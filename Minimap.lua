local addonName, NW = ...

-- ============================================================
-- Minimap button
-- ============================================================

NW.MinimapButton = {}

local ICON_PATH = "Interface\\AddOns\\Nightwatch\\Media\\icon\\Minimap"

local button    -- frame reference, set in CreateButton

-- ============================================================
-- Angle helpers
-- ============================================================

--- Converts a 0-360 degree angle to (x, y) offsets on the minimap edge.
local function AngleToOffset(deg)
    local rad = math.rad(deg)
    return math.cos(rad) * 80, math.sin(rad) * 80
end

--- Converts a world-space delta from minimap centre to a 0-360 degree angle.
local function OffsetToAngle(dx, dy)
    local deg = math.deg(math.atan2(dy, dx))
    if deg < 0 then deg = deg + 360 end
    return deg
end

--- Moves the button to the saved angle position.
local function UpdatePosition()
    local angle = NW.db.settings.minimapButton.angle
    local x, y  = AngleToOffset(angle)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- ============================================================
-- Dropdown menu
-- ============================================================

local function OpenDropdown()
    Menu.CreateContextMenu(button, function(owner, rootDescription)
        rootDescription:CreateTitle("Nightwatch")
        rootDescription:CreateButton("Toggle UI", function() NW.ToggleUI() end)
        rootDescription:CreateButton("Hide Button", function()
            NW.db.settings.minimapButton.show = false
            NW.MinimapButton.Hide()
        end)
    end)
end

-- ============================================================
-- Drag handling
-- ============================================================

local function OnDragStart()
    button:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale  = UIParent:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        local angle = OffsetToAngle(cx - mx, cy - my)
        NW.db.settings.minimapButton.angle = angle
        UpdatePosition()
    end)
end

local function OnDragStop()
    button:SetScript("OnUpdate", nil)
end

-- ============================================================
-- Button construction
-- ============================================================

local function CreateButton()
    button = CreateFrame("Button", "NightwatchMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetClampedToScreen(false)

    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture(ICON_PATH)
    icon:SetSize(24, 24)
    icon:SetPoint("CENTER")

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(56, 56)
    border:SetPoint("CENTER")

    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    button:SetScript("OnClick", function(_, btn)
        if btn == "LeftButton" then
            if NW.ToggleUI then NW.ToggleUI() end
        elseif btn == "RightButton" then
            OpenDropdown()
        end
    end)

    button:SetScript("OnDragStart", OnDragStart)
    button:SetScript("OnDragStop",  OnDragStop)

    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetText("Nightwatch", 0.66, 0.42, 0.98)
        GameTooltip:AddLine("Left-click to toggle", 1, 1, 1)
        GameTooltip:AddLine("Right-click for options", 1, 1, 1)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- ============================================================
-- Public API
-- ============================================================

--- Shows the minimap button at its saved position.
function NW.MinimapButton.Show()
    if not button then CreateButton() end
    UpdatePosition()
    button:Show()
end

--- Hides the minimap button.
function NW.MinimapButton.Hide()
    if button then button:Hide() end
end

-- ============================================================
-- Login hook
-- ============================================================

NW.RegisterOnLogin(function()
    if NW.db.settings.minimapButton.show then
        NW.MinimapButton.Show()
    end
end)
