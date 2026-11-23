-- Settings slider row with a number box for typing the value directly.
-- Used by Options.lua through the DrpurrSliderControlTemplate XML template.
--
-- Extra fields read from the slider options table (Settings.CreateSliderOptions):
--   options.drpurrSuffix   text shown after the box, e.g. "%", "s", "px"

DrpurrSliderControlMixin = CreateFromMixins(SettingsSliderControlMixin)

local function StepOf(options)
	return (options.maxValue - options.minValue) / options.steps
end

local function FormatNumber(value, step)
	if step >= 1 then
		return tostring(math.floor(value + 0.5))
	end
	local text = string.format("%.2f", value)
	return (text:gsub("0+$", ""):gsub("%.$", ""))
end

function DrpurrSliderControlMixin:OnLoad()
	SettingsSliderControlMixin.OnLoad(self)

	self.SliderWithSteppers:SetWidth(220)

	local box = CreateFrame("EditBox", nil, self, "InputBoxTemplate")
	box:SetSize(48, 20)
	box:SetAutoFocus(false)
	box:SetJustifyH("CENTER")
	box:SetPoint("LEFT", self.SliderWithSteppers, "RIGHT", 10, 0)
	box:SetScript("OnEnterPressed", function(editBox)
		self:CommitValueBox()
		editBox:ClearFocus()
	end)
	box:SetScript("OnEscapePressed", function(editBox)
		editBox:ClearFocus()
	end)
	box:SetScript("OnEditFocusLost", function()
		self:UpdateValueBox()
	end)
	self.ValueBox = box

	local suffix = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	suffix:SetPoint("LEFT", box, "RIGHT", 4, 0)
	self.ValueSuffix = suffix
end

function DrpurrSliderControlMixin:Init(initializer)
	SettingsSliderControlMixin.Init(self, initializer)
	self.ValueSuffix:SetText(initializer:GetOptions().drpurrSuffix or "")
	self:UpdateValueBox()
end

function DrpurrSliderControlMixin:UpdateValueBox()
	local setting = self:GetSetting()
	if not setting or self.ValueBox:HasFocus() then return end
	local options = self:GetElementData():GetOptions()
	self.ValueBox:SetText(FormatNumber(setting:GetValue(), StepOf(options)))
	self.ValueBox:SetCursorPosition(0)
end

function DrpurrSliderControlMixin:CommitValueBox()
	local value = tonumber((self.ValueBox:GetText():gsub(",", ".")))
	if value then
		local options = self:GetElementData():GetOptions()
		local step = StepOf(options)
		value = math.max(options.minValue, math.min(options.maxValue, value))
		value = options.minValue + math.floor((value - options.minValue) / step + 0.5) * step
		self.SliderWithSteppers:SetValue(value)
		self:GetSetting():SetValue(value)
	end
	self:UpdateValueBox()
end

function DrpurrSliderControlMixin:OnSettingValueChanged(setting, value)
	SettingsSliderControlMixin.OnSettingValueChanged(self, setting, value)
	self:UpdateValueBox()
end

function DrpurrSliderControlMixin:EvaluateState()
	SettingsSliderControlMixin.EvaluateState(self)
	local enabled = self:IsEnabled()
	self.ValueBox:SetEnabled(enabled)
	self.ValueBox:SetAlpha(enabled and 1 or 0.5)
	self.ValueSuffix:SetAlpha(enabled and 1 or 0.5)
end

function DrpurrSliderControlMixin:Release()
	self.ValueBox:ClearFocus()
	SettingsSliderControlMixin.Release(self)
end
