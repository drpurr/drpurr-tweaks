-- Tweak: show the spell ID on the right side of a tooltip's first line.
local _, ns = ...

local issecretvalue = issecretvalue or function() return false end

local tweak = {
	key = "spellIDs",
	name = "Spell IDs",
	defaults = {
		enabled = true,
		spells = true,
		auras = true,
	},
}

local PREFIX = "ID: "
local GRAY = CreateColor(0.6, 0.6, 0.6)

local function AddID(tooltip, data, settingKey)
	if not tweak.db.enabled or not tweak.db[settingKey] then return end
	if not tooltip or tooltip:IsForbidden() or not data then return end
	local id = data.id
	if not id or issecretvalue(id) then return end

	local right = tooltip.TextRight1 or (tooltip:GetName() and _G[tooltip:GetName() .. "TextRight1"])
	if not right then return end

	local label = PREFIX .. id
	local existing = right:IsShown() and right:GetText()
	if existing and issecretvalue(existing) then return end
	if existing and existing ~= "" then
		if existing:find(PREFIX, 1, true) then return end  -- already added (data refresh)
		right:SetText(existing .. "  " .. GRAY:WrapTextInColorCode(label))
	else
		right:SetText(label)
		right:SetTextColor(GRAY:GetRGB())
	end
	right:Show()
	tooltip:Show()  -- re-layout so the width fits the new text
end

function tweak:OnInit()
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip, data)
		AddID(tooltip, data, "spells")
	end)
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.UnitAura, function(tooltip, data)
		AddID(tooltip, data, "auras")
	end)
end

function tweak:OnEnable() end
function tweak:OnDisable() end

ns:RegisterTweak(tweak)
