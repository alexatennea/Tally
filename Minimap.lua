-- Tally minimap button: left-click shows/hides the panel, right-click opens
-- options, drag to move it around the minimap edge.

local _, ns = ...

local button = CreateFrame("Button", "TallyMinimapButton", Minimap)
button:SetSize(31, 31)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:RegisterForDrag("LeftButton")
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local background = button:CreateTexture(nil, "BACKGROUND")
background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
background:SetSize(20, 20)
background:SetPoint("TOPLEFT", 7, -5)

local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetTexture(ns.ICON)
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
icon:SetSize(17, 17)
icon:SetPoint("TOPLEFT", 7, -6)

local border = button:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT")

local function UpdatePosition()
    local angle = math.rad(ns.db.minimapAngle or 225)
    local radius = (Minimap:GetWidth() / 2) + 10
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx, cy = cx / scale, cy / scale
    ns.db.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
    UpdatePosition()
end

button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", OnDragUpdate)
end)

button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

button:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then
        ns.OpenConfig()
    else
        ns.SetPanelShown(not ns.frame:IsShown())
    end
end)

button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Tally")
    GameTooltip:AddLine("Left-click: show / hide panel", 1, 1, 1)
    GameTooltip:AddLine("Right-click: options", 1, 1, 1)
    GameTooltip:AddLine("Drag: move button", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end)

button:SetScript("OnLeave", function() GameTooltip:Hide() end)

function ns.UpdateMinimapButton()
    button:SetShown(ns.db.showMinimap)
    UpdatePosition()
end
