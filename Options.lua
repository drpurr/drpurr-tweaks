-- Options panel under Esc > Options > AddOns > drpurr-tweaks (Blizzard Settings API).
local ADDON_NAME, ns = ...

local LSM = LibStub("LibSharedMedia-3.0")

local VAR_TYPE = {
	boolean = Settings.VarType.Boolean,
	number = Settings.VarType.Number,
	string = Settings.VarType.String,
}

function ns:BuildOptions()
	local category, layout = Settings.RegisterVerticalLayoutCategory(ADDON_NAME)

	local function Register(tweakKey, name, label)
		local tweak = ns.tweaks[tweakKey]
		local default = tweak.defaults[name]
		local setting = Settings.RegisterAddOnSetting(category,
			"DRPURR_" .. tweakKey:upper() .. "_" .. name:upper(),
			name, tweak.db, VAR_TYPE[type(default)], label, default)
		setting:SetValueChangedCallback(function(_, value)
			ns:OnSettingChanged(tweakKey, name, value)
		end)
		return setting
	end

	local function Header(text)
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
	end

	-- Master toggle for a tweak; returns the initializer so children can nest under it.
	local function Toggle(tweakKey)
		local tweak = ns.tweaks[tweakKey]
		local setting = Register(tweakKey, "enabled", tweak.name)
		local init = Settings.CreateCheckbox(category, setting, tweak.tooltip)
		local function IsEnabled() return tweak.db.enabled end
		return init, IsEnabled
	end

	local function Child(init, parent, isEnabled)
		init:SetParentInitializer(parent, isEnabled)
		return init
	end

	-- Every slider gets a number box for typing the value (Widgets/SliderWithInput).
	local function Slider(tweakKey, name, label, minV, maxV, step, suffix, tooltip)
		local options = Settings.CreateSliderOptions(minV, maxV, step)
		options.drpurrSuffix = suffix
		local init = Settings.CreateControlInitializer("DrpurrSliderControlTemplate",
			Register(tweakKey, name, label), options, tooltip)
		layout:AddInitializer(init)
		return init
	end

	local function Dropdown(tweakKey, name, label, getEntries, tooltip)
		local function GetOptions()
			local container = Settings.CreateControlTextContainer()
			for _, entry in ipairs(getEntries()) do
				container:Add(entry[1], entry[2])
			end
			return container:GetData()
		end
		return Settings.CreateDropdown(category, Register(tweakKey, name, label), GetOptions, tooltip)
	end

	-- One alphabetical list of every name registered under the given media types.
	local function MediaEntries(...)
		local mediaTypes = { ... }
		return function()
			local seen, names = {}, {}
			for _, mediaType in ipairs(mediaTypes) do
				for _, mediaName in ipairs(LSM:List(mediaType)) do
					if not seen[mediaName] then
						seen[mediaName] = true
						names[#names + 1] = mediaName
					end
				end
			end
			table.sort(names, function(a, b) return a:lower() < b:lower() end)
			local entries = {}
			for i, mediaName in ipairs(names) do
				entries[i] = { mediaName, mediaName }
			end
			return entries
		end
	end

	local function Color(tweakKey, name, label, tooltip)
		return Settings.CreateColorSwatch(category, Register(tweakKey, name, label), tooltip)
	end


	---------------------------------------------------------------------------
	Header("Action Bars")
	Toggle("mouseButtonLabels")
	Toggle("hideMacroNames")

	---------------------------------------------------------------------------
	Header("Swing Timer")
	local swInit, swOn = Toggle("swingTimer")
	Child(Dropdown("swingTimer", "position", "Position", function()
		local entries = {}
		for _, p in ipairs(ns.SWING_TIMER_POSITIONS) do entries[#entries + 1] = { p[1], p[2] } end
		return entries
	end), swInit, swOn)

	---------------------------------------------------------------------------
	Header("Tooltip")

	local anchorInit, anchorOn = Toggle("tooltipAnchor")
	Child(Dropdown("tooltipAnchor", "corner", "Corner", function()
		local entries = {}
		for _, c in ipairs(ns.TOOLTIP_CORNERS) do entries[#entries + 1] = { c[1], c[2] } end
		return entries
	end), anchorInit, anchorOn)
	Child(Slider("tooltipAnchor", "offsetX", "Offset X", -50, 50, 1, "px"), anchorInit, anchorOn)
	Child(Slider("tooltipAnchor", "offsetY", "Offset Y", -50, 50, 1, "px"), anchorInit, anchorOn)

	local skinInit, skinOn = Toggle("tooltipSkin")
	Child(Dropdown("tooltipSkin", "background", "BG", MediaEntries("background", "statusbar")), skinInit, skinOn)
	Child(Color("tooltipSkin", "backgroundColor", "BG color"), skinInit, skinOn)
	Child(Slider("tooltipSkin", "backgroundOpacity", "BG opacity", 0, 100, 1, "%"), skinInit, skinOn)
	Child(Dropdown("tooltipSkin", "border", "Border", MediaEntries("border")), skinInit, skinOn)
	Child(Color("tooltipSkin", "borderColor", "Border color"), skinInit, skinOn)
	Child(Slider("tooltipSkin", "borderOpacity", "Border opacity", 0, 100, 1, "%"), skinInit, skinOn)
	Child(Slider("tooltipSkin", "borderSize", "Border size", 1, 32, 1, "px"), skinInit, skinOn)
	Child(Dropdown("tooltipSkin", "font", "Font", MediaEntries("font")), skinInit, skinOn)
	Child(Slider("tooltipSkin", "fontSize", "Font size", 8, 24, 1, "pt"), skinInit, skinOn)
	Child(Dropdown("tooltipSkin", "fontOutline", "Outline", function()
		return { { "NONE", "None" }, { "OUTLINE", "Outline" }, { "THICKOUTLINE", "Thick Outline" } }
	end), skinInit, skinOn)

	Toggle("tooltipSmartBorder")

	local hbInit, hbOn = Toggle("tooltipHealthBar")
	Child(Slider("tooltipHealthBar", "height", "Height", 2, 16, 1, "px"), hbInit, hbOn)

	local fadeInit, fadeOn = Toggle("tooltipFade")
	Child(Slider("tooltipFade", "fadeTime", "Time", 0, 1, 0.05, "s"),
		fadeInit, fadeOn)

	local idInit, idOn = Toggle("spellIDs")
	Child(Settings.CreateCheckbox(category, Register("spellIDs", "spells", "Spells")), idInit, idOn)
	Child(Settings.CreateCheckbox(category, Register("spellIDs", "auras", "Auras")), idInit, idOn)

	local usInit, usOn = Toggle("unitStyle")
	local function UnitCheck(name, label)
		Child(Settings.CreateCheckbox(category, Register("unitStyle", name, label)), usInit, usOn)
	end
	Child(Slider("unitStyle", "nameSize", "Name size", 0, 10, 1, "pt"), usInit, usOn)
	UnitCheck("guildBrackets", "Guild brackets")
	UnitCheck("factionColor", "Faction color")
	UnitCheck("nameColor", "Name color")
	UnitCheck("classColor", "Class color")
	UnitCheck("levelColor", "Level color")
	UnitCheck("abbrevLevel", "Short level")
	UnitCheck("target", "Target")
	UnitCheck("raidIcon", "Raid icon")
	UnitCheck("pvp", "Inline PvP")
	UnitCheck("hideTitles", "Hide titles")
	UnitCheck("hideRealm", "Hide realm")
	UnitCheck("hidePetLevel", "Real pet level")

	Toggle("linkIcons")

	---------------------------------------------------------------------------
	Header("Bar Textures")

	local barInit, barOn = Toggle("barTextures")
	Child(Dropdown("barTextures", "texture", "Texture", MediaEntries("statusbar")), barInit, barOn)
	Child(Settings.CreateCheckbox(category, Register("barTextures", "classColor", "Class health")), barInit, barOn)
	Child(Settings.CreateCheckbox(category, Register("barTextures", "groupTooltip", "Tooltip")), barInit, barOn)
	Child(Settings.CreateCheckbox(category, Register("barTextures", "groupUnitFrames", "Unit frames")), barInit, barOn)
	Child(Settings.CreateCheckbox(category, Register("barTextures", "groupCastBars", "Cast bars")), barInit, barOn)
	Child(Settings.CreateCheckbox(category, Register("barTextures", "groupNameplates", "Nameplates")), barInit, barOn)

	---------------------------------------------------------------------------
	Header("Sound")
	Toggle("bnetLoginSound")

	Settings.RegisterAddOnCategory(category)
end
