-- Tally bar: a slim strip across the top or bottom of the screen with every
-- section on one line, and a thin XP progress line along its inner edge.

local _, ns = ...

local C = ns.COLORS
local MUTED_HEX = ns.MUTED_HEX
local SKILL_HEX = "|cffd99e38"

local BAR_H     = 24
local XP_LINE_H = 3
local SIZE      = 12
local GAP       = 12   -- space either side of each separator
local textY     = 0    -- centres text beside the XP line; set by PositionBar

local bar = CreateFrame("Frame", "TallyBar", UIParent)
ns.bar = bar
bar:SetHeight(BAR_H)
bar:SetFrameStrata("MEDIUM")
bar:EnableMouse(true)
bar:Hide()

local bg = bar:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetTexture(ns.FLAT)
bg:SetVertexColor(unpack(C.bg))

-- XP progress line along the edge facing the game world, with rested XP
-- drawn behind it.
local function NewLine(color, alpha)
    local line = CreateFrame("StatusBar", nil, bar)
    line:SetHeight(XP_LINE_H)
    line:SetStatusBarTexture(ns.FLAT)
    line:SetStatusBarColor(color[1], color[2], color[3], alpha or 1)
    return line
end

local lineTrack = bar:CreateTexture(nil, "BORDER")
lineTrack:SetTexture(ns.FLAT)
lineTrack:SetVertexColor(0, 0, 0, 0.8)
lineTrack:SetHeight(XP_LINE_H)

local restedLine = NewLine(C.rested, 0.6)
local xpLine = NewLine(C.accent)
xpLine:SetFrameLevel(restedLine:GetFrameLevel() + 1)

local icon = bar:CreateTexture(nil, "ARTWORK")
icon:SetTexture(ns.ICON)
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
icon:SetSize(15, 15)

local title = ns.NewText(bar, 10, unpack(C.muted))
title:SetPoint("LEFT", icon, "RIGHT", 5, 0)
title:SetText("TALLY")

local function IsBottom()
    return ns.db and ns.db.style == "bottom"
end

-- Anchor the bar to the top or bottom of the screen, with the XP line on the
-- edge facing the game world.
function ns.PositionBar()
    local edge, inner = "TOP", "BOTTOM"
    if IsBottom() then edge, inner = "BOTTOM", "TOP" end
    textY = (edge == "TOP") and (XP_LINE_H / 2) or (-XP_LINE_H / 2)

    bar:ClearAllPoints()
    bar:SetPoint(edge .. "LEFT", UIParent, edge .. "LEFT", 0, 0)
    bar:SetPoint(edge .. "RIGHT", UIParent, edge .. "RIGHT", 0, 0)
    for _, line in ipairs({ lineTrack, restedLine, xpLine }) do
        line:ClearAllPoints()
        line:SetPoint(inner .. "LEFT", bar, inner .. "LEFT", 0, 0)
        line:SetPoint(inner .. "RIGHT", bar, inner .. "RIGHT", 0, 0)
    end
    icon:ClearAllPoints()
    icon:SetPoint("LEFT", bar, "LEFT", 8, textY)
end

---------------------------------------------------------------------------
-- Segments: one text per section, separated by thin vertical lines.
---------------------------------------------------------------------------

local segments = {}

local function GetSegment(i)
    local seg = segments[i]
    if seg then return seg end
    seg = {}
    seg.sep = bar:CreateTexture(nil, "ARTWORK")
    seg.sep:SetTexture(ns.FLAT)
    seg.sep:SetVertexColor(C.muted[1], C.muted[2], C.muted[3], 0.35)
    seg.sep:SetSize(1, 12)
    seg.text = ns.NewText(bar, SIZE)
    segments[i] = seg
    return seg
end

local function SetSegments(texts)
    local x = 8 + 15 + 5 + title:GetStringWidth()
    for i, text in ipairs(texts) do
        local seg = GetSegment(i)
        seg.sep:ClearAllPoints()
        seg.sep:SetPoint("LEFT", bar, "LEFT", x + GAP, textY)
        x = x + GAP * 2 + 1
        seg.text:SetText(text)
        seg.text:ClearAllPoints()
        seg.text:SetPoint("LEFT", bar, "LEFT", x, textY)
        x = x + seg.text:GetStringWidth()
        seg.sep:Show()
        seg.text:Show()
    end
    for i = #texts + 1, #segments do
        segments[i].sep:Hide()
        segments[i].text:Hide()
    end
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------

function ns.RefreshBar()
    local texts = {}
    local xp = ns.GetXPInfo()

    if xp.maxLevel then
        texts[#texts + 1] = "|cff4cd964Max level|r"
        xpLine:Hide()
        restedLine:Hide()
    else
        xpLine:SetMinMaxValues(0, xp.max)
        xpLine:SetValue(xp.cur)
        restedLine:SetMinMaxValues(0, xp.max)
        restedLine:SetValue(math.min(xp.cur + xp.rested, xp.max))
        xpLine:Show()
        restedLine:Show()

        texts[#texts + 1] = MUTED_HEX .. "Time to level|r  " ..
            (xp.eta and ns.FormatDuration(xp.eta) or (MUTED_HEX .. "--|r"))
        local toGo = string.format("%s to go  %s(%d%%)|r", ns.FormatNumber(xp.remaining), MUTED_HEX, xp.percent)
        if xp.kills then
            toGo = toGo .. "  " .. ns.FormatNumber(xp.kills) .. MUTED_HEX .. " kills|r"
        end
        texts[#texts + 1] = toGo
        texts[#texts + 1] = MUTED_HEX .. "Session|r  +" .. ns.FormatNumber(xp.gained) ..
            "  " .. ns.FormatNumber(xp.perHour) .. MUTED_HEX .. " /hr|r"
    end

    local skills = ns.GetShownProfessions()
    if #skills > 0 then
        local parts = {}
        for _, skill in ipairs(skills) do
            parts[#parts + 1] = SKILL_HEX .. skill.name .. "|r " .. skill.rank .. MUTED_HEX .. "/" .. skill.max .. "|r"
        end
        texts[#texts + 1] = table.concat(parts, "    ")
    end

    if ns.db.showGold then
        local gold = ns.GetGoldInfo()
        texts[#texts + 1] = ns.FormatMoney(gold.money) .. "    " .. ns.FormatGoldChange(gold)
    end

    if ns.db.showHonor then
        local rankName, progress, left, right = ns.GetHonorInfo()
        local honor = left .. "  " .. right
        if progress then
            honor = (rankName or "Unranked") .. MUTED_HEX ..
                string.format(" %d%%|r    ", math.floor(progress * 100)) .. honor
        end
        texts[#texts + 1] = honor
    end

    SetSegments(texts)
end

bar:SetScript("OnEnter", function(self)
    ns.ShowTooltip(self, "ANCHOR_CURSOR", "/tally for options.")
end)

bar:SetScript("OnLeave", function() GameTooltip:Hide() end)

---------------------------------------------------------------------------
-- Making room: move default UI frames that sit under the bar out of its way
-- (down for a top bar, up for a bottom bar), and put them back when the bar
-- moves or goes away.
---------------------------------------------------------------------------

-- Frames that commonly sit at each edge of the screen. Only ones anchored to
-- that edge of UIParent and actually overlapping the bar are moved; frames
-- anchored to these (e.g. extra action bars) follow along.
local PUSH_FRAMES = {
    top = {
        "MinimapCluster", "BuffFrame", "DebuffFrame", "PlayerFrame", "TargetFrame",
        "FocusFrame", "UIWidgetTopCenterContainerFrame", "TicketStatusFrame",
    },
    bottom = {
        "MainActionBar", "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight",
        "StanceBar", "PetActionBar", "PossessActionBar", "MicroMenuContainer", "BagsBar",
        "StatusTrackingBarManager", "MainStatusTrackingBarContainer",
        "SecondaryStatusTrackingBarContainer", "UIWidgetBelowMinimapContainerFrame",
    },
}

-- frame -> { y = original y offset, shiftedY = the offset we set, edge = "top"/"bottom" }
local pushed = {}
local pendingAfterCombat = false

local function EditModeOpen()
    return EditModeManagerFrame and EditModeManagerFrame:IsShown()
end

-- Which edge to make room at, or nil for none.
local function PushEdge()
    local db = ns.db
    if not (db and db.style ~= "panel" and db.shown and db.pushUI) or EditModeOpen() then
        return nil
    end
    return IsBottom() and "bottom" or "top"
end

local function Near(a, b)
    return a and b and math.abs(a - b) < 0.5
end

-- Does `frame` reach into the bar's strip at `edge` (compared in screen space)?
local function Overlaps(frame, edge)
    local barSize = BAR_H * bar:GetEffectiveScale()
    local scale = frame:GetEffectiveScale()
    if edge == "top" then
        local top = frame:GetTop()
        return top and top * scale > UIParent:GetTop() * UIParent:GetEffectiveScale() - barSize
    end
    local bottom = frame:GetBottom()
    return bottom and bottom * scale < UIParent:GetBottom() * UIParent:GetEffectiveScale() + barSize
end

local function Restore(frame, info)
    local point, relTo, relPoint, x, y = frame:GetPoint(1)
    if Near(y, info.shiftedY) then
        frame:SetPoint(point, relTo, relPoint, x, info.y)
    end
    pushed[frame] = nil
end

function ns.UpdateUIPush()
    if InCombatLockdown() then
        -- Some of these frames are protected and can't move mid-fight.
        pendingAfterCombat = true
        return
    end
    local edge = PushEdge()

    -- Put back anything pushed for an edge we're no longer using.
    for frame, info in pairs(pushed) do
        if info.edge ~= edge then Restore(frame, info) end
    end
    if not edge then return end

    local anchorWord = (edge == "top") and "TOP" or "BOTTOM"
    for _, name in ipairs(PUSH_FRAMES[edge]) do
        local frame = _G[name]
        if frame and frame.GetNumPoints and frame:GetNumPoints() == 1 then
            local point, relTo, relPoint, x, y = frame:GetPoint(1)
            local info = pushed[frame]
            if info and not Near(y, info.shiftedY) then
                -- Edit Mode (or something else) has repositioned it since.
                pushed[frame], info = nil, nil
            end
            if not info and (relTo == nil or relTo == UIParent) and relPoint
                and relPoint:find(anchorWord) and Overlaps(frame, edge) then
                -- Offsets are in the frame's own scale.
                local shift = BAR_H * bar:GetEffectiveScale() / frame:GetEffectiveScale()
                if edge == "top" then shift = -shift end
                pushed[frame] = { y = y, shiftedY = y + shift, edge = edge }
                frame:SetPoint(point, relTo, relPoint, x, y + shift)
            end
        end
    end
end

local pushEvents = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED", "PLAYER_REGEN_ENABLED",
                         "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
    pcall(pushEvents.RegisterEvent, pushEvents, event)
end
pushEvents:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" and not pendingAfterCombat then return end
    pendingAfterCombat = false
    -- Let Blizzard finish laying out its frames first.
    C_Timer.After(0.2, ns.UpdateUIPush)
end)

-- Put frames back while Edit Mode is open so their real positions get edited,
-- then make room again once it closes.
if EditModeManagerFrame then
    EditModeManagerFrame:HookScript("OnShow", function() ns.UpdateUIPush() end)
    EditModeManagerFrame:HookScript("OnHide", function() C_Timer.After(0.2, ns.UpdateUIPush) end)
end
