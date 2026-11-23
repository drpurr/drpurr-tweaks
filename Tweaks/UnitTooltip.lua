-- Tweaks: PhanxTooltip-style unit tooltips, and icons on chat-link tooltips.
--
-- Unit tooltip lines are built by the game client. We restyle them after the
-- fact in a TooltipDataProcessor post-call. Anything the game marks as secret
-- (some instance/combat situations) is left exactly as Blizzard drew it.
local _, ns = ...

local issecretvalue = issecretvalue or function() return false end

local function Secret(...)
	for i = 1, select("#", ...) do
		if issecretvalue((select(i, ...))) then return true end
	end
	return false
end

-- Readable text of a tooltip line, or nil if missing/secret.
local function LineText(fontString)
	if not fontString then return nil end
	if fontString.HasAnySecretAspect and fontString:HasAnySecretAspect() then return nil end
	local text = fontString:GetText()
	if text == nil or issecretvalue(text) then return nil end
	return text
end

local function Wrap(text, r, g, b)
	return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, text)
end

local function Escape(s)
	return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

local function ClassColor(unit)
	local _, classFile = UnitClass(unit)
	if classFile and not Secret(classFile) then
		local c = C_ClassColor.GetClassColor(classFile)
		if c then return c.r, c.g, c.b end
	end
end

local function ReactionColor(unit)
	local reaction = UnitReaction(unit, "player")
	if reaction and not Secret(reaction) then
		local c = FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
		if c then return c.r, c.g, c.b end
	end
end

-- Grey if dead or tapped by someone else, class colour for players, reaction for NPCs.
local function UnitNameColor(unit)
	local dead, tapped, isPlayer = UnitIsDeadOrGhost(unit), UnitIsTapDenied(unit), UnitIsPlayer(unit)
	if Secret(dead, tapped, isPlayer) then return end
	if dead or tapped then return 0.5, 0.5, 0.5 end
	if isPlayer then return ClassColor(unit) end
	return ReactionColor(unit)
end

-------------------------------------------------------------------------------
-- Unit tooltip styling
-------------------------------------------------------------------------------
local style = {
	key = "unitStyle",
	name = "Unit styling",
	defaults = {
		enabled = true,
		nameSize = 4,
		guildBrackets = true,
		factionColor = true,
		nameColor = true,
		classColor = true,
		levelColor = true,
		target = true,
		raidIcon = true,
		pvp = true,
		hideTitles = true,
		hideRealm = true,
		hidePetLevel = true,
		abbrevLevel = true,
	},
}

local LINE_UNITLEVEL = Enum.TooltipDataLineType and Enum.TooltipDataLineType.UnitLevel
local LINE_NONE = Enum.TooltipDataLineType and Enum.TooltipDataLineType.None

-- Lines that are never an NPC's reputation faction.
local NOT_FACTION = {}
for _, key in ipairs({ "PVP", "UNIT_SKINNABLE_LEATHER", "UNIT_SKINNABLE_HERB",
		"UNIT_SKINNABLE_ROCK", "UNIT_SKINNABLE_BOLTS", "UNIT_SKINNABLE_HIDE" }) do
	if type(_G[key]) == "string" then NOT_FACTION[_G[key]] = true end
end

local function Left(tooltip, i)
	local name = tooltip:GetName()
	return name and _G[name .. "TextLeft" .. i]
end

local function Right(tooltip, i)
	local name = tooltip:GetName()
	return name and _G[name .. "TextRight" .. i]
end

local function FindLevelLine(tooltip, data, numLines)
	if data and data.lines and LINE_UNITLEVEL then
		for i = 2, numLines do
			local line = data.lines[i]
			if line and line.type == LINE_UNITLEVEL then return i end
		end
	end
	for i = 2, numLines do
		local text = LineText(Left(tooltip, i))
		if text and LEVEL and text:find(LEVEL, 1, true) == 1 then return i end
	end
end

-- UnitName() can return your own realm for same-realm units, so compare it
-- (ignoring spaces/dashes, which differ between realm name formats).
local function NormalizeRealm(realm)
	return (realm:gsub("[%s%-']", ""):lower())
end

local function IsOtherRealm(realm)
	if not realm or realm == "" then return false end
	local own = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()
	if not own or Secret(own) then return true end
	return NormalizeRealm(realm) ~= NormalizeRealm(own)
end

local function StyleName(tooltip, unit, db, isPlayer)
	local left1 = Left(tooltip, 1)
	if not left1 then return end

	-- Name larger than everything else.
	local path, _, flags = GameTooltipHeaderText:GetFont()
	local _, bodySize = GameTooltipText:GetFont()
	if path and bodySize then
		left1:SetFont(path, bodySize + db.nameSize, flags)
		tooltip.drpurrNameFont = true
	end

	local text = LineText(left1)
	if text then
		if isPlayer and (db.hideTitles or db.hideRealm) then
			local name, realm = UnitName(unit)
			if name and not Secret(name, realm) then
				local base = name
				if not db.hideTitles then
					local pvpName = UnitPVPName(unit)
					if pvpName and not Secret(pvpName) then base = pvpName end
				end
				if IsOtherRealm(realm) then
					base = base .. (db.hideRealm and " (*)" or ("-" .. realm))
				end
				text = base
			end
		end
		if db.raidIcon then
			local index = GetRaidTargetIndex(unit)
			if index and not Secret(index) then
				text = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_" .. index .. ":0|t " .. text
			end
		end
		left1:SetText(text)
	end

	if db.nameColor then
		local r, g, b = UnitNameColor(unit)
		if r then left1:SetTextColor(r, g, b) end
	end
end

local function StyleGuild(tooltip, unit, numLines)
	local guild = GetGuildInfo(unit)
	if not guild or Secret(guild) then return end
	for i = 2, numLines do
		local left = Left(tooltip, i)
		local text = LineText(left)
		if text and (text:find(guild, 1, true) == 1 or text:find("<" .. guild, 1, true) == 1) then
			local inner = text:gsub("^<%s*", ""):gsub("%s*>$", "")
			left:SetText("< " .. inner .. " >")
			return i
		end
	end
end

-- Ask the game for this unit's difficulty (same as XPerl and nameplate addons),
-- rather than GetCreatureDifficultyColor(level): Forever's version of that uses
-- retail ranges (yellow down to 4 levels below you), so it disagreed with them.
local function LevelDifficultyColor(unit, level)
	if C_PlayerInfo and C_PlayerInfo.GetContentDifficultyCreatureForPlayer and GetDifficultyColor then
		local difficulty = C_PlayerInfo.GetContentDifficultyCreatureForPlayer(unit)
		if difficulty and not Secret(difficulty) then
			local c = GetDifficultyColor(difficulty)
			if c then return c end
		end
	end
	if GetCreatureDifficultyColor then
		return GetCreatureDifficultyColor(level > 0 and level or 999)
	end
end

local function StyleLevelLine(tooltip, unit, db, levelLine, isPlayer)
	local left = Left(tooltip, levelLine)
	local text = LineText(left)
	if not text then return end

	if db.abbrevLevel and LEVEL then
		text = text:gsub("^" .. Escape(LEVEL), "Lv.", 1)
	end

	local level = UnitLevel(unit)
	if Secret(level) then level = nil end

	if db.hidePetLevel and level and level > 0 then
		local wild = UnitIsWildBattlePet(unit)
		if wild and not Secret(wild) then
			local petLevel = UnitBattlePetLevel(unit)
			if petLevel and not Secret(petLevel) then
				text = text:gsub(tostring(level), tostring(petLevel), 1)
				level = petLevel
			end
		end
	end

	local canAttack = UnitCanAttack("player", unit)
	if Secret(canAttack) then canAttack = nil end

	if db.levelColor and canAttack and level then
		local levelText = level > 0 and tostring(level) or "??"
		local c = LevelDifficultyColor(unit, level)
		if c then
			text = text:gsub(Escape(levelText), Wrap(levelText, c.r, c.g, c.b), 1)
		end
	end

	if db.pvp and canAttack then
		local isPvP = UnitIsPVP(unit)
		if isPvP and not Secret(isPvP) and PVP then
			text = text .. " (" .. PVP .. ")"
		end
	end

	left:SetText(text)
end

local function StyleClassName(tooltip, unit, numLines, skipLine)
	local className = UnitClass(unit)
	if not className or Secret(className) then return end
	local r, g, b = ClassColor(unit)
	if not r then return end
	for i = 2, numLines do
		if i ~= skipLine then
			local left = Left(tooltip, i)
			local text = LineText(left)
			local s, e
			if text then s, e = text:find(className, 1, true) end
			if s then
				left:SetText(text:sub(1, s - 1) .. Wrap(className, r, g, b) .. text:sub(e + 1))
				return
			end
		end
	end
end

local function HidePvPLine(tooltip, numLines)
	if not PVP then return end
	for i = 2, numLines do
		local left = Left(tooltip, i)
		if LineText(left) == PVP then
			left:SetText("")
			local right = Right(tooltip, i)
			if right then right:SetText("") end
		end
	end
end

local function StyleFaction(tooltip, unit, data, numLines, levelLine, isPlayer)
	local factionGroup, localized = UnitFactionGroup(unit)
	if Secret(factionGroup, localized) then factionGroup, localized = nil, nil end
	local groupColor = factionGroup == "Alliance" and PLAYER_FACTION_COLORS[1]
		or factionGroup == "Horde" and PLAYER_FACTION_COLORS[0] or nil

	local npcFactionDone = isPlayer
	for i = 2, numLines do
		local left = Left(tooltip, i)
		local text = LineText(left)
		if text and text ~= "" then
			if localized and groupColor and text == localized then
				left:SetTextColor(groupColor:GetRGB())
				npcFactionDone = true
			elseif not npcFactionDone and levelLine and i > levelLine
					and not NOT_FACTION[text] and not text:find("^%s*@")
					and (not data or not data.lines or not data.lines[i] or data.lines[i].type == LINE_NONE) then
				-- NPC reputation faction: first plain line after the level/type lines.
				local r, g, b = ReactionColor(unit)
				if r then left:SetTextColor(r, g, b) end
				npcFactionDone = true
			end
		end
	end
end

local function AddTargetLine(tooltip, unit)
	local target = unit .. "target"
	local exists = UnitExists(target)
	if not exists or Secret(exists) then return end
	local name = UnitName(target)
	if not name or Secret(name) then return end
	local r, g, b = UnitNameColor(target)
	tooltip:AddLine("@ " .. name, r or 1, g or 1, b or 1)
end

local clearHooked = {}
local function HookClear(tooltip)
	if clearHooked[tooltip] then return end
	clearHooked[tooltip] = true
	tooltip:HookScript("OnTooltipCleared", function(self)
		if self.drpurrNameFont then
			local left1 = Left(self, 1)
			if left1 then left1:SetFontObject(GameTooltipHeaderText) end
			self.drpurrNameFont = nil
		end
	end)
end

local function OnUnitTooltip(tooltip, data)
	local db = style.db
	if not db.enabled or not tooltip or tooltip:IsForbidden() or not tooltip.GetUnit then return end
	local _, unit = tooltip:GetUnit()
	if not unit or Secret(unit) then return end

	HookClear(tooltip)
	local numLines = tooltip:NumLines()
	local isPlayer = UnitIsPlayer(unit)
	if Secret(isPlayer) then isPlayer = nil end

	StyleName(tooltip, unit, db, isPlayer)
	local guildLine = isPlayer and db.guildBrackets and StyleGuild(tooltip, unit, numLines) or nil
	local levelLine = FindLevelLine(tooltip, data, numLines)
	if levelLine then StyleLevelLine(tooltip, unit, db, levelLine, isPlayer) end
	if isPlayer and db.classColor then StyleClassName(tooltip, unit, numLines, guildLine) end
	if db.pvp then HidePvPLine(tooltip, numLines) end
	if db.factionColor then StyleFaction(tooltip, unit, data, numLines, levelLine, isPlayer) end
	if db.target then AddTargetLine(tooltip, unit) end

	tooltip:Show()  -- re-layout for the changed text sizes
end

function style:OnInit()
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnUnitTooltip)
end
function style:OnEnable() end
function style:OnDisable() end

-------------------------------------------------------------------------------
-- Icons on chat-link tooltips
-------------------------------------------------------------------------------
local linkIcons = {
	key = "linkIcons",
	name = "Link icons",
	defaults = { enabled = true },
}

local iconFrame

local function ShowLinkIcon(tooltip, texture)
	if not linkIcons.db.enabled or tooltip ~= ItemRefTooltip or not texture or Secret(texture) then return end
	if not iconFrame then
		iconFrame = ItemRefTooltip:CreateTexture(nil, "ARTWORK")
		iconFrame:SetSize(36, 36)
		iconFrame:SetPoint("TOPRIGHT", ItemRefTooltip, "TOPLEFT", -2, 0)
		ItemRefTooltip:HookScript("OnTooltipCleared", function() iconFrame:Hide() end)
		ItemRefTooltip:HookScript("OnHide", function() iconFrame:Hide() end)
	end
	iconFrame:SetTexture(texture)
	iconFrame:Show()
end

local function DataID(data)
	local id = data and data.id
	if id and not Secret(id) then return id end
end

function linkIcons:OnInit()
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
		local id = DataID(data)
		if id then ShowLinkIcon(tooltip, C_Item.GetItemIconByID(id)) end
	end)
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip, data)
		local id = DataID(data)
		if id then ShowLinkIcon(tooltip, C_Spell.GetSpellTexture(id)) end
	end)
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Achievement, function(tooltip, data)
		local id = DataID(data)
		if id then ShowLinkIcon(tooltip, select(10, GetAchievementInfo(id))) end
	end)
end
function linkIcons:OnEnable() end
function linkIcons:OnDisable()
	if iconFrame then iconFrame:Hide() end
end

ns:RegisterTweak(style)
ns:RegisterTweak(linkIcons)
