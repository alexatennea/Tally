-- Tally profession clicks: clicking a profession on the panel or bar opens
-- its window. Opening one means casting its spell, which addons can only do
-- through Blizzard's secure action buttons. Those can't be moved in combat,
-- so they sit on top of the profession text, parented to UIParent (not
-- anchored to our frames, which would make them protected too), and are
-- lined up again out of combat whenever the layout changes.

local _, ns = ...

-- In WoW Forever every profession, gathering ones included, opens its own
-- tab by casting the profession's spell. Fishing is the exception: casting
-- it would start fishing, so it isn't clickable.
local NOT_CLICKABLE = { Fishing = true }

-- The spell that opens a profession's window, or nil if it shouldn't be clicked.
function ns.ProfessionSpell(name)
    if NOT_CLICKABLE[name] then return nil end
    return name
end

local buttons = {}
local targets = {}  -- { {region = frame or fontstring, name = "Tailoring", spell = "Tailoring"}, ... }
local syncQueued, needsSyncAfterCombat = false, false

local function OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(self.professionName)
    GameTooltip:AddLine("Click to open", 1, 1, 1)
    GameTooltip:Show()
end

local function GetButton(i)
    local button = buttons[i]
    if button then return button end
    button = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    -- Register both: the template acts on whichever the ActionButtonUseKeyDown setting says.
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("type", "spell")
    button:SetFrameStrata("MEDIUM")
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture(ns.FLAT)
    highlight:SetVertexColor(1, 1, 1, 0.08)
    button:SetScript("OnEnter", OnEnter)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    buttons[i] = button
    return button
end

-- Place a button over each target's on-screen rectangle.
local function Sync()
    syncQueued = false
    if InCombatLockdown() then
        needsSyncAfterCombat = true
        return
    end
    local uiScale = UIParent:GetEffectiveScale()
    local used = 0
    for _, target in ipairs(targets) do
        local region = target.region
        local left, bottom, width, height = region:GetRect()
        if target.spell and left and width > 0 and region:IsVisible() then
            used = used + 1
            local button = GetButton(used)
            local scale = region:GetEffectiveScale() / uiScale
            button:ClearAllPoints()
            button:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * scale, bottom * scale)
            button:SetSize(width * scale, height * scale)
            button:SetFrameLevel(ns.ActiveDisplay():GetFrameLevel() + 20)
            button:SetAttribute("spell", target.spell)
            button.professionName = target.name
            button:Show()
        end
    end
    for i = used + 1, #buttons do
        buttons[i]:Hide()
    end
end

-- Called by the displays after laying out their professions. The buttons are
-- placed on the next frame, once the new layout has been measured.
function ns.SetProfessionClickTargets(newTargets)
    targets = newTargets
    if not syncQueued then
        syncQueued = true
        C_Timer.After(0, Sync)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
    if needsSyncAfterCombat then
        needsSyncAfterCombat = false
        Sync()
    end
end)
