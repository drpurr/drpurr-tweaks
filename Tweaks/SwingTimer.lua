-- Tweak: move the swing timer's weapon label outside the bar; time centered in the bar.
local _, ns = ...

local tweak = {
	key = "swingTimer",
	name = "Enable",
	defaults = {
		enabled = true,
		position = "LEFT",
	},
}

ns.SWING_TIMER_POSITIONS = {
	{ "LEFT", "Left" },
	{ "RIGHT", "Right" },
	{ "ABOVE", "Above" },
	{ "BELOW", "Below" },
}

local GAP = 4

-- label point, frame point, x, y, justify
local LAYOUT = {
	LEFT  = { "RIGHT",  "LEFT",   -GAP, 0,    "RIGHT" },
	RIGHT = { "LEFT",   "RIGHT",  GAP,  0,    "LEFT" },
	ABOVE = { "BOTTOM", "TOP",    0,    GAP,  "CENTER" },
	BELOW = { "TOP",    "BOTTOM", 0,    -GAP, "CENTER" },
}

local FRAMES = { "SwingTimerMainHandFrame", "SwingTimerOffHandFrame", "SwingTimerRangedFrame" }

local function Apply()
	for _, name in ipairs(FRAMES) do
		local frame = _G[name]
		local bar = frame and frame.StatusBar
		local typeLabel, timeLabel = bar and bar.TypeLabel, bar and bar.TimeLabel
		if typeLabel and timeLabel then
			typeLabel:ClearAllPoints()
			timeLabel:ClearAllPoints()
			if tweak.db.enabled then
				local l = LAYOUT[tweak.db.position] or LAYOUT.LEFT
				typeLabel:SetPoint(l[1], frame, l[2], l[3], l[4])
				typeLabel:SetJustifyH(l[5])
				timeLabel:SetPoint("CENTER", bar, "CENTER")
				timeLabel:SetJustifyH("CENTER")
			else
				-- Blizzard's original anchors (Blizzard_SwingTimer.xml).
				typeLabel:SetPoint("LEFT", bar, "LEFT", 10, 0)
				typeLabel:SetJustifyH("LEFT")
				timeLabel:SetPoint("RIGHT", bar, "RIGHT", -10, 0)
				timeLabel:SetJustifyH("RIGHT")
			end
		end
	end
end

function tweak:OnEnable() Apply() end
function tweak:OnDisable() Apply() end
function tweak:OnSettingChanged() Apply() end

ns:RegisterTweak(tweak)
