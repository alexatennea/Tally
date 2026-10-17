-- Tally data: what the displays show, gathered in one place so the floating
-- panel and the top bar stay in step. Also the shared tooltip and helpers.

local _, ns = ...

ns.MUTED_HEX = "|cff9ea3b3"
ns.COLORS = {
    bg     = { 0.06, 0.06, 0.08, 0.88 },
    border = { 0, 0, 0, 1 },
    accent = { 0.36, 0.55, 1.00 },   -- XP blue
    rested = { 0.55, 0.30, 0.85 },   -- rested purple
    muted  = { 0.62, 0.64, 0.70 },
    skill  = { 0.85, 0.62, 0.22 },   -- profession amber
    honor  = { 0.80, 0.25, 0.25 },   -- honor red
}
ns.FLAT = "Interface\\Buttons\\WHITE8x8"
ns.BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"

function ns.NewText(parent, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(STANDARD_TEXT_FONT, size, "")
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
    fs:SetTextColor(r or 1, g or 1, b or 1)
    return fs
end

---------------------------------------------------------------------------
-- XP
---------------------------------------------------------------------------

-- Everything the displays need about XP, or { maxLevel = true }.
function ns.GetXPInfo()
    if ns.IsMaxLevel() then return { maxLevel = true } end
    local cur, max = UnitXP("player"), UnitXPMax("player")
    local safeMax = max > 0 and max or 1
    local remaining = max - cur
    local rate = ns.XPRate()
    return {
        cur = cur,
        max = safeMax,
        remaining = remaining,
        percent = math.floor(cur / safeMax * 100),
        rested = (GetXPExhaustion and GetXPExhaustion()) or 0,
        gained = ns.session.xp or 0,
        perHour = rate * 3600,
        eta = rate > 0 and (remaining / rate) or nil,
        kills = ns.db.showKills and ns.KillsToLevel(remaining) or nil,
    }
end

---------------------------------------------------------------------------
-- Professions
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

-- The professions the options say to show (empty if the section is off).
function ns.GetShownProfessions()
    local db, shown = ns.db, {}
    if not db.showProfessions then return shown end
    for _, skill in ipairs(GetProfessionSkills()) do
        if (skill.primary and db.showPrimary) or (not skill.primary and db.showSecondary) then
            shown[#shown + 1] = skill
        end
    end
    return shown
end

---------------------------------------------------------------------------
-- Gold
---------------------------------------------------------------------------

function ns.GetGoldInfo()
    local money = GetMoney()
    local gained = money - (ns.session.startMoney or money)
    local elapsed = ns.SessionElapsed()
    return {
        money = money,
        gained = gained,
        -- Round the rate to whole silver so it stays short.
        perHour = (elapsed > 0) and (math.floor(gained / elapsed * 36) * 100) or 0,
    }
end

-- "+1g 2s  3g /hr" in green/red, or a muted "no change" note.
function ns.FormatGoldChange(gold)
    if gold.gained == 0 then
        return ns.MUTED_HEX .. "no change this session|r"
    end
    local color = gold.gained > 0 and "|cff4cd964+" or "|cffff5f5f"
    return color .. ns.FormatMoney(gold.gained) .. "|r  " ..
        ns.FormatMoney(gold.perHour) .. ns.MUTED_HEX .. " /hr|r"
end

---------------------------------------------------------------------------
-- Honor
---------------------------------------------------------------------------

-- Classic-style rank and weekly honor if the client has them, otherwise the
-- honor currency. Returns rankName, rankProgress (0-1 or nil), leftText, rightText.
function ns.GetHonorInfo()
    local MUTED_HEX = ns.MUTED_HEX
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
-- Tooltip
---------------------------------------------------------------------------

-- Session details shown when hovering either display.
function ns.ShowTooltip(owner, anchor, hint)
    GameTooltip:SetOwner(owner, anchor)
    GameTooltip:AddLine("Tally")
    local elapsed = ns.SessionElapsed()
    GameTooltip:AddDoubleLine("Session time", ns.FormatDuration(elapsed), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Session XP", ns.FormatNumber(ns.session.xp or 0), 1, 1, 1, 1, 1, 1)
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
    GameTooltip:AddLine(hint, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end
