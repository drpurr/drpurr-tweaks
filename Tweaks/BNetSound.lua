-- Tweak: mute the sound of the Battle.net "friend came online" toast.
-- The toast itself still shows; other Battle.net toasts (and the Delves toast,
-- which shares the sound) keep their sound.
local ADDON_NAME, ns = ...

local tweak = {
	key = "bnetLoginSound",
	name = "Mute friend login",
	defaults = { enabled = true },
}

-- sound/interface/ui_bnettoast.ogg, played by SOUNDKIT.UI_BNET_TOAST.
local TOAST_SOUND_FILE = 567402

-- BNToastMixin:ShowToast() fills in the toast's text and then plays the sound.
-- For an "online" toast it sets BottomLine to BN_TOAST_ONLINE first, so we mute
-- the file there and unmute it once ShowToast has returned.
local muted = false

local function OnBottomLineSetText(_, text)
	if not tweak.db.enabled or muted or type(text) ~= "string" then return end
	if BN_TOAST_ONLINE and text:find(BN_TOAST_ONLINE, 1, true) then
		MuteSoundFile(TOAST_SOUND_FILE)
		muted = true
	end
end

local function AfterShowToast()
	if muted then
		UnmuteSoundFile(TOAST_SOUND_FILE)
		muted = false
	end
end

local hooked = false
local function Hook()
	if hooked or not BNToastFrame or not BNToastFrame.BottomLine then return end
	hooked = true
	hooksecurefunc(BNToastFrame.BottomLine, "SetText", OnBottomLineSetText)
	hooksecurefunc(BNToastFrame, "ShowToast", AfterShowToast)
end

function tweak:OnInit()
	Hook()
	if not hooked then
		local waiter = CreateFrame("Frame")
		waiter:RegisterEvent("ADDON_LOADED")
		waiter:SetScript("OnEvent", function(self, _, name)
			if name == "Blizzard_BNet" then
				Hook()
				self:UnregisterAllEvents()
			end
		end)
	end
end

function tweak:OnEnable() end

function tweak:OnDisable()
	AfterShowToast()
end

ns:RegisterTweak(tweak)
