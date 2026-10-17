-- Tally floating panel: a movable box with the XP, profession, gold and honor
-- sections stacked vertically.

local _, ns = ...

local C = ns.COLORS
local MUTED_HEX = ns.MUTED_HEX
local NewText = ns.NewText

-- Font sizes, in one place so they're easy to tune.
local SIZE_TITLE   = 10
local SIZE_ETA     = 15
local SIZE_BAR     = 11
local SIZE_DETAIL  = 11
local SIZE_SKILL   = 11

-- Layout, in pixels.
local WIDTH        = 250
local PAD          = 8
local XP_BAR_H     = 20
local ROW_BAR_H    = 18
local TEXT_ROW_H   = 14
local ROW_GAP      = 3
local SECTION_GAP  = 8

local function NewBox(parent)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetBackdrop({ bgFile = ns.FLAT, edgeFile = ns.FLAT, edgeSize = 1 })
    box:SetBackdropColor(0, 0, 0, 0.6)
    box:SetBackdropBorderColor(0, 0, 0, 1)
    return box
end

local function NewStatusBar(parent, color, alpha)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", -1, 1)
    bar:SetStatusBarTexture(ns.BAR_TEXTURE)
    bar:SetStatusBarColor(color[1], color[2], color[3], alpha or 1)
    return bar
end

-- A bordered bar with a label on the left and a value on the right.
local function NewLabelledBar(parent, color)
    local row = NewBox(parent)
    row:SetHeight(ROW_BAR_H)
    row.bar = NewStatusBar(row, color, 0.85)
    row.left = NewText(row.bar, SIZE_SKILL)
    row.left:SetPoint("LEFT", 6, 0)
    row.right = NewText(row.bar, SIZE_SKILL)
    row.right:SetPoint("RIGHT", -6, 0)
    return row
end

-- A plain line of text with a left and right part.
local function NewTextRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(TEXT_ROW_H)
    row.left = NewText(row, SIZE_DETAIL)
    row.left:SetPoint("LEFT", 0, 0)
    row.right = NewText(row, SIZE_DETAIL)
    row.right:SetPoint("RIGHT", 0, 0)
    return row
end

---------------------------------------------------------------------------
-- Frame and header
---------------------------------------------------------------------------

local frame = CreateFrame("Frame", "TallyFrame", UIParent, "BackdropTemplate")
ns.panel = frame
frame:SetSize(WIDTH, 80)
frame:SetFrameStrata("MEDIUM")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop({ bgFile = ns.FLAT, edgeFile = ns.FLAT, edgeSize = 1 })
frame:SetBackdropColor(unpack(C.bg))
frame:SetBackdropBorderColor(unpack(C.border))
frame:Hide()

-- Thin accent stripe along the top edge.
local accent = frame:CreateTexture(nil, "ARTWORK")
accent:SetTexture(ns.FLAT)
accent:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.9)
accent:SetPoint("TOPLEFT", 1, -1)
accent:SetPoint("TOPRIGHT", -1, -1)
accent:SetHeight(2)

local icon = frame:CreateTexture(nil, "ARTWORK")
icon:SetTexture(ns.ICON)
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)  -- trim the default icon border
icon:SetSize(16, 16)
icon:SetPoint("TOPLEFT", PAD, -9)

local title = NewText(frame, SIZE_TITLE, unpack(C.muted))
title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
title:SetText("TALLY")

local HEADER_H = 31  -- y where content starts below the header

---------------------------------------------------------------------------
-- Sections
---------------------------------------------------------------------------

local ETA_ROW_H = 18
local etaRow = CreateFrame("Frame", nil, frame)
etaRow:SetHeight(ETA_ROW_H)
local etaLabel = NewText(etaRow, SIZE_DETAIL, unpack(C.muted))
etaLabel:SetPoint("LEFT", 0, 0)
local eta = NewText(etaRow, SIZE_ETA)
eta:SetPoint("RIGHT", 0, 0)
eta:SetJustifyH("RIGHT")

-- XP bar, with rested XP drawn behind it the way the default UI does.
local xpBox = NewBox(frame)
xpBox:SetHeight(XP_BAR_H)
local restedBar = NewStatusBar(xpBox, C.rested, 0.5)
local xpBar = NewStatusBar(xpBox, C.accent)
xpBar:SetFrameLevel(restedBar:GetFrameLevel() + 1)
local xpText = NewText(xpBar, SIZE_BAR)
xpText:SetPoint("CENTER", 0, 0)

local xpSession = NewTextRow(frame)

local skillRows = {}
local function GetSkillRow(i)
    if not skillRows[i] then
        skillRows[i] = NewLabelledBar(frame, C.skill)
    end
    return skillRows[i]
end

local goldRow = NewTextRow(frame)
local honorBar = NewLabelledBar(frame, C.honor)
local honorRow = NewTextRow(frame)

---------------------------------------------------------------------------
-- Layout and refresh
---------------------------------------------------------------------------

-- Anchor a full-width row at `y` pixels below the top and return the next y.
local function Place(row, y, height)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
    row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -y)
    row:Show()
    return y + height
end

local function RefreshXP(y)
    local xp = ns.GetXPInfo()
    if xp.maxLevel then
        etaLabel:SetText("|cff4cd964Max level|r")
        eta:SetText("")
        xpBox:Hide()
        xpSession:Hide()
        return Place(etaRow, y, ETA_ROW_H)
    end
    etaLabel:SetText("Time to level")
    eta:SetText(xp.eta and ns.FormatDuration(xp.eta) or (MUTED_HEX .. "--|r"))

    xpBar:SetMinMaxValues(0, xp.max)
    xpBar:SetValue(xp.cur)
    restedBar:SetMinMaxValues(0, xp.max)
    restedBar:SetValue(math.min(xp.cur + xp.rested, xp.max))
    local barLabel = string.format("%s to go  (%d%%)", ns.FormatNumber(xp.remaining), xp.percent)
    if xp.kills then
        -- "||" is an escaped pipe; a single "|" starts a WoW text escape.
        barLabel = barLabel .. MUTED_HEX .. "  ||  |r" .. ns.FormatNumber(xp.kills) .. " kills"
    end
    xpText:SetText(barLabel)

    xpSession.left:SetText(MUTED_HEX .. "Session|r  +" .. ns.FormatNumber(xp.gained))
    xpSession.right:SetText(ns.FormatNumber(xp.perHour) .. MUTED_HEX .. " /hr|r")

    y = Place(etaRow, y, ETA_ROW_H) + 5
    y = Place(xpBox, y, XP_BAR_H) + 6
    return Place(xpSession, y, TEXT_ROW_H)
end

local function RefreshProfessions(y)
    local skills = ns.GetShownProfessions()
    for i, skill in ipairs(skills) do
        local row = GetSkillRow(i)
        row.bar:SetMinMaxValues(0, skill.max)
        row.bar:SetValue(skill.rank)
        row.left:SetText(skill.name)
        row.right:SetText(skill.rank .. MUTED_HEX .. " / " .. skill.max .. "|r")
        y = Place(row, y + (i == 1 and SECTION_GAP or ROW_GAP), ROW_BAR_H)
    end
    for i = #skills + 1, #skillRows do
        skillRows[i]:Hide()
    end
    return y
end

local function RefreshGold(y)
    if not ns.db.showGold then
        goldRow:Hide()
        return y
    end
    local gold = ns.GetGoldInfo()
    goldRow.left:SetText(ns.FormatMoney(gold.money))
    goldRow.right:SetText(ns.FormatGoldChange(gold))
    return Place(goldRow, y + SECTION_GAP, TEXT_ROW_H)
end

local function RefreshHonor(y)
    if not ns.db.showHonor then
        honorBar:Hide()
        honorRow:Hide()
        return y
    end
    local rankName, progress, left, right = ns.GetHonorInfo()
    honorRow.left:SetText(left)
    honorRow.right:SetText(right)

    if progress then
        honorBar.bar:SetMinMaxValues(0, 1)
        honorBar.bar:SetValue(progress)
        honorBar.left:SetText(rankName or "Unranked")
        honorBar.right:SetText(string.format("%d%%", math.floor(progress * 100)))
        y = Place(honorBar, y + SECTION_GAP, ROW_BAR_H)
        return Place(honorRow, y + ROW_GAP + 1, TEXT_ROW_H)
    end
    honorBar:Hide()
    return Place(honorRow, y + SECTION_GAP, TEXT_ROW_H)
end

function ns.RefreshPanel()
    local y = HEADER_H
    y = RefreshXP(y)
    y = RefreshProfessions(y)
    y = RefreshGold(y)
    y = RefreshHonor(y)
    frame:SetHeight(y + PAD)
end

---------------------------------------------------------------------------
-- Interaction
---------------------------------------------------------------------------

frame:SetScript("OnDragStart", function(self)
    if not ns.db.locked then self:StartMoving() end
end)

frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    ns.db.point = { point, "UIParent", relPoint, x, y }
end)

frame:SetScript("OnEnter", function(self)
    ns.ShowTooltip(self, "ANCHOR_BOTTOM", "Drag to move. /tally for options.")
end)

frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
