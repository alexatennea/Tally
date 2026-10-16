-- Tally panel: the on-screen frame and its sections (XP, professions, gold, honor).

local _, ns = ...

local FLAT = "Interface\\Buttons\\WHITE8x8"
local BAR = "Interface\\TargetingFrame\\UI-StatusBar"

local COLOR_BG      = { 0.06, 0.06, 0.08, 0.88 }
local COLOR_BORDER  = { 0, 0, 0, 1 }
local COLOR_ACCENT  = { 0.36, 0.55, 1.00 }   -- XP blue
local COLOR_RESTED  = { 0.55, 0.30, 0.85 }   -- rested purple
local COLOR_MUTED   = { 0.62, 0.64, 0.70 }
local COLOR_SKILL   = { 0.85, 0.62, 0.22 }   -- profession amber
local COLOR_HONOR   = { 0.80, 0.25, 0.25 }   -- honor red
local MUTED_HEX     = "|cff9ea3b3"

-- Font sizes, in one place so they're easy to tune.
local FONT = STANDARD_TEXT_FONT
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

local function NewText(parent, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, size, "")
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
    fs:SetTextColor(r or 1, g or 1, b or 1)
    return fs
end

local function NewBox(parent)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    box:SetBackdropColor(0, 0, 0, 0.6)
    box:SetBackdropBorderColor(0, 0, 0, 1)
    return box
end

local function NewStatusBar(parent, color, alpha)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", -1, 1)
    bar:SetStatusBarTexture(BAR)
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
ns.frame = frame
frame:SetSize(WIDTH, 80)
frame:SetFrameStrata("MEDIUM")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
frame:SetBackdropColor(unpack(COLOR_BG))
frame:SetBackdropBorderColor(unpack(COLOR_BORDER))

-- Thin accent stripe along the top edge.
local accent = frame:CreateTexture(nil, "ARTWORK")
accent:SetTexture(FLAT)
accent:SetVertexColor(COLOR_ACCENT[1], COLOR_ACCENT[2], COLOR_ACCENT[3], 0.9)
accent:SetPoint("TOPLEFT", 1, -1)
accent:SetPoint("TOPRIGHT", -1, -1)
accent:SetHeight(2)

local icon = frame:CreateTexture(nil, "ARTWORK")
icon:SetTexture(ns.ICON)
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)  -- trim the default icon border
icon:SetSize(16, 16)
icon:SetPoint("TOPLEFT", PAD, -9)

local title = NewText(frame, SIZE_TITLE, unpack(COLOR_MUTED))
title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
title:SetText("TALLY")

local HEADER_H = 31  -- y where content starts below the header

---------------------------------------------------------------------------
-- Time to level row
---------------------------------------------------------------------------

local ETA_ROW_H = 18
local etaRow = CreateFrame("Frame", nil, frame)
etaRow:SetHeight(ETA_ROW_H)
local etaLabel = NewText(etaRow, SIZE_DETAIL, unpack(COLOR_MUTED))
etaLabel:SetPoint("LEFT", 0, 0)
local eta = NewText(etaRow, SIZE_ETA)
eta:SetPoint("RIGHT", 0, 0)
eta:SetJustifyH("RIGHT")

---------------------------------------------------------------------------
-- XP section
---------------------------------------------------------------------------

-- XP bar, with rested XP drawn behind it the way the default UI does.
local xpBox = NewBox(frame)
xpBox:SetHeight(XP_BAR_H)
local restedBar = NewStatusBar(xpBox, COLOR_RESTED, 0.5)
local xpBar = NewStatusBar(xpBox, COLOR_ACCENT)
xpBar:SetFrameLevel(restedBar:GetFrameLevel() + 1)
local xpText = NewText(xpBar, SIZE_BAR)
xpText:SetPoint("CENTER", 0, 0)

local xpSession = NewTextRow(frame)

---------------------------------------------------------------------------
-- Professions section
---------------------------------------------------------------------------

local PRIMARY_HEADERS, SECONDARY_HEADERS = {}, {}
for _, name in ipairs({ TRADE_SKILLS, "Professions" }) do
    if name then PRIMARY_HEADERS[(name:gsub(":$", ""))] = true end
end
for _, name in ipairs({ SECONDARY_SKILLS, "Secondary Skills" }) do
    if name then SECONDARY_HEADERS[(name:gsub(":$", ""))] = true end
end

-- Returns { {name=, rank=, max=, primary=bool}, ... }.
-- Skills under a collapsed header in the Skills tab aren't visible to the
-- API, so expand them there if one goes missing.
local function GetProfessionSkills()
    local list = {}
    if GetNumSkillLines and GetSkillLineInfo then
        local group
        for i = 1, GetNumSkillLines() do
            local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
            if isHeader then
                local key = name and name:gsub(":$", "")
                group = (PRIMARY_HEADERS[key] and "primary") or (SECONDARY_HEADERS[key] and "secondary") or nil
            elseif group and name and maxRank and maxRank > 0 then
                list[#list + 1] = { name = name, rank = rank, max = maxRank, primary = (group == "primary") }
            end
        end
    elseif GetProfessions and GetProfessionInfo then
        -- Retail-style API: the first two slots are primary professions.
        local slots = { GetProfessions() }
        for i = 1, 6 do
            local index = slots[i]
            if index then
                local name, _, rank, maxRank = GetProfessionInfo(index)
                if name and maxRank and maxRank > 0 then
                    list[#list + 1] = { name = name, rank = rank, max = maxRank, primary = (i <= 2) }
                end
            end
        end
    end
    return list
end

local skillRows = {}

local function GetSkillRow(i)
    if not skillRows[i] then
        skillRows[i] = NewLabelledBar(frame, COLOR_SKILL)
    end
    return skillRows[i]
end

---------------------------------------------------------------------------
-- Gold section
---------------------------------------------------------------------------

local goldRow = NewTextRow(frame)

---------------------------------------------------------------------------
-- Honor section
---------------------------------------------------------------------------

local honorBar = NewLabelledBar(frame, COLOR_HONOR)
local honorRow = NewTextRow(frame)

-- Classic-style rank and weekly honor if the client has them, otherwise the
-- honor currency. Returns rankName, rankProgress (0-1 or nil), leftText, rightText.
local function GetHonorInfo()
    local rankName, progress
    if UnitPVPRank and GetPVPRankInfo then
        rankName = GetPVPRankInfo(UnitPVPRank("player"))
        if GetPVPRankProgress then progress = GetPVPRankProgress() end
    end
    if not progress then rankName = nil end  -- no rank data on this client

    if GetPVPSessionStats and GetPVPThisWeekStats then
        local todayHK = GetPVPSessionStats() or 0
        local _, weekHonor = GetPVPThisWeekStats()
        return rankName, progress,
            MUTED_HEX .. "Today|r  " .. ns.FormatNumber(todayHK) .. MUTED_HEX .. " HKs|r",
            MUTED_HEX .. "Week|r  " .. ns.FormatNumber(weekHonor or 0) .. MUTED_HEX .. " honor|r"
    end

    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        for _, id in ipairs({ 1901, 1792 }) do
            local info = C_CurrencyInfo.GetCurrencyInfo(id)
            if info and info.name and info.name ~= "" then
                return rankName, progress,
                    MUTED_HEX .. info.name .. "|r",
                    ns.FormatNumber(info.quantity or 0)
            end
        end
    end
    return rankName, progress, MUTED_HEX .. "Honor unavailable|r", ""
end

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
    if ns.IsMaxLevel() then
        etaLabel:SetText("|cff4cd964Max level|r")
        eta:SetText("")
        xpBox:Hide()
        xpSession:Hide()
        return Place(etaRow, y, ETA_ROW_H)
    end
    etaLabel:SetText("Time to level")

    local cur, max = UnitXP("player"), UnitXPMax("player")
    local remaining = max - cur
    local gained = ns.session.xp or 0
    local rate = ns.XPRate()
    local perHour = rate * 3600
    local rested = (GetXPExhaustion and GetXPExhaustion()) or 0
    local safeMax = max > 0 and max or 1

    if rate > 0 then
        eta:SetText(ns.FormatDuration(remaining / rate))
    else
        eta:SetText(MUTED_HEX .. "--|r")
    end

    xpBar:SetMinMaxValues(0, safeMax)
    xpBar:SetValue(cur)
    restedBar:SetMinMaxValues(0, safeMax)
    restedBar:SetValue(math.min(cur + rested, max))
    local barLabel = string.format("%s to go  (%d%%)", ns.FormatNumber(remaining), math.floor(cur / safeMax * 100))
    local kills = ns.db.showKills and ns.KillsToLevel(remaining)
    if kills then
        -- "||" is an escaped pipe; a single "|" starts a WoW text escape.
        barLabel = barLabel .. MUTED_HEX .. "  ||  |r" .. ns.FormatNumber(kills) .. " kills"
    end
    xpText:SetText(barLabel)

    xpSession.left:SetText(MUTED_HEX .. "Session|r  +" .. ns.FormatNumber(gained))
    xpSession.right:SetText(ns.FormatNumber(perHour) .. MUTED_HEX .. " /hr|r")

    y = Place(etaRow, y, ETA_ROW_H) + 5
    y = Place(xpBox, y, XP_BAR_H) + 6
    return Place(xpSession, y, TEXT_ROW_H)
end

local function RefreshProfessions(y)
    local db = ns.db
    local shown = 0
    if db.showProfessions then
        for _, skill in ipairs(GetProfessionSkills()) do
            if (skill.primary and db.showPrimary) or (not skill.primary and db.showSecondary) then
                shown = shown + 1
                local row = GetSkillRow(shown)
                row.bar:SetMinMaxValues(0, skill.max)
                row.bar:SetValue(skill.rank)
                row.left:SetText(skill.name)
                row.right:SetText(skill.rank .. MUTED_HEX .. " / " .. skill.max .. "|r")
                y = Place(row, y + (shown == 1 and SECTION_GAP or ROW_GAP), ROW_BAR_H)
            end
        end
    end
    for i = shown + 1, #skillRows do
        skillRows[i]:Hide()
    end
    return y
end

local function RefreshGold(y)
    if not ns.db.showGold then
        goldRow:Hide()
        return y
    end
    local money = GetMoney()
    local gained = money - (ns.session.startMoney or money)
    local elapsed = ns.SessionElapsed()
    -- Round the rate to whole silver so the line stays short.
    local perHour = (elapsed > 0) and (math.floor(gained / elapsed * 36) * 100) or 0

    goldRow.left:SetText(ns.FormatMoney(money))
    if gained ~= 0 then
        local color = gained > 0 and "|cff4cd964+" or "|cffff5f5f"
        goldRow.right:SetText(color .. ns.FormatMoney(gained) .. "|r  " ..
            ns.FormatMoney(perHour) .. MUTED_HEX .. " /hr|r")
    else
        goldRow.right:SetText(MUTED_HEX .. "no change this session|r")
    end
    return Place(goldRow, y + SECTION_GAP, TEXT_ROW_H)
end

local function RefreshHonor(y)
    if not ns.db.showHonor then
        honorBar:Hide()
        honorRow:Hide()
        return y
    end
    local rankName, progress, left, right = GetHonorInfo()
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

function ns.Refresh()
    if not ns.db or not ns.session.start then return end
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
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Tally")
    GameTooltip:AddDoubleLine("Session time", ns.FormatDuration(ns.SessionElapsed()), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Session XP", ns.FormatNumber(ns.session.xp or 0), 1, 1, 1, 1, 1, 1)
    local elapsed = ns.SessionElapsed()
    if elapsed > 0 then
        GameTooltip:AddDoubleLine("Session average",
            ns.FormatNumber((ns.session.xp or 0) / elapsed * 3600) .. " /hr", 1, 1, 1, 1, 1, 1)
    end
    local window = ns.db.rateWindow or 0
    if window > 0 then
        local recorded = math.min(elapsed, window)
        GameTooltip:AddDoubleLine("Rate window",
            string.format("%s of %s", ns.FormatDuration(recorded), ns.FormatDuration(window)), 1, 1, 1, 1, 1, 1)
    else
        GameTooltip:AddDoubleLine("Rate window", "Whole session", 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:AddDoubleLine("Kills this session", ns.FormatNumber(ns.session.kills or 0), 1, 1, 1, 1, 1, 1)
    local avgKill = ns.AverageKillXP()
    if avgKill then
        GameTooltip:AddDoubleLine("Avg XP per kill", ns.FormatNumber(avgKill), 1, 1, 1, 1, 1, 1)
    end
    local rested = GetXPExhaustion and GetXPExhaustion()
    if rested and rested > 0 then
        GameTooltip:AddDoubleLine("Rested XP", ns.FormatNumber(rested), 1, 1, 1, 0.7, 0.5, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Drag to move. /tally for options.", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end)

frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- XP gains and other events refresh immediately; between them, recalculate
-- every few seconds so the ETA and per-hour rates keep moving.
local REFRESH_SECONDS = 5
local sinceUpdate = 0
frame:SetScript("OnUpdate", function(_, dt)
    sinceUpdate = sinceUpdate + dt
    if sinceUpdate >= REFRESH_SECONDS then
        sinceUpdate = 0
        ns.Refresh()
    end
end)
