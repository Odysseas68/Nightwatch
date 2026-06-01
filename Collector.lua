-- ============================================================
-- Addon   : Nightwatch
-- File    : Collector.lua
-- Version : 2026.06.01
-- Desc    : Per-character data snapshot — inventory, bank, currencies, professions
-- ============================================================
local addonName, NW = ...

-- Explicit bag ID tables — safer than arithmetic offset if enum values change
local CHAR_BANK_BAGS = {
    Enum.BagIndex.CharacterBankTab_1, Enum.BagIndex.CharacterBankTab_2,
    Enum.BagIndex.CharacterBankTab_3, Enum.BagIndex.CharacterBankTab_4,
    Enum.BagIndex.CharacterBankTab_5, Enum.BagIndex.CharacterBankTab_6,
}
local ACCOUNT_BANK_BAGS = {
    Enum.BagIndex.AccountBankTab_1, Enum.BagIndex.AccountBankTab_2,
    Enum.BagIndex.AccountBankTab_3, Enum.BagIndex.AccountBankTab_4,
    Enum.BagIndex.AccountBankTab_5,
}
-- Fast lookup set for warbank bag IDs — used to detect warbank BAG_UPDATE events
local WARBANK_BAG_SET = {}
for _, bagID in ipairs(ACCOUNT_BANK_BAGS) do
    WARBANK_BAG_SET[bagID] = true
end
-- Fast lookup set for character bank bag IDs — used to detect bank BAG_UPDATE events
local CHARBANK_BAG_SET = {}
for _, bagID in ipairs(CHAR_BANK_BAGS) do
    CHARBANK_BAG_SET[bagID] = true
end
local MAX_GUILDBANK_SLOTS = 98   -- slots per guild bank tab (matches Blizzard source)

-- ============================================================
-- Helpers
-- ============================================================

--- Returns "CharName-Realm" key for the current character.
local function GetCharKey()
    local name  = UnitName("player")
    local realm = GetRealmName()
    return name .. "-" .. realm
end

--- Returns a fresh character snapshot skeleton.
local function NewCharEntry(name, realm)
    return {
        name        = name,
        realm       = realm,
        class       = "",
        level       = 0,
        equippedIlvl = 0,
        zone        = "",
        gold        = 0,
        lastSeen    = 0,
        currencies  = {},
        inventory   = {},
        bank        = {},
        reagentbag  = {},
        faction     = "",
        restedXP    = 0,
        guild       = "",
        professions = {},
    }
end

-- ============================================================
-- Snapshot functions
-- ============================================================

--- Collects base character info: class, level, iLevel, zone, gold.
local function SnapshotCharacterInfo(entry)
    local _, class = UnitClass("player")
    entry.class       = class or ""
    entry.level       = UnitLevel("player") or 0
    local _, equipped = GetAverageItemLevel()
    entry.equippedIlvl = math.floor(equipped or 0)
    entry.zone        = GetRealZoneText() or ""
    entry.gold        = GetMoney() or 0
    entry.lastSeen    = time()
    entry.faction     = UnitFactionGroup("player") or "Neutral"
    entry.guild       = (IsInGuild() and GetGuildInfo("player")) or ""
    local restedXP    = (GetXPExhaustion and GetXPExhaustion()) or 0
    local maxXP       = UnitXPMax("player") or 1
    entry.restedXP    = math.floor((restedXP / maxXP) * 100)
end

--- Scans the full currency list and snapshots all currencies with quantity > 0.
--- No hardcoded IDs — automatically captures current and future currencies.
local function SnapshotCurrencies(entry)
    entry.currencies = {}
    local listSize = C_CurrencyInfo.GetCurrencyListSize()
    for i = 1, listSize do
        local info = C_CurrencyInfo.GetCurrencyListInfo(i)
        if info and not info.isHeader and info.currencyID and info.quantity > 0 then
            entry.currencies[info.currencyID] = {
                amount                = info.quantity,
                cap                   = info.maxQuantity or 0,
                isAccountWide         = info.isAccountWide or false,
                isAccountTransferable = info.isAccountTransferable or false,
            }
        end
    end
end

--- Snapshots all professions including per-expansion skill breakdown.
local function SnapshotProfessions(entry)
    entry.professions = {}

    -- GetProfessions() returns reliable slots with correct skill data.
    -- GetAllProfessionTradeSkillLines() returns ALL expansion lines but only
    -- has skill data for lines the tradeskill frame has been opened for.
    -- We use GetProfessions() as the primary source and GetAllProfessionTradeSkillLines()
    -- only to find which parentID each root profession maps to.

    -- Build a lookup: parentSkillLine -> slot data from GetProfessions()
    local slots = { GetProfessions() }
    for _, slot in ipairs(slots) do
        if slot then
            local name, icon, skillLevel, maxSkillLevel, _, _, skillLine = GetProfessionInfo(slot)
            if name and skillLine then
                local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLine)
                -- skillLine here IS the parent root ID (333=Enchanting etc.)
                entry.professions[skillLine] = {
                    name           = name,
                    icon           = icon,
                    skillLevel     = skillLevel    or 0,
                    maxSkillLevel  = maxSkillLevel or 0,
                    isPrimary      = info and info.isPrimaryProfession or false,
                    enumProfession = info and info.profession or nil,
                    expansions     = {},
                }
            end
        end
    end

    -- Now fill expansion breakdown from GetAllProfessionTradeSkillLines()
    -- Only store lines that belong to a profession we actually have (parentID in our map)
    -- and that have real skill data (maxSkillLevel > 0)
    local allLines = C_TradeSkillUI.GetAllProfessionTradeSkillLines()
    if allLines then
        for _, childLine in ipairs(allLines) do
            local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(childLine)
            if info and info.parentProfessionID then
                local parentID = info.parentProfessionID
                if entry.professions[parentID] and (info.maxSkillLevel or 0) > 0 then
                    entry.professions[parentID].expansions[childLine] = {
                        skillLevel    = info.skillLevel    or 0,
                        maxSkillLevel = info.maxSkillLevel or 0,
                    }
                end
            end
        end
    end

    -- Compute and store totals across all expansion lines for fast panel display
    for skillLine, prof in pairs(entry.professions) do
        local total, maxTotal = 0, 0
        for _, exp in pairs(prof.expansions) do
            total    = total    + (exp.skillLevel    or 0)
            maxTotal = maxTotal + (exp.maxSkillLevel or 0)
        end
        if maxTotal > 0 then
            prof.totalSkill    = total
            prof.totalMaxSkill = maxTotal
        else
            prof.totalSkill    = prof.skillLevel    or 0
            prof.totalMaxSkill = prof.maxSkillLevel or 0
        end
    end
end

--- Dumps all profession skillLineIDs and names to chat — for building expansion name table.
function NW.DumpProfessionLines()
    local allLines = C_TradeSkillUI.GetAllProfessionTradeSkillLines()
    if not allLines then print("Nightwatch: No profession lines found."); return end
    print(string.format("|cffA78BFANightwatch:|r %d profession skill lines:", #allLines))
    for _, skillLine in ipairs(allLines) do
        local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLine)
        if info then
            print(string.format("  [%d] %s / parent:%s (skill %d/%d, primary:%s)",
                skillLine,
                info.professionName or "?",
                tostring(info.parentProfessionID or "nil"),
                info.skillLevel or 0,
                info.maxSkillLevel or 0,
                tostring(info.isPrimaryProfession)))
        end
    end
end
local function SnapshotBags(entry)
    entry.inventory  = {}
    entry.reagentbag = {}
    for bag = 0, NUM_BAG_SLOTS do
        local slots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local id = info.itemID
                entry.inventory[id] = (entry.inventory[id] or 0) + info.stackCount
            end
        end
    end
    -- Reagent bag scanned separately for tooltip display
    local reagentSlots = C_Container.GetContainerNumSlots(Enum.BagIndex.ReagentBag)
    for slot = 1, reagentSlots do
        local info = C_Container.GetContainerItemInfo(Enum.BagIndex.ReagentBag, slot)
        if info and info.itemID then
            local id = info.itemID
            entry.reagentbag[id] = (entry.reagentbag[id] or 0) + info.stackCount
        end
    end
end

--- Scans personal bank tabs (only valid while bank frame is open).
local function SnapshotBank(entry)
    entry.bank = {}
    local tabCount = C_Bank.FetchNumPurchasedBankTabs(Enum.BankType.Character) or 0
    for tab = 1, tabCount do
        local bagID = CHAR_BANK_BAGS[tab]
        local slots = C_Container.GetContainerNumSlots(bagID)
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bagID, slot)
            if info and info.itemID then
                local id = info.itemID
                entry.bank[id] = (entry.bank[id] or 0) + info.stackCount
            end
        end
    end
end

--- Scans warbank tabs and writes to account-level NW.db.warbank/warbankTabs.
local function SnapshotWarbank()
    NW.db.warbank     = {}
    NW.db.warbankTabs = {}

    -- Fetch tab metadata for names (only available while bank is open)
    local tabData = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account) or {}
    for _, tab in ipairs(tabData) do
        NW.db.warbankTabs[tab.ID] = tab.name
    end

    local tabCount = C_Bank.FetchNumPurchasedBankTabs(Enum.BankType.Account) or 0
    for tabIndex = 1, tabCount do
        local bagID = ACCOUNT_BANK_BAGS[tabIndex]
        if bagID then
            local slots = C_Container.GetContainerNumSlots(bagID)
            for slot = 1, slots do
                local info = C_Container.GetContainerItemInfo(bagID, slot)
                if info and info.itemID then
                    local id = info.itemID
                    if not NW.db.warbank[id] then NW.db.warbank[id] = {} end
                    NW.db.warbank[id][bagID] = (NW.db.warbank[id][bagID] or 0) + info.stackCount
                end
            end
        end
    end
end

--- Scans all viewable guild bank tabs and writes to NW.db.guildbanks.
--- Only callable while guild bank frame is open.
local function SnapshotGuildBank()
    if not IsInGuild() then return end
    local guildName = GetGuildInfo("player")
    if not guildName then return end
    local key = guildName .. "-" .. GetRealmName()

    NW.db.guildbanks[key] = { items = {}, tabs = {} }
    local entry = NW.db.guildbanks[key]

    local numTabs = GetNumGuildBankTabs()
    for tab = 1, numTabs do
        local name, _, isViewable = GetGuildBankTabInfo(tab)
        if isViewable and name then
            entry.tabs[tab] = name
            for slot = 1, MAX_GUILDBANK_SLOTS do
                local itemLink = GetGuildBankItemLink(tab, slot)
                if itemLink then
                    local itemID = C_Item.GetItemInfoInstant(itemLink)
                    if itemID then
                        local _, count = GetGuildBankItemInfo(tab, slot)
                        count = count or 1
                        if not entry.items[itemID] then entry.items[itemID] = {} end
                        entry.items[itemID][tab] = (entry.items[itemID][tab] or 0) + count
                    end
                end
            end
        end
    end
    NW.LogDebug("Collector", "Guild bank snapshot: " .. key .. " (" .. numTabs .. " tabs)")
    if NW.RefreshUI then NW.RefreshUI() end
end

-- ============================================================
-- Full snapshot entry point
-- ============================================================

--- Runs a full snapshot of the current character and writes to NW.db.
local function SnapshotCharacter()
    if not NW.db then return end
    local name  = UnitName("player")
    local realm = GetRealmName()
    local key   = name .. "-" .. realm

    local chars = NW.db.characters
    if not chars[key] then
        chars[key] = NewCharEntry(name, realm)
    end

    local entry = chars[key]
    SnapshotCharacterInfo(entry)
    SnapshotCurrencies(entry)
    SnapshotBags(entry)
    SnapshotProfessions(entry)
    NW.LogDebug("Collector", "Snapshot complete for " .. key)
    if NW.RefreshUI then NW.RefreshUI() end
end

-- ============================================================
-- Login hook + bank events
-- ============================================================

--- Called by Core on PLAYER_LOGIN.
NW.RegisterOnLogin(SnapshotCharacter)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("SKILL_LINES_CHANGED")
eventFrame:RegisterEvent("TRADE_SKILL_SHOW")
eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
eventFrame:RegisterEvent("GUILDBANKFRAME_OPENED")
eventFrame:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")

local profRefreshPending   = false
local bagScanPending       = false
local warbankScanPending   = false
local bankScanPending      = false
local guildbankScanPending = false

local function ScheduleProfRefresh(entry, source)
    if profRefreshPending then return end
    profRefreshPending = true
    C_Timer.After(0.5, function()
        if not NW.db then profRefreshPending = false; return end
        SnapshotProfessions(entry)
        profRefreshPending = false
        NW.LogDebug("Collector", "Professions refreshed (" .. source .. ")")
        if NW.RefreshUI then NW.RefreshUI() end
    end)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "BANKFRAME_OPENED" then
        if not NW.db then return end
        local key   = GetCharKey()
        local entry = NW.db.characters[key]
        if not entry then return end
        -- Delay scan — tab contents load asynchronously after frame opens
        C_Timer.After(0.5, function()
            if not NW.db then return end
            SnapshotBank(entry)
            -- Use FetchViewableBankTypes to detect if warbank is actually open
            local viewable = C_Bank.FetchViewableBankTypes() or {}
            local warbankViewable = false
            for _, bankType in ipairs(viewable) do
                if bankType == Enum.BankType.Account then
                    warbankViewable = true
                    break
                end
            end
            if warbankViewable then
                SnapshotWarbank()
                NW.LogDebug("Collector", "Bank + Warbank snapshot for " .. key)
            else
                NW.LogDebug("Collector", "Bank snapshot for " .. key .. " (warbank not viewable)")
            end
            if NW.RefreshUI then NW.RefreshUI() end
        end)

    elseif event == "PLAYER_MONEY" then
        if not NW.db then return end
        local key   = GetCharKey()
        local entry = NW.db.characters[key]
        if entry then
            entry.gold    = GetMoney()
            entry.lastSeen = time()
        end

    elseif event == "SKILL_LINES_CHANGED" then
        if not NW.db then return end
        local key   = GetCharKey()
        local entry = NW.db.characters[key]
        if entry then
            ScheduleProfRefresh(entry, "SKILL_LINES_CHANGED")
        end

    elseif event == "TRADE_SKILL_SHOW" then
        if not NW.db then return end
        local key   = GetCharKey()
        local entry = NW.db.characters[key]
        if entry then
            C_Timer.After(0.2, function()
                if not NW.db then return end
                SnapshotProfessions(entry)
                NW.LogDebug("Collector", "Professions refreshed (TRADE_SKILL_SHOW)")
                if NW.RefreshUI then NW.RefreshUI() end
            end)
        end

    elseif event == "BAG_UPDATE" then
        if not NW.db then return end
        local bagID = ...   -- BAG_UPDATE passes the updated bag ID
        if bagID and WARBANK_BAG_SET[bagID] then
            -- Only re-scan warbank if bank frame is actually open
            -- BAG_UPDATE fires for warbank IDs at login even when bank isn't open
            if not warbankScanPending and C_Bank.AreAnyBankTypesViewable() then
                warbankScanPending = true
                C_Timer.After(0.5, function()
                    if not NW.db then return end
                    SnapshotWarbank()
                    if NW.RefreshUI then NW.RefreshUI() end
                    warbankScanPending = false
                end)
            end
        elseif bagID and CHARBANK_BAG_SET[bagID] then
            -- Character bank tab changed — re-scan bank
            if not bankScanPending then
                bankScanPending = true
                C_Timer.After(0.5, function()
                    if not NW.db then return end
                    local key   = GetCharKey()
                    local entry = NW.db.characters[key]
                    if entry then SnapshotBank(entry) end
                    if NW.RefreshUI then NW.RefreshUI() end
                    bankScanPending = false
                end)
            end
        elseif not bagScanPending then
            bagScanPending = true
            C_Timer.After(1.5, function()
                if not NW.db then return end
                local key   = GetCharKey()
                local entry = NW.db.characters[key]
                if entry then SnapshotBags(entry) end
                if NW.RefreshUI then NW.RefreshUI() end
                bagScanPending = false
            end)
        end

    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        if not NW.db then return end
        local key   = GetCharKey()
        local entry = NW.db.characters[key]
        if entry then
            SnapshotCurrencies(entry)
            if NW.RefreshUI then NW.RefreshUI() end
        end

    elseif event == "GUILDBANKFRAME_OPENED" then
        if not NW.db then return end
        -- Delay scan — guild bank tab contents load asynchronously
        C_Timer.After(0.5, function()
            if not NW.db then return end
            SnapshotGuildBank()
        end)

    elseif event == "GUILDBANKBAGSLOTS_CHANGED" then
        if not NW.db then return end
        if not guildbankScanPending then
            guildbankScanPending = true
            C_Timer.After(0.5, function()
                if not NW.db then return end
                SnapshotGuildBank()
                guildbankScanPending = false
            end)
        end
    end
end)