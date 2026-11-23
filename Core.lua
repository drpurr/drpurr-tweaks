-- drpurr-tweaks core: saved variables, tweak registry, enable/disable plumbing.
local ADDON_NAME, ns = ...

ns.tweaks = {}      -- key -> tweak definition
ns.tweakOrder = {}  -- registration order, used by the options panel

-- A tweak is a table:
--   key        unique string, also the saved-variables sub-table name
--   defaults   table of default settings (must include `enabled`)
--   OnInit()   optional, called once after saved variables load
--   OnEnable() / OnDisable()   called when the master toggle changes (and on load if enabled)
--   OnSettingChanged(name, value)   optional, called when any other setting changes
function ns:RegisterTweak(tweak)
	assert(tweak.key and tweak.defaults, "tweak needs key and defaults")
	self.tweaks[tweak.key] = tweak
	self.tweakOrder[#self.tweakOrder + 1] = tweak.key
end

-- Blizzard action bar buttons shared by the action-bar tweaks.
local ACTION_BUTTON_PREFIXES = {
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

-- Iterator over every existing Blizzard action bar button.
function ns:EnumerateActionButtons()
	return coroutine.wrap(function()
		for _, bar in ipairs(ACTION_BUTTON_PREFIXES) do
			for i = 1, bar[2] do
				local button = _G[bar[1] .. i]
				if button then coroutine.yield(button) end
			end
		end
	end)
end

local function ApplyDefaults(db, defaults)
	for k, v in pairs(defaults) do
		if db[k] == nil then
			db[k] = v
		end
	end
end

function ns:SetTweakEnabled(key, enabled)
	local tweak = self.tweaks[key]
	if not tweak then return end
	tweak.db.enabled = enabled and true or false
	if tweak.db.enabled then
		if tweak.OnEnable then tweak:OnEnable() end
	else
		if tweak.OnDisable then tweak:OnDisable() end
	end
end

function ns:OnSettingChanged(key, name, value)
	local tweak = self.tweaks[key]
	if not tweak then return end
	if name == "enabled" then
		self:SetTweakEnabled(key, value)
	elseif tweak.db.enabled and tweak.OnSettingChanged then
		tweak:OnSettingChanged(name, value)
	end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
		DrpurrTweaksDB = DrpurrTweaksDB or {}
		for _, key in ipairs(ns.tweakOrder) do
			local tweak = ns.tweaks[key]
			DrpurrTweaksDB[key] = DrpurrTweaksDB[key] or {}
			ApplyDefaults(DrpurrTweaksDB[key], tweak.defaults)
			tweak.db = DrpurrTweaksDB[key]
			if tweak.OnInit then tweak:OnInit() end
		end
		if ns.BuildOptions then ns:BuildOptions() end
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_LOGIN" then
		for _, key in ipairs(ns.tweakOrder) do
			local tweak = ns.tweaks[key]
			if tweak.db.enabled and tweak.OnEnable then
				tweak:OnEnable()
			end
		end
		self:UnregisterEvent("PLAYER_LOGIN")
	end
end)
