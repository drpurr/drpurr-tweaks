-- Tweak: hide macro/item name text on Blizzard action bar buttons.
local _, ns = ...

local tweak = {
	key = "hideMacroNames",
	name = "Hide macro names",
	defaults = { enabled = true },
}

-- Transparent rather than hidden, so Blizzard or Masque calling Show() on the
-- name doesn't bring it back.
local function Apply()
	local alpha = tweak.db.enabled and 0 or 1
	for button in ns:EnumerateActionButtons() do
		if button.Name then button.Name:SetAlpha(alpha) end
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", Apply)

function tweak:OnEnable()
	-- Re-apply when bars are rebuilt (e.g. entering a vehicle, edit mode).
	eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	eventFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
	eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
	Apply()
end

function tweak:OnDisable()
	eventFrame:UnregisterAllEvents()
	Apply()
end

ns:RegisterTweak(tweak)
