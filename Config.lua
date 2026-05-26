-- ============================================================
-- Addon   : Nightwatch
-- File    : Config.lua
-- Version : 2026.05.26
-- Desc    : Main UI — expandable nav, panels, status bar
-- ============================================================
local addonName, NW = ...

-- ============================================================
-- Constants
-- ============================================================

local WINDOW_WIDTH   = 820
local WINDOW_HEIGHT  = 570   -- +30 for bottom status bar
local SIDEBAR_WIDTH  = 160
local BOTTOM_BAR_H   = 28
local CONTENT_X      = SIDEBAR_WIDTH + 18
local CONTENT_WIDTH  = WINDOW_WIDTH - SIDEBAR_WIDTH - 30
local CONTENT_HEIGHT = WINDOW_HEIGHT - 60 - BOTTOM_BAR_H

-- Class colors (Retail standard)
local CLASS_COLORS = {
    WARRIOR     = "C79C6E", PALADIN    = "F58CBA", HUNTER   = "ABD473",
    ROGUE       = "FFF569", PRIEST     = "FFFFFF", DEATHKNIGHT = "C41F3B",
    SHAMAN      = "0070DE", MAGE       = "69CCF0", WARLOCK  = "9482C9",
    MONK        = "00FF96", DRUID      = "FF7D0A", DEMONHUNTER = "A330C9",
    EVOKER      = "33937F",
}

-- Expandable nav tree
local NAV_TREE = {
    {
        id       = "charinfo",
        label    = "Character Information",
        children = {
            { id = "characters",  label = "Character Summary" },
            { id = "professions", label = "Profession Skills" },
        },
    },
    {
        id       = "currencies",
        label    = "Currencies",
        children = {
            { id = "currencies_midnight", label = "Midnight"       },
            { id = "currencies_misc",     label = "Miscellaneous"  },
            { id = "currencies_pvp",      label = "PvP"            },
        },
    },
    { id = "inventory", label = "Inventory",  children = {} },
    { id = "settings",  label = "Settings",   children = {} },
}

-- Midnight Season 1 Dawncrest crests — ordered Adventurer→Myth
local DAWNCREST_CRESTS = {
    { id = 3383, name = "Adventurer Dawncrest", icon = 7639517 },
    { id = 3341, name = "Veteran Dawncrest",    icon = 7639525 },
    { id = 3343, name = "Champion Dawncrest",   icon = 7639519 },
    { id = 3345, name = "Hero Dawncrest",       icon = 7639521 },
    { id = 3347, name = "Myth Dawncrest",       icon = 7639523 },
}

-- Miscellaneous cross-expansion currencies
local MISC_CURRENCIES = {
    { id = 2032, name = "Trader's Tender",  icon = 4696085 },
    { id = 1166, name = "Timewarped Badge", icon = 463446  },
}

-- PvP currencies
local PVP_CURRENCIES = {
    { id = 1792, name = "Honor",    icon = 1455894 },
    { id = 1602, name = "Conquest", icon = 1523630 },
}

-- Theme presets
local THEMES = {
    midnight     = { bg = {0.05, 0.05, 0.10}, accent = {0.30, 0.20, 0.50}, text = {1, 1, 1} },
    darkblue     = { bg = {0.03, 0.05, 0.12}, accent = {0.10, 0.30, 0.60}, text = {1, 1, 1} },
    darkgreen    = { bg = {0.03, 0.10, 0.05}, accent = {0.10, 0.50, 0.20}, text = {1, 1, 1} },
    parchment    = { bg = {0.85, 0.78, 0.62}, accent = {0.60, 0.45, 0.25}, text = {0.15, 0.10, 0.05} },
    deuteranopia = { bg = {0.05, 0.05, 0.10}, accent = {0.20, 0.40, 0.80}, text = {1, 1, 1} },
    protanopia   = { bg = {0.05, 0.05, 0.10}, accent = {0.30, 0.50, 0.80}, text = {1, 1, 1} },
    tritanopia   = { bg = {0.10, 0.05, 0.05}, accent = {0.80, 0.30, 0.20}, text = {1, 1, 1} },
}

-- ============================================================
-- Helpers
-- ============================================================

local function FormatGold(copper)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    local gStr = tostring(g):reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
    return string.format("|cffFFD700%sg|r |cffC0C0C0%ds|r |cffB87333%dc|r", gStr, s, c)
end

local function ColoredName(name, class)
    local hex = CLASS_COLORS[class] or "FFFFFF"
    return string.format("|cff%s%s|r", hex, name)
end

local function GetVisibleChars(realmFilter)
    local chars = {}
    for key, data in pairs(NW.db.characters) do
        if (not realmFilter or data.realm == realmFilter)
        and not NW.db.settings.hiddenChars[key] then
            table.insert(chars, { key = key, data = data })
        end
    end
    table.sort(chars, function(a, b) return (a.data.name or "") < (b.data.name or "") end)
    return chars
end

local function TotalGold(realmFilter)
    local total = 0
    for key, char in pairs(NW.db.characters) do
        if (not realmFilter or char.realm == realmFilter)
        and not NW.db.settings.hiddenChars[key] then
            total = total + (char.gold or 0)
        end
    end
    return total
end

local function CountRealms()
    local realms = {}
    for _, char in pairs(NW.db.characters) do
        if char.realm then realms[char.realm] = true end
    end
    local n = 0
    for _ in pairs(realms) do n = n + 1 end
    return n
end

-- Forward declarations for ApplyTheme/ApplyFont (need mainFrame/sidebar/titleText)
local mainFrame, sidebar, titleText

function NW.ApplyTheme(themeID)
    local t = THEMES[themeID]
    if not t then return end
    NW.db.settings.theme = themeID
    mainFrame:SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], 1.0)
    sidebar:SetBackdropColor(t.bg[1] * 0.6, t.bg[2] * 0.6, t.bg[3] * 0.6, 1.0)
end

function NW.ApplyFont(fontName)
    NW.db.settings.font = fontName
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if not LSM then return end
    local path = LSM:Fetch("font", fontName)
    if path then
        titleText:SetFont(path, NW.db.settings.fontSize or 12)
    end
end

-- ============================================================
-- Main frame
-- ============================================================

mainFrame = CreateFrame("Frame", "NightwatchFrame", UIParent, "BackdropTemplate")
mainFrame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
mainFrame:SetPoint("CENTER")
mainFrame:SetFrameStrata("DIALOG")
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop",  mainFrame.StopMovingOrSizing)
mainFrame:SetClampedToScreen(true)
mainFrame:Hide()
tinsert(UISpecialFrames, "NightwatchFrame")

mainFrame:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = false, edgeSize = 16,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
})
mainFrame:SetBackdropColor(0.05, 0.05, 0.10, 1.0)
mainFrame:SetBackdropBorderColor(0.30, 0.20, 0.50, 1.0)

titleText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetPoint("TOP", mainFrame, "TOP", 0, -14)
titleText:SetText("|cffA78BFANightwatch|r")

local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -4, -4)
closeBtn:SetScript("OnClick", function() mainFrame:Hide() end)

-- ============================================================
-- Bottom status bar
-- ============================================================

local bottomBar = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
bottomBar:SetHeight(BOTTOM_BAR_H)
bottomBar:SetPoint("BOTTOMLEFT",  mainFrame, "BOTTOMLEFT",  6,  6)
bottomBar:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -6, 6)
bottomBar:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
bottomBar:SetBackdropColor(0.03, 0.03, 0.07, 0.9)
bottomBar:SetBackdropBorderColor(0.25, 0.18, 0.40, 0.8)

local bottomCharFS = bottomBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
bottomCharFS:SetPoint("LEFT", bottomBar, "LEFT", 10, 0)

local bottomRealmFS = bottomBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
bottomRealmFS:SetPoint("LEFT", bottomBar, "LEFT", 130, 0)

local bottomGoldFS = bottomBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
bottomGoldFS:SetPoint("RIGHT", bottomBar, "RIGHT", -10, 0)
bottomGoldFS:SetJustifyH("RIGHT")

local function UpdateBottomBar()
    if not NW.db then return end
    local chars = 0
    for key in pairs(NW.db.characters) do
        if not NW.db.settings.hiddenChars[key] then chars = chars + 1 end
    end
    bottomCharFS:SetText(string.format("|cffBBBBBBCharacters:|r %d", chars))
    bottomRealmFS:SetText(string.format("|cffBBBBBBRealms:|r %d", CountRealms()))
---@diagnostic disable-next-line: undefined-global
    bottomGoldFS:SetText("Total Gold: " .. FormatGold(TotalGold(currentRealmFilter)))
end

-- ============================================================
-- Sidebar
-- ============================================================

sidebar = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
sidebar:SetSize(SIDEBAR_WIDTH, WINDOW_HEIGHT - 50 - BOTTOM_BAR_H - 8)
sidebar:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -40)
sidebar:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
sidebar:SetBackdropColor(0.05, 0.05, 0.10, 0.8)
sidebar:SetBackdropBorderColor(0.25, 0.18, 0.40, 0.8)

local realmLabel = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
realmLabel:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 10, -10)
realmLabel:SetText("|cffBBBBBBRealm|r")

local currentRealmFilter = nil

local realmBtn = CreateFrame("Button", nil, sidebar, "UIPanelButtonTemplate")
realmBtn:SetSize(SIDEBAR_WIDTH - 20, 22)
realmBtn:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 10, -26)
realmBtn:SetText("All Realms")
realmBtn:SetScript("OnClick", function()
    if currentRealmFilter then
        currentRealmFilter = nil
        realmBtn:SetText("All Realms")
    else
        currentRealmFilter = GetRealmName()
        realmBtn:SetText("This Realm")
    end
    if NW.activePanel then NW.ShowPanel(NW.activePanel) end
    UpdateBottomBar()
end)

-- ============================================================
-- Expandable nav
-- ============================================================

local function IsExpanded(id)
    if not NW.db then return false end
    NW.db.settings.navExpanded = NW.db.settings.navExpanded or {}
    return NW.db.settings.navExpanded[id] == true
end

local function SetExpanded(id, state)
    if not NW.db then return end
    NW.db.settings.navExpanded = NW.db.settings.navExpanded or {}
    NW.db.settings.navExpanded[id] = state or nil
end

local navButtonRefs = {}
local NAV_BTN_H   = 26
local NAV_BTN_PAD = 2
local NAV_TOP     = -56

local function SetNavActive(id)
    for navId, btn in pairs(navButtonRefs) do
        if navId == id then
            btn.sel:Show()
            btn.label:SetTextColor(1, 1, 1)
        else
            btn.sel:Hide()
            if btn.isChild then
                btn.label:SetTextColor(1, 1, 1)
            else
                btn.label:SetTextColor(1, 0.82, 0.0)
            end
        end
    end
end

local RebuildNav  -- forward

local function MakeNavButton(parent, id, label, yOff, isChild)
    local btn    = CreateFrame("Button", nil, parent)
    local indent = isChild and 18 or 4
    btn:SetSize(SIDEBAR_WIDTH - 16, NAV_BTN_H)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOff)

    -- Normal background texture (atlas)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    if isChild then
        bg:SetAtlas("auctionhouse-nav-button-secondary", false)
        bg:SetSize(133, 32)
        bg:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, 0)
    else
        bg:SetAtlas("auctionhouse-nav-button", false)
        bg:SetSize(136, 32)
        bg:SetPoint("TOPLEFT", btn, "TOPLEFT", -2, 0)
    end
    btn.bg = bg

    -- Highlight texture (hover)
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    if isChild then
        hl:SetAtlas("auctionhouse-nav-button-secondary-highlight", false)
        hl:SetSize(122, 21)
        hl:SetPoint("TOPLEFT", btn, "TOPLEFT", 10, 0)
    else
        hl:SetAtlas("auctionhouse-nav-button-highlight", false)
        hl:SetSize(132, 21)
        hl:SetPoint("LEFT", btn, "LEFT", 0, 0)
    end
    hl:SetBlendMode("BLEND")
    btn.hl = hl

    -- Selected texture
    local sel = btn:CreateTexture(nil, "ARTWORK")
    if isChild then
        sel:SetAtlas("auctionhouse-nav-button-secondary-select", false)
        sel:SetSize(122, 21)
        sel:SetPoint("TOPLEFT", btn, "TOPLEFT", 10, 0)
    else
        sel:SetAtlas("auctionhouse-nav-button-select", false)
        sel:SetSize(132, 21)
        sel:SetPoint("LEFT", btn, "LEFT", 0, 0)
    end
    sel:Hide()
    btn.sel = sel

    local labelX = isChild and indent or indent + 4
    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("LEFT", btn, "LEFT", labelX, 0)
    fs:SetText(label)
    fs:SetWidth(SIDEBAR_WIDTH - labelX - 16)
    btn.label = fs
    btn.isChild = isChild
    if isChild then
        fs:SetTextColor(1, 1, 1)
    else
        fs:SetTextColor(1, 0.82, 0.0)
    end

    -- OnEnter/OnLeave not needed — HIGHLIGHT layer handles hover automatically
    navButtonRefs[id] = btn
    return btn
end

RebuildNav = function()
    for _, btn in pairs(navButtonRefs) do btn:Hide() end
    navButtonRefs = {}

    local yOff = NAV_TOP

    for _, item in ipairs(NAV_TREE) do
        local hasChildren = #item.children > 0
        local expanded    = hasChildren and IsExpanded(item.id)

        local btn = MakeNavButton(sidebar, item.id, item.label, yOff, false)

        if hasChildren then
            btn:SetScript("OnClick", function()
                local nowExpanded = not IsExpanded(item.id)
                SetExpanded(item.id, nowExpanded)
                RebuildNav()
                if nowExpanded and item.children[1] then
                    NW.ShowPanel(item.children[1].id)
                end
            end)
        else
            btn:SetScript("OnClick", function() NW.ShowPanel(item.id) end)
        end

        btn:Show()
        yOff = yOff - NAV_BTN_H - NAV_BTN_PAD

        if expanded then
            for _, child in ipairs(item.children) do
                local cbtn = MakeNavButton(sidebar, child.id, child.label, yOff, true)
                cbtn:SetScript("OnClick", function() NW.ShowPanel(child.id) end)
                cbtn:Show()
                yOff = yOff - NAV_BTN_H - NAV_BTN_PAD
            end
        end
    end

    -- Re-apply active state after rebuild
    if NW.activePanel then SetNavActive(NW.activePanel) end
end

-- ============================================================
-- Content pane + scroll frame
-- ============================================================

local contentPane = CreateFrame("Frame", nil, mainFrame)
contentPane:SetSize(CONTENT_WIDTH, CONTENT_HEIGHT)
contentPane:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", CONTENT_X, -42)

local scrollFrame = CreateFrame("ScrollFrame", nil, contentPane, "UIPanelScrollFrameTemplate")
scrollFrame:SetSize(CONTENT_WIDTH - 20, CONTENT_HEIGHT - 10)
scrollFrame:SetPoint("TOPLEFT", contentPane, "TOPLEFT", 0, 0)

local scrollChild = CreateFrame("Frame", nil, scrollFrame)
scrollChild:SetSize(CONTENT_WIDTH - 20, 1)
scrollFrame:SetScrollChild(scrollChild)

local charHeaderPane = CreateFrame("Frame", nil, contentPane)
charHeaderPane:SetPoint("TOPLEFT",  contentPane, "TOPLEFT",  0, 0)
charHeaderPane:SetPoint("TOPRIGHT", contentPane, "TOPRIGHT", 0, 0)
charHeaderPane:SetHeight(42)
charHeaderPane:Hide()

local function ClearContent()
    for _, child in ipairs({ scrollChild:GetChildren() }) do child:Hide() end
    for _, region in ipairs({ scrollChild:GetRegions() }) do region:Hide() end
    for _, region in ipairs({ charHeaderPane:GetRegions() }) do region:Hide() end
    scrollFrame:SetVerticalScroll(0)
end

local function ResetScrollFrame()
    charHeaderPane:Hide()
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", contentPane, "TOPLEFT", 0, 0)
    scrollFrame:SetHeight(CONTENT_HEIGHT - 10)
end

local function MakeDivider(parent, yOff)
    local d = parent:CreateTexture(nil, "ARTWORK")
    d:SetHeight(1)
    d:SetPoint("TOPLEFT",  parent, "TOPLEFT",   0, yOff)
    d:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, yOff)
    d:SetColorTexture(0.3, 0.3, 0.4, 0.6)
    return d
end

local function SectionHeader(parent, text, yOff)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, yOff)
    fs:SetText("|cffA78BFA" .. text .. "|r")
    return yOff - 20
end

-- ============================================================
-- Character Summary panel
-- ============================================================

local function BuildCharacterSummaryPanel()
    local FACTION_ICONS = {
        Alliance = "Interface\\Icons\\Inv_misc_tournaments_banner_human",
        Horde    = "Interface\\Icons\\Inv_misc_tournaments_banner_orc",
    }
    local ROW_HEIGHT  = 28
    local ROW_PADDING = 2
    local COL_FACTION  = 4
    local COL_NAME     = 60
    local COL_LEVEL    = 220
    local COL_RESTED   = 258
    local COL_ILVL     = 310
    local COL_GOLD     = 312
    local COL_LASTSEEN = 510

    ClearContent()
    charHeaderPane:Show()
    charHeaderPane:SetFrameLevel(contentPane:GetFrameLevel() + 2)
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", contentPane, "TOPLEFT", 0, -42)
    scrollFrame:SetHeight(CONTENT_HEIGHT - 42)

    local chars = GetVisibleChars(currentRealmFilter)

    local function MakeHeader(label, xOff, yOff)
        local fs = charHeaderPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", charHeaderPane, "TOPLEFT", xOff, yOff)
        fs:SetTextColor(0.80, 0.80, 0.90)
        fs:SetText(label)
    end
    local headerY = -22
    MakeHeader("Faction",    COL_FACTION,    headerY)
    MakeHeader("Name",       COL_NAME,       headerY)
    MakeHeader("Lvl",        COL_LEVEL,      headerY)
    MakeHeader("Rested",     COL_RESTED,     headerY)
    MakeHeader("iLvl",       COL_ILVL,       headerY)
    MakeHeader("Gold",       COL_GOLD + 80,  headerY)
    MakeHeader("Last Login", COL_LASTSEEN,   headerY)
    MakeDivider(charHeaderPane, -36)

    local yOff = -8
    for i, entry in ipairs(chars) do
        local char = entry.data
        local row  = CreateFrame("Frame", nil, scrollChild)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT",  scrollChild, "TOPLEFT",  0,   yOff)
        row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -20, yOff)

        if i % 2 == 0 then
            local rowBg = row:CreateTexture(nil, "BACKGROUND")
            rowBg:SetAllPoints()
            rowBg:SetColorTexture(0.10, 0.08, 0.16, 0.4)
        end

        local classHex = CLASS_COLORS[char.class] or "888888"
        local r = tonumber(classHex:sub(1,2), 16) / 255
        local g = tonumber(classHex:sub(3,4), 16) / 255
        local b = tonumber(classHex:sub(5,6), 16) / 255
        local bar = row:CreateTexture(nil, "ARTWORK")
        bar:SetWidth(3)
        bar:SetPoint("TOPLEFT",    row, "TOPLEFT",    1, -2)
        bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 1,  2)
        bar:SetColorTexture(r, g, b, 1)

        local factionTex = row:CreateTexture(nil, "ARTWORK")
        factionTex:SetSize(20, 20)
        factionTex:SetPoint("LEFT", row, "LEFT", COL_FACTION, 0)
        local iconPath = FACTION_ICONS[char.faction]
        if iconPath then factionTex:SetTexture(iconPath) end

        local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameFS:SetPoint("LEFT", row, "LEFT", COL_NAME, 0)
        nameFS:SetWidth(COL_LEVEL - COL_NAME - 4)
        nameFS:SetJustifyH("LEFT")
        nameFS:SetText(ColoredName(char.name or "?", char.class)
            .. " |cff666666" .. (char.realm or "") .. "|r")

        local levelFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        levelFS:SetPoint("LEFT", row, "LEFT", COL_LEVEL, 0)
        levelFS:SetText(tostring(char.level or 0))

        local restedFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        restedFS:SetPoint("LEFT", row, "LEFT", COL_RESTED, 0)
        local rested = char.restedXP or 0
        restedFS:SetText(rested > 0
            and string.format("|cff4FC3F7%d%%|r", rested)
            or "|cff444444—|r")

        local ilvlFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ilvlFS:SetPoint("LEFT", row, "LEFT", COL_ILVL, 0)
        ilvlFS:SetText(tostring(char.equippedIlvl or 0))

        local goldFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        goldFS:SetPoint("LEFT", row, "LEFT", COL_GOLD, 0)
        goldFS:SetWidth(160)
        goldFS:SetJustifyH("RIGHT")
        goldFS:SetText(FormatGold(char.gold or 0))

        local seenFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        seenFS:SetPoint("LEFT", row, "LEFT", COL_LASTSEEN, 0)
        seenFS:SetTextColor(0.65, 0.65, 0.72)
        local seenStr = (char.lastSeen and char.lastSeen > 0)
            and tostring(date("%d/%m/%Y", char.lastSeen)) or "Never"
        seenFS:SetText(seenStr)

        yOff = yOff - ROW_HEIGHT - ROW_PADDING
    end

    scrollChild:SetHeight(math.max(CONTENT_HEIGHT, math.abs(yOff) + 20))
end

-- ============================================================
-- Profession Skills panel
-- ============================================================

-- Secondary profession enum values and their fallback header icons
local SECONDARY_COLS = {
    { enum = 5,  label = "Cook",  icon = "Interface\\Icons\\INV_Misc_Food_15"    },
    { enum = 10, label = "Fish",  icon = "Interface\\Icons\\Trade_Fishing"       },
    { enum = 14, label = "Arch",  icon = "Interface\\Icons\\Trade_Archaeology"   },
}
local SECONDARY_ENUM_SET = {}
for _, s in ipairs(SECONDARY_COLS) do SECONDARY_ENUM_SET[s.enum] = true end

local function BuildProfessionsPanel()
    ClearContent()
    ResetScrollFrame()

    local chars = GetVisibleChars(currentRealmFilter)
    if #chars == 0 then return end

    -- Column layout
    local COL_FACTION  = 4
    local COL_NAME     = 22    -- faction icon 14px + 4px gap
    local COL_LEVEL    = 180
    local COL_PRIM1    = 210
    local COL_PRIM2    = 290   -- tighter — icon only, no name
    local COL_SEC1     = 370   -- Cooking
    local COL_SEC2     = 408   -- Fishing
    local COL_SEC3     = 446   -- Archaeology
    local ROW_H        = 26
    local FACTION_SZ   = 14
    local ICON_SZ      = 14

    -- ---- Header row ----
    local function MakeHdr(label, x)
        local fs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", x, -8)
        fs:SetTextColor(0.80, 0.80, 0.90)
        fs:SetText(label)
    end

    MakeHdr("Name",    COL_NAME)
    MakeHdr("Lvl",     COL_LEVEL)
    MakeHdr("Prof. 1", COL_PRIM1)
    MakeHdr("Prof. 2", COL_PRIM2)

    -- Apply column positions to secondary cols before rendering headers
    SECONDARY_COLS[1].col = COL_SEC1
    SECONDARY_COLS[2].col = COL_SEC2
    SECONDARY_COLS[3].col = COL_SEC3

    -- Use pre-computed totals from snapshot; fall back to root values if not yet available
    local function ProfTotal(prof)
        if (prof.totalMaxSkill or 0) > 0 then
            return prof.totalSkill, prof.totalMaxSkill
        end
        -- Fallback: sum expansions directly
        local total, maxTotal = 0, 0
        local hasExpansions = false
        for _, exp in pairs(prof.expansions or {}) do
            if (exp.maxSkillLevel or 0) > 0 then
                total    = total    + (exp.skillLevel    or 0)
                maxTotal = maxTotal + (exp.maxSkillLevel or 0)
                hasExpansions = true
            end
        end
        if not hasExpansions then
            return prof.skillLevel or 0, prof.maxSkillLevel or 0
        end
        return total, maxTotal
    end

    -- Gather best icon for each secondary col from any char that has it
    for _, sec in ipairs(SECONDARY_COLS) do
        for _, entry in ipairs(chars) do
            for _, prof in pairs(entry.data.professions or {}) do
                if prof.enumProfession == sec.enum and prof.icon then
                    sec.icon = prof.icon
                    break
                end
            end
        end
        -- Icon-only secondary header
        local tex = scrollChild:CreateTexture(nil, "ARTWORK")
        tex:SetSize(ICON_SZ + 2, ICON_SZ + 2)
        tex:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", sec.col, -7)
        tex:SetTexture(sec.icon)
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    -- Divider — lower so it clears the secondary icons
    local divY = -28
    MakeDivider(scrollChild, divY)
    local yOff = divY - 4

    -- ---- Rows ----
    local FACTION_ICONS = {
        Alliance = "Interface\\Icons\\Inv_misc_tournaments_banner_human",
        Horde    = "Interface\\Icons\\Inv_misc_tournaments_banner_orc",
    }

    -- Profession breakdown tooltip — live query for current char, stored data for others
    local function ShowProfTooltip(anchor, prof, parentSkillLine)
        GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(prof.name, 0.8, 0.6, 1)

        local sorted = {}
        local liveTotal, liveTotalMax = 0, 0

        -- Try live query first (works for currently logged in character)
        local allLines = C_TradeSkillUI.GetAllProfessionTradeSkillLines()
        for _, childLine in ipairs(allLines or {}) do
            local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(childLine)
            if info and info.parentProfessionID == parentSkillLine
            and (info.maxSkillLevel or 0) > 0 then
                liveTotal    = liveTotal    + (info.skillLevel    or 0)
                liveTotalMax = liveTotalMax + (info.maxSkillLevel or 0)
                local expLabel = info.professionName or ""
                local suffixPos = expLabel:find("%s+" .. (prof.name or "") .. "$")
                if suffixPos then expLabel = expLabel:sub(1, suffixPos - 1) end
                if expLabel == "" then expLabel = info.professionName or "?" end
                table.insert(sorted, {
                    label     = expLabel,
                    skillLine = childLine,
                    skill     = info.skillLevel    or 0,
                    maxSkill  = info.maxSkillLevel or 0,
                })
            end
        end

        -- Fall back to stored snapshot expansions (offline characters)
        if #sorted == 0 then
            for childLine, exp in pairs(prof.expansions or {}) do
                if (exp.maxSkillLevel or 0) > 0 then
                    liveTotal    = liveTotal    + (exp.skillLevel    or 0)
                    liveTotalMax = liveTotalMax + (exp.maxSkillLevel or 0)
                    -- Get expansion label from API (name data doesn't need frame open)
                    local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(childLine)
                    local expLabel = (info and info.professionName) or tostring(childLine)
                    local suffixPos = expLabel:find("%s+" .. (prof.name or "") .. "$")
                    if suffixPos then expLabel = expLabel:sub(1, suffixPos - 1) end
                    table.insert(sorted, {
                        label     = expLabel,
                        skillLine = childLine,
                        skill     = exp.skillLevel    or 0,
                        maxSkill  = exp.maxSkillLevel or 0,
                    })
                end
            end
        end

        -- Final fallback: no expansion data at all
        if liveTotal == 0 and liveTotalMax == 0 then
            liveTotal, liveTotalMax = ProfTotal(prof)
        end

        GameTooltip:AddLine(string.format("Total: %d / %d", liveTotal, liveTotalMax), 1, 1, 1)

        if #sorted > 0 then
            GameTooltip:AddLine(" ")
            -- Newest expansion first — label prefix matched against known order
            local EXPANSION_ORDER = {
                ["Midnight"]      = 1,
                ["Khaz Algar"]    = 2,
                ["Dragon Isles"]  = 3,
                ["Shadowlands"]   = 4,
                ["Kul Tiran"]     = 5,
                ["Zandalar"]      = 5,
                ["Legion"]        = 6,
                ["Draenor"]       = 7,
                ["Pandaria"]      = 8,
                ["Cataclysm"]     = 9,
                ["Northrend"]     = 10,
                ["Outland"]       = 11,
                ["Classic"]       = 12,
            }
            local function ExpansionRank(label)
                for prefix, rank in pairs(EXPANSION_ORDER) do
                    if label:find(prefix, 1, true) then return rank end
                end
                return 99
            end
            table.sort(sorted, function(a, b)
                return ExpansionRank(a.label) < ExpansionRank(b.label)
            end)
            for _, expRow in ipairs(sorted) do
                local pct   = math.floor((expRow.skill / expRow.maxSkill) * 100)
                local color = pct >= 100 and "FFD700" or "DDDDDD"
                GameTooltip:AddDoubleLine(
                    "|cffAAAAAA" .. expRow.label .. "|r",
                    string.format("|cff%s%d|r|cff666666/%d|r", color, expRow.skill, expRow.maxSkill)
                )
            end
        end

        GameTooltip:Show()
    end

    local function SecCell(row, enumVal, profs, x)
        -- Find the secondary prof by enumProfession value
        local secProf, secSL
        for skillLine, prof in pairs(profs or {}) do
            if prof.enumProfession == enumVal then
                secProf = prof
                secSL   = skillLine
                break
            end
        end

        if secProf then
            local total, _ = ProfTotal(secProf)
            local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetPoint("LEFT", row, "LEFT", x, 0)
            local color = total > 0 and "DDDDDD" or "555555"
            fs:SetText(total > 0
                and string.format("|cff%s%d|r", color, total)
                or "|cff555555—|r")

            -- Hover button for tooltip
            local hoverBtn = CreateFrame("Button", nil, row)
            hoverBtn:SetPoint("LEFT", row, "LEFT", x - 2, 0)
            hoverBtn:SetSize(36, ROW_H)
            hoverBtn:SetScript("OnEnter", function(self)
                ShowProfTooltip(self, secProf, secSL)
            end)
            hoverBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        else
            local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetPoint("LEFT", row, "LEFT", x, 0)
            fs:SetText("|cff555555—|r")
        end
    end

    for i, entry in ipairs(chars) do
        local char  = entry.data
        local profs = char.professions or {}

        -- Row frame (same pattern as Character Summary)
        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT",  scrollChild, "TOPLEFT",  0,   yOff)
        row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -20, yOff)

        -- Zebra stripe
        if i % 2 == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.10, 0.08, 0.16, 0.4)
        end

        -- Class color bar on left
        local classHex = CLASS_COLORS[char.class] or "888888"
        local r = tonumber(classHex:sub(1,2), 16) / 255
        local g = tonumber(classHex:sub(3,4), 16) / 255
        local b = tonumber(classHex:sub(5,6), 16) / 255
        local bar = row:CreateTexture(nil, "ARTWORK")
        bar:SetWidth(3)
        bar:SetPoint("TOPLEFT",    row, "TOPLEFT",    1, -2)
        bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 1,  2)
        bar:SetColorTexture(r, g, b, 1)

        -- Faction icon — centered vertically
        local fTex = row:CreateTexture(nil, "ARTWORK")
        fTex:SetSize(FACTION_SZ, FACTION_SZ)
        fTex:SetPoint("LEFT", row, "LEFT", COL_FACTION, 0)
        local fIcon = FACTION_ICONS[char.faction]
        if fIcon then fTex:SetTexture(fIcon) end

        -- Name (no realm) — centered
        local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameFS:SetPoint("LEFT", row, "LEFT", COL_NAME, 0)
        nameFS:SetWidth(COL_LEVEL - COL_NAME - 4)
        nameFS:SetJustifyH("LEFT")
        nameFS:SetText(string.format("|cff%s%s|r", classHex, char.name or "?"))

        -- Level — centered
        local lvlFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lvlFS:SetPoint("LEFT", row, "LEFT", COL_LEVEL, 0)
        lvlFS:SetText(tostring(char.level or 0))

        -- Primary professions — store parentSkillLine key alongside prof data
        local primaries = {}
        for skillLine, prof in pairs(profs) do
            if prof.isPrimary then
                table.insert(primaries, { prof = prof, skillLine = skillLine })
            end
        end
        table.sort(primaries, function(a, b)
            return (a.prof.name or "") < (b.prof.name or "")
        end)

        for pi, pCol in ipairs({ COL_PRIM1, COL_PRIM2 }) do
            local entry2 = primaries[pi]
            local p      = entry2 and entry2.prof
            local pSL    = entry2 and entry2.skillLine
            if p then
                if p.icon then
                    local tex = row:CreateTexture(nil, "ARTWORK")
                    tex:SetSize(ICON_SZ, ICON_SZ)
                    tex:SetPoint("LEFT", row, "LEFT", pCol, 0)
                    tex:SetTexture(p.icon)
                    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                end
                local total, maxTotal = ProfTotal(p)
                local pct   = maxTotal > 0 and math.floor((total / maxTotal) * 100) or 0
                local color = pct >= 100 and "FFD700" or "DDDDDD"
                local hoverBtn = CreateFrame("Button", nil, row)
                hoverBtn:SetPoint("LEFT", row, "LEFT", pCol, 0)
                hoverBtn:SetSize(80, ROW_H)
                hoverBtn:SetScript("OnEnter", function(self)
                    ShowProfTooltip(self, p, pSL)
                end)
                hoverBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                fs:SetPoint("LEFT", row, "LEFT", pCol + ICON_SZ + 1, 0)
                fs:SetWidth(65)
                fs:SetText(string.format("|cff%s%d|r|cff666666/%d|r", color, total, maxTotal))
            else
                local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                fs:SetPoint("LEFT", row, "LEFT", pCol, 0)
                fs:SetText("|cff555555N/A|r")
            end
        end

        -- Secondary cols — centered
        for _, sec in ipairs(SECONDARY_COLS) do
            SecCell(row, sec.enum, profs, sec.col)
        end

        yOff = yOff - ROW_H
    end

    scrollChild:SetHeight(math.max(CONTENT_HEIGHT, math.abs(yOff) + 20))
end

-- ============================================================
-- Currencies panel (grouped by expansion)
-- ============================================================

-- Placeholder shown when parent "Currencies" node is clicked directly
local function BuildCurrenciesPanel()
    ClearContent()
    ResetScrollFrame()
    local fs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, -8)
    fs:SetText("|cff888888Select an expansion from the left panel.|r")
    scrollChild:SetHeight(CONTENT_HEIGHT)
end

local FACTION_ICONS = {
    Alliance = "Interface\\Icons\\Inv_misc_tournaments_banner_human",
    Horde    = "Interface\\Icons\\Inv_misc_tournaments_banner_orc",
}

--- Shared currency panel builder — used by all currency sub-panels.
--- list = { { id, name, icon }, ... } — defines columns after Name/Lvl.
--- colStart = x offset of first currency column (default 210).
--- colW     = width per currency column (default 52).
local function BuildCurrencyPanel(list, colStart, colW)
    ClearContent()
    ResetScrollFrame()

    colStart = colStart or 210
    colW     = colW     or 52

    local chars   = GetVisibleChars(currentRealmFilter)
    local ROW_H   = 26
    local ICON_SZ = 20
    local COL_FACTION = 4
    local COL_NAME    = 26
    local COL_LVL     = 180

    -- Header row
    local function MakeHdr(text, x)
        local fs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", x, -8)
        fs:SetTextColor(0.80, 0.80, 0.90)
        fs:SetText(text)
    end
    MakeHdr("Name", COL_NAME)
    MakeHdr("Lvl",  COL_LVL)

    -- Icon header per currency column with tooltip
    for ci, curr in ipairs(list) do
        local x      = colStart + (ci - 1) * colW
        local iconX  = x + math.floor((colW - ICON_SZ) / 2)   -- centered in column
        local tex = scrollChild:CreateTexture(nil, "ARTWORK")
        tex:SetSize(ICON_SZ, ICON_SZ)
        tex:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", iconX, -4)
        tex:SetTexture(curr.icon)
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local hoverBtn = CreateFrame("Button", nil, scrollChild)
        hoverBtn:SetSize(ICON_SZ + 4, ICON_SZ + 4)
        hoverBtn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", iconX - 2, -3)
        hoverBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(curr.name, 1, 0.82, 0)
            GameTooltip:Show()
        end)
        hoverBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    MakeDivider(scrollChild, -28)
    local yOff = -32

    -- Character rows
    for i, entry in ipairs(chars) do
        local char = entry.data
        local row  = CreateFrame("Frame", nil, scrollChild)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT",  scrollChild, "TOPLEFT",  0,   yOff)
        row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -20, yOff)

        -- Zebra stripe
        if i % 2 == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.10, 0.08, 0.16, 0.4)
        end

        -- Class color bar
        local classHex = CLASS_COLORS[char.class] or "888888"
        local r = tonumber(classHex:sub(1,2), 16) / 255
        local g = tonumber(classHex:sub(3,4), 16) / 255
        local b = tonumber(classHex:sub(5,6), 16) / 255
        local bar = row:CreateTexture(nil, "ARTWORK")
        bar:SetWidth(3)
        bar:SetPoint("TOPLEFT",    row, "TOPLEFT",    1, -2)
        bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 1,  2)
        bar:SetColorTexture(r, g, b, 1)

        -- Faction icon
        local fTex = row:CreateTexture(nil, "ARTWORK")
        fTex:SetSize(16, 16)
        fTex:SetPoint("LEFT", row, "LEFT", COL_FACTION, 0)
        local fIcon = FACTION_ICONS[char.faction]
        if fIcon then fTex:SetTexture(fIcon) end

        -- Name (no realm, class colored)
        local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameFS:SetPoint("LEFT", row, "LEFT", COL_NAME, 0)
        nameFS:SetWidth(COL_LVL - COL_NAME - 10)
        nameFS:SetJustifyH("LEFT")
        nameFS:SetText(string.format("|cff%s%s|r", classHex, char.name or "?"))

        -- Level
        local lvlFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lvlFS:SetPoint("LEFT", row, "LEFT", COL_LVL, 0)
        lvlFS:SetText(tostring(char.level or 0))

        -- Currency amounts
        for ci, curr in ipairs(list) do
            local x   = colStart + (ci - 1) * colW
            local c   = char.currencies and char.currencies[curr.id]
            local val = c and c.amount or 0
            local fs  = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetPoint("LEFT", row, "LEFT", x, 0)
            fs:SetWidth(colW)
            fs:SetJustifyH("CENTER")
            if val == 0 then
                fs:SetText("|cff444444—|r")
            else
                fs:SetText(tostring(val))
            end
        end

        yOff = yOff - ROW_H
    end

    scrollChild:SetHeight(math.max(CONTENT_HEIGHT, math.abs(yOff) + 20))
end

local function BuildMidnightCurrenciesPanel()
    BuildCurrencyPanel(DAWNCREST_CRESTS)
end

local function BuildMiscCurrenciesPanel()
    BuildCurrencyPanel(MISC_CURRENCIES, 210, 100)
end

local function BuildPvPCurrenciesPanel()
    BuildCurrencyPanel(PVP_CURRENCIES, 210, 100)
end

-- ============================================================
-- Inventory panel
-- ============================================================

local function BuildInventoryPanel()
    ClearContent()
    ResetScrollFrame()

    local searchBox = CreateFrame("EditBox", nil, scrollChild, "SearchBoxTemplate")
    searchBox:SetSize(CONTENT_WIDTH - 40, 24)
    searchBox:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, -6)
    searchBox:SetAutoFocus(false)

    local resultsParent = CreateFrame("Frame", nil, scrollChild)
    resultsParent:SetSize(CONTENT_WIDTH - 20, 20)
    resultsParent:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -38)

    local function RenderResults(query)
        for _, child in ipairs({ resultsParent:GetChildren() }) do child:Hide() end
        for _, region in ipairs({ resultsParent:GetRegions() }) do region:Hide() end

        query = query and query:lower() or ""
        if query == "" then scrollChild:SetHeight(CONTENT_HEIGHT); return end

        local ROW_H, yOff, matches = 22, 0, 0
        local rows = {}

        for key, char in pairs(NW.db.characters) do
            if (not currentRealmFilter or char.realm == currentRealmFilter)
            and not NW.db.settings.hiddenChars[key] then
                for _, src in ipairs({
                    { label = "Bags",    t = char.inventory  },
                    { label = "Reagent", t = char.reagentbag },
                    { label = "Bank",    t = char.bank       },
                }) do
                    if src.t then
                        for itemID, count in pairs(src.t) do
                            local name = C_Item.GetItemInfo(itemID) or ""
                            if name:lower():find(query, 1, true) then
                                table.insert(rows, {
                                    charName = char.name, class = char.class,
                                    source = src.label, itemID = itemID,
                                    itemName = name, count = count,
                                })
                            end
                        end
                    end
                end
                if char.warbank then
                    for itemID, tabCounts in pairs(char.warbank) do
                        local name = C_Item.GetItemInfo(itemID) or ""
                        if name:lower():find(query, 1, true) then
                            for bagID, count in pairs(tabCounts) do
                                local tabName = (char.warbankTabs and char.warbankTabs[bagID])
                                    or ("Tab " .. (bagID - 11))
                                table.insert(rows, {
                                    charName = char.name, class = char.class,
                                    source = "Warbank: " .. tabName,
                                    itemID = itemID, itemName = name, count = count,
                                })
                            end
                        end
                    end
                end
            end
        end
        table.sort(rows, function(a, b) return a.itemName < b.itemName end)

        for _, row in ipairs(rows) do
            local rowFrame = CreateFrame("Frame", nil, resultsParent, "BackdropTemplate")
            rowFrame:SetSize(CONTENT_WIDTH - 40, ROW_H)
            rowFrame:SetPoint("TOPLEFT", resultsParent, "TOPLEFT", 0, yOff)
            if matches % 2 == 0 then
                rowFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
                rowFrame:SetBackdropColor(0.10, 0.08, 0.16, 0.4)
            end
            local itemFS = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            itemFS:SetPoint("LEFT", rowFrame, "LEFT", 4, 0); itemFS:SetText(row.itemName); itemFS:SetWidth(200)
            local charFS = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            charFS:SetPoint("LEFT", rowFrame, "LEFT", 210, 0); charFS:SetText(ColoredName(row.charName, row.class)); charFS:SetWidth(120)
            local srcFS = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            srcFS:SetPoint("LEFT", rowFrame, "LEFT", 336, 0); srcFS:SetTextColor(0.5, 0.7, 1); srcFS:SetText(row.source); srcFS:SetWidth(160)
            local countFS = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            countFS:SetPoint("LEFT", rowFrame, "LEFT", 500, 0); countFS:SetTextColor(1, 0.9, 0.4); countFS:SetText("x" .. row.count)
            yOff = yOff - ROW_H; matches = matches + 1
        end

        if matches == 0 then
            local noResult = resultsParent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            noResult:SetPoint("TOPLEFT", resultsParent, "TOPLEFT", 4, 0)
            noResult:SetTextColor(0.5, 0.5, 0.5)
            noResult:SetText("No items found.")
        end

        resultsParent:SetHeight(math.max(20, matches * ROW_H))
        scrollChild:SetHeight(math.max(CONTENT_HEIGHT, 38 + math.abs(yOff) + 20))
    end

    local searchTimer = nil
    searchBox:SetScript("OnTextChanged", function(self)
        if searchTimer then searchTimer:Cancel() end
        searchTimer = C_Timer.NewTimer(0.4, function() RenderResults(self:GetText()) end)
    end)
    scrollChild:SetHeight(CONTENT_HEIGHT)
end

-- ============================================================
-- Settings panel
-- ============================================================

local fontSizeSlider, fontSizeValueText

local function EnsureFontSizeSlider()
    if fontSizeSlider then return end
    fontSizeSlider = CreateFrame("Slider", nil, UIParent, "OptionsSliderTemplate")
    fontSizeSlider:SetSize(200, 16)
    fontSizeSlider:SetMinMaxValues(10, 16)
    fontSizeSlider:SetValueStep(1)
    fontSizeSlider:SetObeyStepOnDrag(true)
    fontSizeSlider:Hide()
    fontSizeSlider.Low:SetText("10")
    fontSizeSlider.High:SetText("16")
    fontSizeValueText = fontSizeSlider.Text
    fontSizeSlider:SetScript("OnValueChanged", function(_, val)
        val = math.floor(val)
        NW.db.settings.fontSize = val
        fontSizeValueText:SetText(tostring(val))
        if NW.db.settings.font then NW.ApplyFont(NW.db.settings.font) end
    end)
end

local function BuildSettingsPanel()
    EnsureFontSizeSlider()
    ClearContent()
    ResetScrollFrame()

    local LSM  = LibStub and LibStub("LibSharedMedia-3.0", true)
    local yOff = -8

    yOff = SectionHeader(scrollChild, "THEME", yOff)
    local themeOrder = { "midnight","darkblue","darkgreen","parchment","deuteranopia","protanopia","tritanopia" }
    local swatchSize, swatchPad = 28, 6
    for i, themeID in ipairs(themeOrder) do
        local t    = THEMES[themeID]
        local xOff = 4 + (i - 1) * (swatchSize + swatchPad)
        local swatch = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
        swatch:SetSize(swatchSize, swatchSize)
        swatch:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", xOff, yOff)
        swatch:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
        swatch:SetBackdropColor(t.bg[1], t.bg[2], t.bg[3], 1)
        swatch:SetBackdropBorderColor(
            NW.db.settings.theme == themeID and t.accent[1] or 0.3,
            NW.db.settings.theme == themeID and t.accent[2] or 0.3,
            NW.db.settings.theme == themeID and t.accent[3] or 0.3, 1)
        local tip = swatch:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tip:SetPoint("TOP", swatch, "BOTTOM", 0, -2); tip:SetText(themeID); tip:SetTextColor(0.7, 0.7, 0.7)
        swatch:SetScript("OnClick", function() NW.ApplyTheme(themeID); NW.ShowPanel("settings") end)
    end
    yOff = yOff - swatchSize - 24

    yOff = SectionHeader(scrollChild, "FONT", yOff)
    if LSM then
        local fonts    = LSM:List("font")
        local dropH    = 22
        local listH    = math.min(#fonts, 6) * dropH
        local listOpen = false
        local listFrame

        local dropBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
        dropBtn:SetSize(220, dropH)
        dropBtn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, yOff)
        dropBtn:SetText(NW.db.settings.font or "default")

        listFrame = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
        listFrame:SetSize(220, listH)
        listFrame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        listFrame:SetFrameLevel(mainFrame:GetFrameLevel() + 20)
        listFrame:Hide()

        dropBtn:SetScript("OnClick", function()
            listOpen = not listOpen
            if listOpen then
                listFrame:ClearAllPoints()
                listFrame:SetPoint("TOPLEFT", dropBtn, "BOTTOMLEFT", 0, 0)
                listFrame:Show()
            else listFrame:Hide() end
        end)

        local listScroll = CreateFrame("ScrollFrame", nil, listFrame, "UIPanelScrollFrameTemplate")
        listScroll:SetPoint("TOPLEFT",     listFrame, "TOPLEFT",      4,  -4)
        listScroll:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -22,  4)
        local listChild = CreateFrame("Frame", nil, listScroll)
        listChild:SetSize(190, #fonts * dropH)
        listScroll:SetScrollChild(listChild)
        for fi, fname in ipairs(fonts) do
            local row = CreateFrame("Button", nil, listChild)
            row:SetSize(190, dropH)
            row:SetPoint("TOPLEFT", listChild, "TOPLEFT", 0, -(fi - 1) * dropH)
            local rowBg = row:CreateTexture(nil, "BACKGROUND"); rowBg:SetAllPoints(); rowBg:SetColorTexture(0,0,0,0)
            local rowLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            rowLabel:SetPoint("LEFT", row, "LEFT", 4, 0); rowLabel:SetText(fname)
            row:SetScript("OnEnter", function() rowBg:SetColorTexture(0.2,0.2,0.3,0.6) end)
            row:SetScript("OnLeave", function() rowBg:SetColorTexture(0,0,0,0) end)
            row:SetScript("OnClick", function()
                NW.ApplyFont(fname); dropBtn:SetText(fname); listFrame:Hide(); listOpen = false
            end)
        end
        yOff = yOff - dropH - listH - 14
    else
        local noLSM = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        noLSM:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, yOff)
        noLSM:SetText("|cff888888LibSharedMedia not available|r")
        yOff = yOff - 20
    end

    local sliderLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sliderLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, yOff)
    sliderLabel:SetText("Font Size")
    yOff = yOff - 18
    fontSizeSlider:SetParent(scrollChild)
    fontSizeSlider:ClearAllPoints()
    fontSizeSlider:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, yOff)
    fontSizeSlider:SetValue(NW.db.settings.fontSize or 12)
    fontSizeValueText:SetText(tostring(NW.db.settings.fontSize or 12))
    fontSizeSlider:Show()
    yOff = yOff - 36

    -- TOOLTIP MODIFIER
    yOff = SectionHeader(scrollChild, "TOOLTIP MODIFIER", yOff)
    local modLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    modLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, yOff)
    modLabel:SetTextColor(0.7, 0.7, 0.7)
    modLabel:SetText("Hold key when hovering an item to see counts:")
    yOff = yOff - 20

    local modKeys = { "ALT", "CTRL", "SHIFT" }
    for _, key in ipairs(modKeys) do
        local rb = CreateFrame("CheckButton", nil, scrollChild, "UIRadioButtonTemplate")
        rb:SetSize(20, 20)
        rb:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4 + (key == "ALT" and 0 or key == "CTRL" and 70 or 140), yOff)
        rb:SetChecked(NW.db.settings.tooltipModifier == key)
        local lbl = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("LEFT", rb, "RIGHT", 2, 0)
        lbl:SetText(key)
        rb:SetScript("OnClick", function()
            NW.db.settings.tooltipModifier = key
            -- Uncheck siblings by rebuilding — simplest approach
            NW.ShowPanel("settings")
        end)
    end
    yOff = yOff - 28

    -- MINIMAP BUTTON
    yOff = SectionHeader(scrollChild, "MINIMAP BUTTON", yOff)
    local mmCheck = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
    mmCheck:SetSize(24, 24); mmCheck:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, yOff)
    mmCheck:SetChecked(NW.db.settings.minimapButton.show)
    local mmLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mmLabel:SetPoint("LEFT", mmCheck, "RIGHT", 4, 0); mmLabel:SetText("Show minimap button")
    mmCheck:SetScript("OnClick", function(self)
        NW.db.settings.minimapButton.show = self:GetChecked()
        if self:GetChecked() then NW.MinimapButton.Show() else NW.MinimapButton.Hide() end
    end)
    yOff = yOff - 30

    yOff = SectionHeader(scrollChild, "CHARACTER MANAGEMENT", yOff)
    local charList = {}
    for key, data in pairs(NW.db.characters) do table.insert(charList, { key = key, data = data }) end
    table.sort(charList, function(a, b) return (a.data.name or "") < (b.data.name or "") end)
    for _, entry in ipairs(charList) do
        local cb = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
        cb:SetSize(24, 24); cb:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, yOff)
        cb:SetChecked(not NW.db.settings.hiddenChars[entry.key])
        local lbl = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        lbl:SetText(ColoredName(entry.data.name or "?", entry.data.class)
            .. " |cff888888" .. (entry.data.realm or "") .. "|r")
        cb:SetScript("OnClick", function(self)
            if self:GetChecked() then
                NW.db.settings.hiddenChars[entry.key] = nil
            else
                NW.db.settings.hiddenChars[entry.key] = true
            end
            UpdateBottomBar()
        end)
        yOff = yOff - 28
    end

    scrollChild:SetHeight(math.max(CONTENT_HEIGHT, math.abs(yOff) + 20))
end

-- ============================================================
-- Panel router
-- ============================================================

local panelBuilders = {
    characters           = BuildCharacterSummaryPanel,
    professions          = BuildProfessionsPanel,
    currencies           = BuildCurrenciesPanel,
    currencies_midnight  = BuildMidnightCurrenciesPanel,
    currencies_misc      = BuildMiscCurrenciesPanel,
    currencies_pvp       = BuildPvPCurrenciesPanel,
    inventory            = BuildInventoryPanel,
    settings             = BuildSettingsPanel,
}

function NW.ShowPanel(id)
    if not NW.db then return end
    NW.activePanel = id
    SetNavActive(id)
    local builder = panelBuilders[id]
    if builder then builder() end
    UpdateBottomBar()
end

function NW.RefreshUI()
    if NW.activePanel then NW.ShowPanel(NW.activePanel) end
end

-- ============================================================
-- Toggle
-- ============================================================

function NW.ToggleUI()
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
        RebuildNav()
        if not NW.activePanel then
            NW.ShowPanel("characters")
        else
            NW.ShowPanel(NW.activePanel)
        end
        UpdateBottomBar()
    end
end
