-- ============================================================
-- Addon   : Nightwatch
-- File    : Debug.lua
-- Version : 2026.05.24
-- Desc    : Debug console — buffered log viewer, /nwdebug toggle
-- ============================================================
local addonName, NW = ...

-- ============================================================
-- Debug console
-- ============================================================

local MAX_LINES  = 200
local logBuffer  = {}  -- { text = "..." } entries, capped at MAX_LINES

local frame       -- main frame, built lazily on first open
local scrollChild -- grows with content
local lineFrames  = {}  -- FontString pool

NW.Debug = {}

-- ============================================================
-- Buffer
-- ============================================================

--- Appends a timestamped line to the log buffer, dropping oldest if over cap.
local function BufferLine(text)
    local ts = date("%H:%M:%S")
    table.insert(logBuffer, string.format("[%s] %s", ts, text))
    if #logBuffer > MAX_LINES then
        table.remove(logBuffer, 1)
    end
end

-- ============================================================
-- Override NW.LogDebug
-- ============================================================

local _originalLogDebug = NW.LogDebug

--- Replaces NW.LogDebug to also buffer output for the debug console.
function NW.LogDebug(module, msg)
    if not NW.debugEnabled then return end
    _originalLogDebug(module, msg)
    BufferLine(string.format("[Nightwatch:%s] %s", module, msg))
    if frame and frame:IsShown() then
        NW.Debug.Refresh()
    end
end

-- ============================================================
-- Frame construction
-- ============================================================

local FRAME_W = 600
local FRAME_H = 400

local function BuildFrame()
    frame = CreateFrame("Frame", "NightwatchDebugFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_W, FRAME_H)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop",  frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)

    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = false, edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.10, 1.0)
    frame:SetBackdropBorderColor(0.30, 0.20, 0.50, 1.0)

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -14)
    title:SetText("|cffA78BFANightwatch|r Debug")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Clear button
    local clearBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clearBtn:SetSize(80, 22)
    clearBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 10)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        logBuffer = {}
        NW.Debug.Refresh()
    end)

    -- Copy box — shows full log as selectable text
    local copyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    copyBtn:SetSize(100, 22)
    copyBtn:SetPoint("BOTTOMLEFT", clearBtn, "BOTTOMRIGHT", 8, 0)
    copyBtn:SetText("Select All")
    copyBtn:SetScript("OnClick", function()
        -- Build full log text and show in a popup editbox
        local fullText = table.concat(logBuffer, "\n")
        local popup = CreateFrame("Frame", "NWDebugCopyFrame", UIParent, "BackdropTemplate")
        popup:SetSize(580, 200)
        popup:SetPoint("BOTTOM", frame, "TOP", 0, 4)
        popup:SetFrameStrata("TOOLTIP")
        popup:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        popup:SetBackdropColor(0.05, 0.05, 0.10, 1.0)
        popup:SetBackdropBorderColor(0.30, 0.20, 0.50, 1.0)

        local eb = CreateFrame("EditBox", nil, popup)
        eb:SetPoint("TOPLEFT", popup, "TOPLEFT", 8, -8)
        eb:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -8, 8)
        eb:SetMultiLine(true)
        eb:SetAutoFocus(true)
        eb:SetFontObject("ChatFontNormal")
        eb:SetText(fullText)
        eb:HighlightText()
        eb:SetScript("OnEscapePressed", function() popup:Hide() end)
        popup:Show()
    end)

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     frame, "TOPLEFT",  12, -36)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 40)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(FRAME_W - 50, 1)
    scrollFrame:SetScrollChild(scrollChild)

    frame._scrollFrame = scrollFrame
end

-- ============================================================
-- Render
-- ============================================================

--- Rebuilds the visible log lines from logBuffer.
function NW.Debug.Refresh()
    if not frame then return end

    local ROW_H = 14
    local count = #logBuffer

    for i = 1, count do
        if not lineFrames[i] then
            local fs = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, -(i - 1) * ROW_H)
            fs:SetWidth(FRAME_W - 60)
            fs:SetJustifyH("LEFT")
            lineFrames[i] = fs
        end
        lineFrames[i]:SetText(logBuffer[i])
        lineFrames[i]:Show()
    end

    for i = count + 1, #lineFrames do
        lineFrames[i]:Hide()
    end

    scrollChild:SetHeight(math.max(FRAME_H - 80, count * ROW_H))
    frame._scrollFrame:SetVerticalScroll(
        math.max(0, scrollChild:GetHeight() - frame._scrollFrame:GetHeight())
    )
end

-- ============================================================
-- Public API
-- ============================================================

--- Toggles the debug console open/closed.
function NW.Debug.Toggle()
    if not frame then BuildFrame() end
    if frame:IsShown() then
        frame:Hide()
    else
        NW.Debug.Refresh()
        frame:Show()
    end
end

-- ============================================================
-- Slash command
-- ============================================================

SLASH_NIGHTWATCHDEBUG1 = "/nwdebug"
SlashCmdList["NIGHTWATCHDEBUG"] = function()
    NW.Debug.Toggle()
end
