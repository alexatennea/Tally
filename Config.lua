-- Tally options page, found under Options > AddOns > Tally (or /tally).

local _, ns = ...

local panel = CreateFrame("Frame")
panel.name = "Tally"
panel:Hide()

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Tally")

local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
subtitle:SetText("Time to level is always shown. Choose how it's worked out and what else appears on the panel.")

local checks = {}

-- `parentKey` makes this an indented sub-option that's disabled while its
-- parent option is off.
local function NewCheck(label, key, y, parentKey)
    local x = parentKey and 40 or 16
    local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb:SetPoint("TOPLEFT", x, y)
    cb.label = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    cb.label:SetText(label)
    cb.key, cb.parentKey = key, parentKey
    cb:SetScript("OnClick", function(self)
        ns.db[key] = self:GetChecked() and true or false
        ns.RefreshConfig()
        ns.OnSettingChanged(key)
    end)
    checks[#checks + 1] = cb
    return cb
end

local y = -70
local function Next(step) y = y - (step or 28); return y + (step or 28) end

local heading0 = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
heading0:SetPoint("TOPLEFT", 16, Next(22))
heading0:SetText("Time to level")

local rateLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
rateLabel:SetPoint("TOPLEFT", 20, Next(22))
rateLabel:SetText("Base the XP rate on the last:")

-- Radio-style choices for ns.db.rateWindow (seconds, 0 = whole session).
local radios = {}
local RATE_WINDOWS = {
    { 300, "5 min" }, { 600, "10 min" }, { 1800, "30 min" }, { 3600, "1 hour" }, { 0, "Whole session" },
}
local radioY = Next()
for i, choice in ipairs(RATE_WINDOWS) do
    local rb = CreateFrame("CheckButton", nil, panel, "UIRadioButtonTemplate")
    rb:SetPoint("TOPLEFT", 20 + (i - 1) * 90, radioY - 4)
    rb.label = rb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    rb.label:SetPoint("LEFT", rb, "RIGHT", 4, 1)
    rb.label:SetText(choice[2])
    rb.value = choice[1]
    rb:SetScript("OnClick", function(self)
        ns.db.rateWindow = self.value
        ns.RefreshConfig()
        ns.OnSettingChanged("rateWindow")
    end)
    radios[#radios + 1] = rb
end

NewCheck("Show kills to level (average of your last 5 kills)", "showKills", Next())

Next(12)
local heading1 = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
heading1:SetPoint("TOPLEFT", 16, Next(22))
heading1:SetText("Panel sections")

NewCheck("Show professions", "showProfessions", Next())
NewCheck("Primary professions", "showPrimary", Next(), "showProfessions")
NewCheck("Secondary skills (Cooking, First Aid, Fishing)", "showSecondary", Next(), "showProfessions")
NewCheck("Show gold", "showGold", Next())
NewCheck("Show honor", "showHonor", Next())

Next(12)
local heading2 = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
heading2:SetPoint("TOPLEFT", 16, Next(22))
heading2:SetText("General")

NewCheck("Show minimap button", "showMinimap", Next())
NewCheck("Lock panel position", "locked", Next())

Next(8)
local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
reset:SetSize(140, 24)
reset:SetPoint("TOPLEFT", 20, Next(30))
reset:SetText("Reset session")
reset:SetScript("OnClick", function()
    ns.ResetSession()
    ns.Refresh()
    ns.Print("session reset.")
end)

function ns.RefreshConfig()
    if not ns.db then return end
    for _, rb in ipairs(radios) do
        rb:SetChecked(ns.db.rateWindow == rb.value)
    end
    for _, cb in ipairs(checks) do
        cb:SetChecked(ns.db[cb.key])
        local enabled = not cb.parentKey or ns.db[cb.parentKey]
        cb:SetEnabled(enabled)
        if enabled then
            cb.label:SetTextColor(1, 1, 1)
        else
            cb.label:SetTextColor(0.5, 0.5, 0.5)
        end
    end
end

panel:SetScript("OnShow", ns.RefreshConfig)

-- Register with whichever options UI this client has.
local category
if Settings and Settings.RegisterCanvasLayoutCategory then
    category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
end

function ns.OpenConfig()
    if category and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        -- Called twice: the first call often lands on the wrong page.
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end
