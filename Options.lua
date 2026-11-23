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

	local function Slider(tweakKey, name, label, minV, maxV, step, fmt, tooltip)
		local options = Settings.CreateSliderOptions(minV, maxV, step)
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, fmt)
		return Settings.CreateSlider(category, Register(tweakKey, name, label), options, tooltip)
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

	local function MediaEntries(mediaType)
		return function()
			local entries = {}
			for _, mediaName in ipairs(LSM:List(mediaType)) do
				entries[#entries + 1] = { mediaName, mediaName }
			end
			return entries
		end
	end

	local function Color(tweakKey, name, label, tooltip)
		return Settings.CreateColorSwatch(category, Register(tweakKey, name, label), tooltip)
	end

	local function Number(v) return tostring(math.floor(v + 0.5)) end
	local function Percent(v) return math.floor(v + 0.5) .. "%" end

	---------------------------------------------------------------------------
	Header("General")
	Toggle("mouseButtonLabels")

	---------------------------------------------------------------------------
	Header("Tooltip")

	local anchorInit, anchorOn = Toggle("tooltipAnchor")
	Child(Dropdown("tooltipAnchor", "corner", "Anchor corner", function()
		local entries = {}
		for _, c in ipairs(ns.TOOLTIP_CORNERS) do entries[#entries + 1] = { c[1], c[2] } end
		return entries
	end, "Which side of the cursor the tooltip opens on."), anchorInit, anchorOn)
	Child(Slider("tooltipAnchor", "offsetX", "Offset X", -50, 50, 1, Number,
		"Fine-tune the horizontal distance from the cursor."), anchorInit, anchorOn)
	Child(Slider("tooltipAnchor", "offsetY", "Offset Y", -50, 50, 1, Number,
		"Fine-tune the vertical distance from the cursor."), anchorInit, anchorOn)

	local skinInit, skinOn = Toggle("tooltipSkin")
	Child(Dropdown("tooltipSkin", "background", "Background", MediaEntries("background")), skinInit, skinOn)
	Child(Color("tooltipSkin", "backgroundColor", "Background color"), skinInit, skinOn)
	Child(Slider("tooltipSkin", "backgroundOpacity", "Background opacity", 0, 100, 1, Percent), skinInit, skinOn)
	Child(Dropdown("tooltipSkin", "border", "Border", MediaEntries("border")), skinInit, skinOn)
	Child(Color("tooltipSkin", "borderColor", "Border color"), skinInit, skinOn)
	Child(Slider("tooltipSkin", "borderOpacity", "Border opacity", 0, 100, 1, Percent), skinInit, skinOn)
	Child(Slider("tooltipSkin", "borderSize", "Border size", 1, 32, 1, Number), skinInit, skinOn)
	Child(Dropdown("tooltipSkin", "font", "Font", MediaEntries("font")), skinInit, skinOn)
	Child(Slider("tooltipSkin", "fontSize", "Font size", 8, 24, 1, Number), skinInit, skinOn)
	Child(Dropdown("tooltipSkin", "fontOutline", "Font outline", function()
		return { { "NONE", "None" }, { "OUTLINE", "Outline" }, { "THICKOUTLINE", "Thick Outline" } }
	end), skinInit, skinOn)

	Toggle("tooltipSmartBorder")

	Settings.RegisterAddOnCategory(category)
end
