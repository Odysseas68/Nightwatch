-- ============================================================
-- Addon   : Nightwatch
-- File    : Core.lua
-- Version : 2026.06.01
-- Desc    : Namespace, DB init, login callbacks, slash commands
-- ============================================================
local addonName, NW = ...

-- ============================================================
-- Version & DB defaults
-- ============================================================

NW.VERSION = "0.1.0"

local DB_DEFAULTS = {
    characters  = {},
    warbank     = {},   -- account-wide: { [itemID] = { [bagID] = count } }
    warbankTabs = {},   -- account-wide: { [bagID] = "Tab Name" }
    guildbanks  = {},   -- per-guild: { ["GuildName-Realm"] = { items={}, tabs={} } }
    settings = {
        showAllRealms   = true,
        theme           = "midnight",
        font            = nil,
        fontSize        = 12,
        minimapButton   = {
            show  = true,
            angle = 45,
        },
        hiddenChars     = {},
        hiddenGuilds    = {},
        navExpanded     = {},
        tooltipModifier = "ALT",
    },
}

-- ============================================================
-- Login callbacks
-- ============================================================

NW.loginCallbacks = {}

--- Registers a function to be called on PLAYER_LOGIN.
function NW.RegisterOnLogin(fn)
    table.insert(NW.loginCallbacks, fn)
end

-- ============================================================
-- Debug engine
-- ============================================================

NW.debugEnabled = false

--- Prints a formatted debug message if debug mode is on.
function NW.LogDebug(module, msg)
    if not NW.debugEnabled then return end
    print(string.format("|cff888888[Nightwatch:%s]|r %s", module, msg))
end

-- ============================================================
-- DB init
-- ============================================================

--- Merges missing default keys into an existing table (shallow).
local function ApplyDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if target[k] == nil then
            if type(v) == "table" then
                target[k] = CopyTable(v)
            else
                target[k] = v
            end
        end
    end
end

--- Called on ADDON_LOADED; initialises NightwatchDB and NW.db shorthand.
local function InitDB()
    if type(NightwatchDB) ~= "table" then
        NightwatchDB = CopyTable(DB_DEFAULTS)
    else
        ApplyDefaults(NightwatchDB, DB_DEFAULTS)
        ApplyDefaults(NightwatchDB.settings, DB_DEFAULTS.settings)
    end
    ApplyDefaults(NightwatchDB.settings.minimapButton, DB_DEFAULTS.settings.minimapButton)

    -- Remove stale settings keys
    NightwatchDB.settings.trackedCurrencies = nil

    -- Migrate warbank data from character entries to account level
    -- Only runs once — if NightwatchDB.warbank is already populated skip
    if not next(NightwatchDB.warbank) then
        local bestTime = 0
        for _, char in pairs(NightwatchDB.characters) do
            local lastSeen = char.lastSeen or 0
            if lastSeen > bestTime and char.warbank and next(char.warbank) then
                bestTime = lastSeen
                NightwatchDB.warbank     = CopyTable(char.warbank)
                NightwatchDB.warbankTabs = CopyTable(char.warbankTabs or {})
            end
        end
    end

    -- Clear per-character warbank data — no longer stored here
    for _, char in pairs(NightwatchDB.characters) do
        char.warbank     = nil
        char.warbankTabs = nil
        -- Migrate: ensure guild field exists on all character entries
        if char.guild == nil then char.guild = "" end
    end

    NW.db = NightwatchDB
end

-- ============================================================
-- Slash commands
-- ============================================================

--- Dispatch table for /nw sub-commands.
local slashHandlers = {
    debug = function()
        NW.debugEnabled = not NW.debugEnabled
        print(string.format("|cffA78BFANightwatch|r debug %s",
            NW.debugEnabled and "|cff55FF55ON|r" or "|cffFF5555OFF|r"))
    end,
    prof = function()
        if NW.DumpProfessionLines then NW.DumpProfessionLines() end
    end,
}

local function OnSlashCommand(input)
    local cmd = strtrim(input):lower()
    local handler = slashHandlers[cmd]
    if handler then
        handler()
    elseif NW.ToggleUI then
        NW.ToggleUI()
    else
        NW.LogDebug("Core", "UI not yet loaded")
    end
end

SLASH_NIGHTWATCH1 = "/nw"
SlashCmdList["NIGHTWATCH"] = OnSlashCommand

-- ============================================================
-- Event frame
-- ============================================================

local frame = CreateFrame("Frame")

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= addonName then return end
        InitDB()
        NW.LogDebug("Core", "DB initialised — v" .. NW.VERSION)

    elseif event == "PLAYER_LOGIN" then
        for _, fn in ipairs(NW.loginCallbacks) do fn() end
        NW.LogDebug("Core", "Player login fired")
    end
end)

-- Addon compartment button click handler (global required by TOC)
function Nightwatch_OnAddonCompartmentClick()
    if NW.ToggleUI then NW.ToggleUI() end
end