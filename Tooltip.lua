-- ============================================================
-- Addon   : Nightwatch
-- File    : Tooltip.lua
-- Version : 2026.05.24
-- Desc    : Item tooltip injection — shows per-char counts on Alt hover
-- ============================================================
local _, NW = ...

-- ============================================================
-- Item lookup
-- ============================================================

--- Returns per-character counts and warbank breakdown by tab.
local function GetItemCounts(itemID)
    local chars          = {}
    local warbankTabs    = {}
    local warbankTotal   = 0
    local warbankCounted = false

    for key, char in pairs(NW.db.characters) do
        if not NW.db.settings.hiddenChars[key] then
            local bags    = (char.inventory  and char.inventory[itemID])  or 0
            local reagent = (char.reagentbag and char.reagentbag[itemID]) or 0
            local bank    = (char.bank       and char.bank[itemID])       or 0

            -- Warbank is account-wide — only read once
            if not warbankCounted and char.warbank and char.warbank[itemID] then
                local tabCounts = char.warbank[itemID]
                for bagID, count in pairs(tabCounts) do
                    local name = (char.warbankTabs and char.warbankTabs[bagID])
                        or ("Tab " .. (bagID - 11))
                    warbankTabs[#warbankTabs + 1] = { name = name, count = count }
                    warbankTotal = warbankTotal + count
                end
                warbankCounted = true
            end

            if bags + reagent + bank > 0 then
                chars[#chars + 1] = {
                    name    = char.name  or key,
                    class   = char.class or "",
                    bags    = bags,
                    reagent = reagent,
                    bank    = bank,
                    total   = bags + reagent + bank,
                }
            end
        end
    end
    table.sort(chars, function(a, b) return a.name < b.name end)
    table.sort(warbankTabs, function(a, b) return a.name < b.name end)
    return chars, warbankTabs, warbankTotal
end

-- ============================================================
-- Class color lookup
-- ============================================================

local CLASS_COLORS = {
    WARRIOR     = "C79C6E", PALADIN     = "F58CBA", HUNTER      = "ABD473",
    ROGUE       = "FFF569", PRIEST      = "FFFFFF", DEATHKNIGHT = "C41F3B",
    SHAMAN      = "0070DE", MAGE        = "69CCF0", WARLOCK     = "9482C9",
    MONK        = "00FF96", DRUID       = "FF7D0A", DEMONHUNTER = "A330C9",
    EVOKER      = "33937F",
}

local function ColoredName(name, class)
    local hex = CLASS_COLORS[class] or "FFFFFF"
    return string.format("|cff%s%s|r", hex, name)
end

-- ============================================================
-- Tooltip hook
-- ============================================================

local function OnItemTooltip(tooltip, data)
    if not NW.db then return end

    -- Respect modifier key setting (default: Alt)
    local mod = NW.db.settings.tooltipModifier or "ALT"
    if mod == "ALT"   and not IsAltKeyDown()   then return end
    if mod == "CTRL"  and not IsControlKeyDown() then return end
    if mod == "SHIFT" and not IsShiftKeyDown()   then return end

    local itemID = data and data.id
    if not itemID then return end

    local results, warbankTabs, warbankTotal = GetItemCounts(itemID)
    if #results == 0 and warbankTotal == 0 then return end

    tooltip:AddLine(" ")
    tooltip:AddLine("|cffA78BFANightwatch|r")

    local grandTotal = warbankTotal

    for _, entry in ipairs(results) do
        grandTotal = grandTotal + entry.total

        local parts = {}
        if entry.bags    > 0 then
            parts[#parts + 1] = "|cffCCCCCCBags:|r |cff4ADE80" .. entry.bags .. "|r"
        end
        if entry.reagent > 0 then
            parts[#parts + 1] = "|cffCCCCCCReagent Bag:|r |cff4ADE80" .. entry.reagent .. "|r"
        end
        if entry.bank    > 0 then
            parts[#parts + 1] = "|cffCCCCCCBank:|r |cff4ADE80" .. entry.bank .. "|r"
        end
        local breakdown = #parts > 0
            and ("  |cff888888(|r" .. table.concat(parts, " |cff888888·|r ") .. "|cff888888)|r")
            or ""

        tooltip:AddDoubleLine(
            ColoredName(entry.name, entry.class) .. breakdown,
            "|cff4ADE80" .. entry.total .. "|r"
        )
    end

    if warbankTotal > 0 then
        -- Header line with total
        tooltip:AddDoubleLine(
            "|cff67E8F9Account Warbank|r",
            "|cff4ADE80" .. warbankTotal .. "|r"
        )
        -- Per-tab breakdown
        for _, tab in ipairs(warbankTabs) do
            tooltip:AddDoubleLine(
                "  |cffE2E8F0" .. tab.name .. ":|r",
                "|cff4ADE80" .. tab.count .. "|r"
            )
        end
    end

    tooltip:AddLine(" ")
    tooltip:AddDoubleLine(
        "|cffCCCCCCTotal owned:|r",
        "|cffC084FC" .. grandTotal .. "|r"
    )
end

-- ============================================================
-- Registration
-- ============================================================

NW.RegisterOnLogin(function()
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip) ---@diagnostic disable-line: undefined-global
    NW.LogDebug("Tooltip", "Item tooltip hook registered")
end)
