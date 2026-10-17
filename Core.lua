-- Tally core: saved settings, session tracking, events and slash commands.
-- Other files hang their functions off the shared `ns` table.

local ADDON, ns = ...

ns.ICON = "Interface\\Icons\\inv_misc_pocketwatch_01"

local defaults = {
    point = { "TOP", "UIParent", "TOP", 0, -120 },
    locked = false,
    shown = true,
    showProfessions = true,
    showPrimary = true,
    showSecondary = true,
    showGold = true,
    showHonor = false,
    showMinimap = true,
    minimapAngle = 225,  -- degrees around the minimap, 0 = right, 90 = top
    rateWindow = 600,    -- seconds of history the XP rate uses; 0 = whole session
    showKills = true,
    style = "panel",     -- "panel" (floating), "bar" (across the top) or "bottom"
    pushUI = true,       -- move default UI down to make room for the bar
}

-- A session ends after this long without gaining XP, or this long logged out.
local IDLE_RESET_SECONDS = 30 * 60
local MAX_WINDOW = 3600  -- longest rate window, so older gains can be dropped
local KILL_SAMPLES = 5   -- kills averaged for "kills to level"

-- Session state lives in TallyCharDB (per character) so it survives /reload
-- and short logouts. Until that loads, an empty table keeps lookups safe.
ns.session = {}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

function ns.FormatNumber(n)
    local s = tostring(math.floor(math.abs(n) + 0.5))
    local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return (n < 0 and "-" or "") .. formatted
end

function ns.FormatDuration(seconds)
    if not seconds or seconds ~= seconds or seconds == math.huge then
        return "--"
    end
    seconds = math.floor(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then
        return string.format("%dh %02dm", h, m)
    elseif m > 0 then
        return string.format("%dm %02ds", m, s)
    end
    return string.format("%ds", s)
end

local GOLD_ICON   = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:1:0|t"
local SILVER_ICON = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:1:0|t"
local COPPER_ICON = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:1:0|t"

-- Coin string with icons, skipping zero denominations ("12g 5c").
function ns.FormatMoney(copper)
    local sign = copper < 0 and "-" or ""
    copper = math.floor(math.abs(copper))
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = ns.FormatNumber(g) .. GOLD_ICON end
    if s > 0 then parts[#parts + 1] = s .. SILVER_ICON end
    if c > 0 or #parts == 0 then parts[#parts + 1] = c .. COPPER_ICON end
    return sign .. table.concat(parts, " ")
end

function ns.IsMaxLevel()
    local maxLevel = GetMaxPlayerLevel and GetMaxPlayerLevel() or MAX_PLAYER_LEVEL
    return maxLevel and UnitLevel("player") >= maxLevel
end

function ns.SessionElapsed()
    local start = ns.session.start
    return start and (time() - start) or 0
end

function ns.ResetSession()
    local s = ns.session
    -- Recent kill XP is still a good guide after a reset, so keep it.
    local recentKills = s.recentKills or {}
    wipe(s)
    s.start = time()
    s.lastSeen = s.start
    s.xp = 0
    s.gains = {}         -- { {t = time(), xp = n}, ... } for the rate window
    s.kills = 0
    s.recentKills = recentKills
    s.lastXP, s.lastMax = UnitXP("player"), UnitXPMax("player")
    s.startMoney = GetMoney()
end

-- Carry the saved session over unless we've been away too long. Time spent
-- logged out is skipped by shifting every timestamp forward.
local function ResumeOrReset()
    local s = ns.session
    local now = time()
    if not s.start or not s.lastSeen or not s.gains or now - s.lastSeen > IDLE_RESET_SECONDS then
        ns.ResetSession()
        return
    end
    local away = now - s.lastSeen
    s.start = s.start + away
    if s.lastGain then s.lastGain = s.lastGain + away end
    for _, gain in ipairs(s.gains) do gain.t = gain.t + away end
    s.lastSeen = now
    s.lastXP, s.lastMax = UnitXP("player"), UnitXPMax("player")
end

-- XP per second over the chosen rate window, or the whole session.
function ns.XPRate()
    local s = ns.session
    local elapsed = ns.SessionElapsed()
    if elapsed <= 0 then return 0 end
    local window = ns.db.rateWindow or 0
    if window <= 0 or window >= elapsed then
        return (s.xp or 0) / elapsed
    end
    local since, sum = time() - window, 0
    for _, gain in ipairs(s.gains) do
        if gain.t >= since then sum = sum + gain.xp end
    end
    return sum / window
end

function ns.AverageKillXP()
    local recent = ns.session.recentKills
    if not recent or #recent == 0 then return nil end
    local sum = 0
    for _, xp in ipairs(recent) do sum = sum + xp end
    return sum / #recent
end

function ns.KillsToLevel(remaining)
    local avg = ns.AverageKillXP()
    return avg and avg > 0 and math.ceil(remaining / avg) or nil
end

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff5c8cffTally|r: " .. msg)
end

-- The display for the chosen style: the floating panel or the top bar.
function ns.ActiveDisplay()
    return ns.db.style == "panel" and ns.panel or ns.bar
end

-- Show the active display (if not hidden by the player) and hide the other.
function ns.UpdateDisplay()
    local active = ns.ActiveDisplay()
    local other = (active == ns.bar) and ns.panel or ns.bar
    other:Hide()
    ns.PositionBar()
    active:SetShown(ns.db.shown)
    ns.UpdateUIPush()
end

function ns.SetDisplayShown(shown)
    ns.db.shown = shown
    ns.UpdateDisplay()
    ns.Refresh()
end

function ns.Refresh()
    if not ns.db or not ns.session.start then return end
    if ns.db.style ~= "panel" then
        ns.RefreshBar()
    else
        ns.RefreshPanel()
    end
end

-- Called by the options page whenever a setting changes.
function ns.OnSettingChanged(key)
    if key == "showMinimap" then
        ns.UpdateMinimapButton()
        return
    elseif key == "style" or key == "pushUI" then
        ns.UpdateDisplay()
    end
    ns.Refresh()
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local function OnXPUpdate()
    local s = ns.session
    local cur, max = UnitXP("player"), UnitXPMax("player")
    local delta = 0
    if s.lastXP then
        delta = cur - s.lastXP
        if delta < 0 then
            -- Levelled up: finish the old bar, then add progress into the new one.
            delta = (s.lastMax - s.lastXP) + cur
        end
    end

    local now = time()
    if delta > 0 and s.lastGain and now - s.lastGain > IDLE_RESET_SECONDS then
        ns.ResetSession()  -- been idle a while; this gain starts a fresh session
    end
    s.lastXP, s.lastMax = cur, max
    if delta <= 0 then return end

    s.xp = s.xp + delta
    s.lastGain = now
    s.gains[#s.gains + 1] = { t = now, xp = delta }
    while s.gains[1] and s.gains[1].t < now - MAX_WINDOW do
        table.remove(s.gains, 1)
    end
end

-- Kill XP comes through as "<mob> dies, you gain N experience." (plus a
-- rested/group bonus suffix). Build a pattern from the client's own string so
-- it works in other languages, with the English text as a fallback.
local KILL_PATTERNS = { "^.+ dies, you gain (%d+) experience" }
if COMBATLOG_XPGAIN_FIRSTPERSON then
    local pattern = COMBATLOG_XPGAIN_FIRSTPERSON
        :gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
        :gsub("%%s", ".+")
        :gsub("%%d", "(%%d+)")
    table.insert(KILL_PATTERNS, 1, "^" .. pattern)
end

local function OnCombatXPMessage(msg)
    for _, pattern in ipairs(KILL_PATTERNS) do
        local xp = tonumber(msg:match(pattern))
        if xp then
            local s = ns.session
            s.kills = (s.kills or 0) + 1
            s.recentKills = s.recentKills or {}
            table.insert(s.recentKills, xp)
            if #s.recentKills > KILL_SAMPLES then table.remove(s.recentKills, 1) end
            return
        end
    end
end

local events = CreateFrame("Frame")

-- Some events only exist on certain clients; registering an unknown one errors.
local function SafeRegister(event)
    pcall(events.RegisterEvent, events, event)
end

for _, event in ipairs({
    "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "SKILL_LINES_CHANGED",
    "PLAYER_MONEY", "PLAYER_PVP_KILLS_CHANGED", "PLAYER_PVP_RANK_CHANGED", "HONOR_CURRENCY_UPDATE",
    "CHAT_MSG_COMBAT_XP_GAIN", "PLAYER_LOGOUT",
}) do
    SafeRegister(event)
end

events:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        TallyDB = TallyDB or {}
        for k, v in pairs(defaults) do
            if TallyDB[k] == nil then TallyDB[k] = v end
        end
        ns.db = TallyDB
        TallyCharDB = TallyCharDB or {}
        TallyCharDB.session = TallyCharDB.session or {}
        ns.session = TallyCharDB.session
        ns.panel:ClearAllPoints()
        ns.panel:SetPoint(unpack(ns.db.point))
        ns.UpdateDisplay()
        ns.UpdateMinimapButton()
        self:UnregisterEvent("ADDON_LOADED")
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        if not self.resumed then
            self.resumed = true
            ResumeOrReset()
        end
    elseif event == "PLAYER_XP_UPDATE" then
        OnXPUpdate()
    elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
        OnCombatXPMessage(arg1)
    elseif event == "PLAYER_LOGOUT" then
        ns.session.lastSeen = time()
        return
    end
    ns.Refresh()
end)

-- Every few seconds: note when we were last online (so a crash or disconnect
-- still counts as time away) and refresh the display so the ETA and per-hour
-- rates keep moving between XP gains.
local TICK_SECONDS = 5
local sinceTick = 0
events:SetScript("OnUpdate", function(_, dt)
    sinceTick = sinceTick + dt
    if sinceTick < TICK_SECONDS then return end
    sinceTick = 0
    if ns.session.start then ns.session.lastSeen = time() end
    if ns.db and ns.db.shown then
        ns.Refresh()
        -- Catch frames that Blizzard re-anchored back under the bar.
        if ns.db.style ~= "panel" then ns.UpdateUIPush() end
    end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

SLASH_TALLY1 = "/tally"
SlashCmdList.TALLY = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "" or msg == "config" or msg == "options" then
        ns.OpenConfig()
    elseif msg == "reset" then
        ns.ResetSession()
        ns.Refresh()
        ns.Print("session reset.")
    elseif msg == "lock" then
        ns.db.locked = not ns.db.locked
        ns.Print(ns.db.locked and "panel locked." or "panel unlocked.")
    elseif msg == "show" then
        ns.SetDisplayShown(true)
    elseif msg == "hide" then
        ns.SetDisplayShown(false)
    elseif msg == "toggle" then
        ns.SetDisplayShown(not ns.db.shown)
    elseif msg == "bar" or msg == "bottom" or msg == "panel" then
        ns.db.style = msg
        ns.OnSettingChanged("style")
    elseif msg == "center" then
        ns.db.point = { "CENTER", "UIParent", "CENTER", 0, 0 }
        ns.panel:ClearAllPoints()
        ns.panel:SetPoint(unpack(ns.db.point))
    else
        ns.Print("/tally (options) | reset | lock | show | hide | toggle | bar | bottom | panel | center")
    end
end
