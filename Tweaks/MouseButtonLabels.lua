-- Tweak: show Mouse Button 4/5 as M4/M5 on Blizzard action bar hotkey labels.
local _, ns = ...

local tweak = {
	key = "mouseButtonLabels",
	name = "Mouse button labels (M4/M5)",
	tooltip = "Shorten Mouse Button 4 and 5 keybind text on Blizzard action bars to M4 and M5.",
	defaults = { enabled = true },
}

local REPLACEMENTS = {
	BUTTON4 = "M4",
	BUTTON5 = "M5",
}

-- (pattern, replacement) pairs covering the localized full name, the localized
-- abbreviation (if the client defines one), and the raw key token.
local patterns = {}
local function escape(s)
	return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end
for key, short in pairs(REPLACEMENTS) do
	local seen = {}
	for _, text in ipairs({ _G["KEY_ABBR_" .. key], _G["KEY_" .. key], key }) do
		if type(text) == "string" and text ~= "" and not seen[text] then
			seen[text] = true
			patterns[#patterns + 1] = { escape(text), short }
		end
	end
end
table.sort(patterns, function(a, b) return #a[1] > #b[1] end)

local function Abbreviate(text)
	for _, p in ipairs(patterns) do
		text = text:gsub(p[1], p[2])
	end
	return text
end

local BAR_PREFIXES = {
	{ "ActionButton", 12 },
	{ "MultiBarBottomLeftButton", 12 },
	{ "MultiBarBottomRightButton", 12 },
	{ "MultiBarRightButton", 12 },
	{ "MultiBarLeftButton", 12 },
	{ "MultiBar5Button", 12 },
	{ "MultiBar6Button", 12 },
	{ "MultiBar7Button", 12 },
	{ "PetActionButton", 10 },
	{ "StanceButton", 10 },
	{ "PossessButton", 2 },
	{ "OverrideActionBarButton", 6 },
}

local hotkeys = {}   -- hooked hotkey fontstrings
local original = {}  -- fontstring -> Blizzard's unmodified text, for restoring on disable
local updating = false

local function OnSetText(fontString, text)
	if updating then return end
	original[fontString] = text
	if not tweak.db.enabled or type(text) ~= "string" then return end
	local newText = Abbreviate(text)
	if newText ~= text then
		updating = true
		fontString:SetText(newText)
		updating = false
	end
end

local function HookAll()
	for _, bar in ipairs(BAR_PREFIXES) do
		for i = 1, bar[2] do
			local button = _G[bar[1] .. i]
			local hotkey = button and button.HotKey
			if hotkey and not hotkeys[hotkey] then
				hotkeys[hotkey] = true
				hooksecurefunc(hotkey, "SetText", OnSetText)
				OnSetText(hotkey, hotkey:GetText())
			end
		end
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", HookAll)

function tweak:OnEnable()
	HookAll()
	eventFrame:RegisterEvent("UPDATE_BINDINGS")
	for hotkey in pairs(hotkeys) do
		OnSetText(hotkey, original[hotkey] or hotkey:GetText())
	end
end

function tweak:OnDisable()
	eventFrame:UnregisterEvent("UPDATE_BINDINGS")
	updating = true
	for hotkey in pairs(hotkeys) do
		if original[hotkey] ~= nil then
			hotkey:SetText(original[hotkey])
		end
	end
	updating = false
end

ns:RegisterTweak(tweak)
