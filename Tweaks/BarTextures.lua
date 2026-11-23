-- Tweak: one LibSharedMedia status-bar texture for Blizzard's bars.
local _, ns = ...

local LSM = LibStub("LibSharedMedia-3.0")

local issecretvalue = issecretvalue or function() return false end

local tweak = {
	key = "barTextures",
	name = "Override",
	defaults = {
		enabled = false,
		texture = "Blizzard",
		classColor = false,
		groupTooltip = true,
		groupUnitFrames = true,
		groupCastBars = true,
		groupNameplates = false,
	},
}

-- bar -> { kind = "health"|"power"|"cast"|"plain", group = "groupX",
--          origTexture = ..., origColor = {r,g,b,a} }
local bars = {}
local guard = false

local function IsActive(info)
	return tweak.db.enabled and tweak.db[info.group]
end

local function SafeUnit(bar)
	local unit = bar.unit
	if unit and not issecretvalue(unit) then return unit end
end

local function HealthColor(bar)
	if tweak.db.classColor then
		local unit = SafeUnit(bar)
		if unit then
			local isPlayer = UnitIsPlayer(unit)
			if not issecretvalue(isPlayer) and isPlayer then
				local _, class = UnitClass(unit)
				if class and not issecretvalue(class) then
					local c = C_ClassColor.GetClassColor(class)
					if c then return c.r, c.g, c.b end
				end
			end
		end
	end
	return 0, 1, 0
end

local function PowerColor(bar)
	local unit = SafeUnit(bar)
	if unit then
		local powerType, powerToken = UnitPowerType(unit)
		if not issecretvalue(powerType) and not issecretvalue(powerToken) then
			local info = PowerBarColor and (PowerBarColor[powerToken] or PowerBarColor[powerType])
			if info and info.r then return info.r, info.g, info.b end
		end
	end
	return 0, 0, 1
end

local function CastColor(bar)
	if bar.GetTypeInfo then
		local barType = bar.barType or (CastingBarType and CastingBarType.Standard)
		local info = barType and bar:GetTypeInfo(barType)
		local color = info and (bar.drpurrFull and info.classicFullColor or info.classicFillColor)
		if color then return color:GetRGB() end
	end
	return 1, 0.7, 0
end

local COLOR_FUNCS = { health = HealthColor, power = PowerColor, cast = CastColor }

local function ApplyColor(bar, info)
	local colorFunc = COLOR_FUNCS[info.kind]
	if not colorFunc then return end
	guard = true
	bar:SetStatusBarColor(colorFunc(bar))
	guard = false
end

local function Restore(bar, info)
	if not info.applied then return end
	info.applied = false
	guard = true
	if info.origTexture then bar:SetStatusBarTexture(info.origTexture) end
	if info.origColor and COLOR_FUNCS[info.kind] then
		bar:SetStatusBarColor(unpack(info.origColor))
	end
	guard = false
end

local function Apply(bar)
	local info = bars[bar]
	if not info or bar:IsForbidden() then return end
	if not IsActive(info) then return end
	local path = LSM:Fetch("statusbar", tweak.db.texture, true)
	if not path then return end
	info.applied = true
	guard = true
	bar:SetStatusBarTexture(path)
	guard = false
	ApplyColor(bar, info)
end

local function Manage(bar, kind, group)
	if not bar or bars[bar] or bar:IsForbidden() or not bar.SetStatusBarTexture then return end

	local info = { kind = kind, group = group }
	local tex = bar:GetStatusBarTexture()
	if tex then
		info.origTexture = tex:GetAtlas() or tex:GetTexture()
	end
	info.origColor = { bar:GetStatusBarColor() }
	bars[bar] = info

	-- Blizzard re-sets textures/colours on many state changes: remember what it
	-- wanted (for restoring) and put ours back on top.
	hooksecurefunc(bar, "SetStatusBarTexture", function(self, asset)
		if guard then return end
		info.origTexture = asset
		Apply(self)
	end)
	if COLOR_FUNCS[kind] then
		hooksecurefunc(bar, "SetStatusBarColor", function(self, r, g, b, a)
			if guard then return end
			info.origColor = { r, g, b, a }
			if IsActive(info) then ApplyColor(self, info) end
		end)
	end
	if kind == "cast" and bar.UpdateBarFillTexture then
		hooksecurefunc(bar, "UpdateBarFillTexture", function(self, isFull)
			self.drpurrFull = isFull
			Apply(self)
		end)
	end

	Apply(bar)
end

-------------------------------------------------------------------------------
-- Collecting Blizzard bars
-------------------------------------------------------------------------------
local function ManageUnitFrame(frame)
	if not frame then return end
	Manage(frame.healthbar, "health", "groupUnitFrames")
	Manage(frame.manabar, "power", "groupUnitFrames")
end

local function CollectUnitFrames()
	ManageUnitFrame(PlayerFrame)
	ManageUnitFrame(PetFrame)
	ManageUnitFrame(TargetFrame)
	ManageUnitFrame(FocusFrame)
	ManageUnitFrame(TargetFrame and TargetFrame.totFrame)
	ManageUnitFrame(FocusFrame and FocusFrame.totFrame)
	for i = 1, 5 do
		ManageUnitFrame(_G["Boss" .. i .. "TargetFrame"])
	end
	if PartyFrame and PartyFrame.PartyMemberFramePool then
		for member in PartyFrame.PartyMemberFramePool:EnumerateActive() do
			ManageUnitFrame(member)
		end
	end
end

local function CollectCastBars()
	Manage(PlayerCastingBarFrame, "cast", "groupCastBars")
	Manage(PetCastingBarFrame, "cast", "groupCastBars")
	Manage(TargetFrame and TargetFrame.spellbar, "cast", "groupCastBars")
	Manage(FocusFrame and FocusFrame.spellbar, "cast", "groupCastBars")
end

local function CollectNameplate(plate)
	if not plate or plate:IsForbidden() or not plate.UnitFrame then return end
	Manage(plate.UnitFrame.healthBar, "plain", "groupNameplates")
	Manage(plate.UnitFrame.castBar, "cast", "groupNameplates")
end

local function CollectAll()
	Manage(GameTooltip and GameTooltip.StatusBar, "plain", "groupTooltip")
	CollectUnitFrames()
	CollectCastBars()
	if C_NamePlate and C_NamePlate.GetNamePlates then
		for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
			CollectNameplate(plate)
		end
	end
end

local function RefreshAll()
	for bar, info in pairs(bars) do
		if IsActive(info) then Apply(bar) else Restore(bar, info) end
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event, unit)
	if event == "NAME_PLATE_UNIT_ADDED" then
		if tweak.db.groupNameplates then
			CollectNameplate(C_NamePlate.GetNamePlateForUnit(unit))
		end
	else
		CollectAll()
	end
end)

function tweak:OnInit()
	LSM.RegisterCallback(tweak, "LibSharedMedia_Registered", function(_, mediaType)
		if mediaType == "statusbar" and tweak.db.enabled then RefreshAll() end
	end)
end

function tweak:OnEnable()
	eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
	eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	CollectAll()
	RefreshAll()
end

function tweak:OnDisable()
	eventFrame:UnregisterAllEvents()
	RefreshAll()
end

function tweak:OnSettingChanged()
	CollectAll()
	RefreshAll()
end

ns:RegisterTweak(tweak)
