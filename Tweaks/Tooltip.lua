-- Tooltip tweaks: anchor to mouse, LibSharedMedia skinning, smart border colour.
local _, ns = ...

local LSM = LibStub("LibSharedMedia-3.0")

local issecretvalue = issecretvalue or function() return false end
local function Secret(...)
	for i = 1, select("#", ...) do
		if issecretvalue((select(i, ...))) then return true end
	end
	return false
end

-------------------------------------------------------------------------------
-- Anchor to mouse
-------------------------------------------------------------------------------
local anchor = {
	key = "tooltipAnchor",
	name = "Anchor to mouse",
	defaults = {
		enabled = true,
		corner = "BOTTOMLEFT",
		offsetX = 0,
		offsetY = 0,
	},
}

-- Corner = which side of the cursor the tooltip opens on.
-- point: the tooltip point that is placed on the cursor.
-- dx/dy: which corner of the cursor image it goes to, as multiples of the
-- cursor size measured from the tip (the image's top-left corner).
local CORNER_POINT = {
	BOTTOMLEFT  = { point = "TOPRIGHT",    dx = 0, dy = -1 },
	BOTTOMRIGHT = { point = "TOPLEFT",     dx = 1, dy = -1 },
	TOPLEFT     = { point = "BOTTOMRIGHT", dx = 0, dy = 0 },
	TOPRIGHT    = { point = "BOTTOMLEFT",  dx = 1, dy = 0 },
}

-- Blizzard's Cursor Size option (cursorSizePreferred): -1 = default, 0..4 = 32..128 px.
-- "Default" is treated as 32 px.
local CURSOR_PIXELS = { [-1] = 32, [0] = 32, [1] = 48, [2] = 64, [3] = 96, [4] = 128 }

-- Cursor image size in the same units GetCursorPosition() returns.
local function CursorSizeUnits()
	local pixels = CURSOR_PIXELS[tonumber(C_CVar.GetCVar("cursorSizePreferred")) or -1] or 32
	local _, physicalHeight = GetPhysicalScreenSize()
	if not physicalHeight or physicalHeight <= 0 then return pixels end
	return pixels * 768 / physicalHeight
end
ns.TOOLTIP_CORNERS = {
	{ "BOTTOMLEFT", "Bottom Left" },
	{ "BOTTOMRIGHT", "Bottom Right" },
	{ "TOPLEFT", "Top Left" },
	{ "TOPRIGHT", "Top Right" },
}

local following = {}     -- tooltip -> true while it should track the cursor
local hookedOwner = {}   -- tooltips whose SetOwner/OnUpdate/OnHide we've hooked

local function PositionAtCursor(tooltip)
	local db = anchor.db
	local corner = CORNER_POINT[db.corner] or CORNER_POINT.BOTTOMLEFT
	local x, y = GetCursorPosition()
	local size = CursorSizeUnits()
	x = x + corner.dx * size
	y = y + corner.dy * size
	local scale = tooltip:GetEffectiveScale()
	tooltip:ClearAllPoints()
	tooltip:SetPoint(corner.point, UIParent, "BOTTOMLEFT",
		x / scale + db.offsetX, y / scale + db.offsetY)
end

local function OnTooltipUpdate(tooltip)
	if following[tooltip] then
		PositionAtCursor(tooltip)
	end
end

local function StopFollowing(tooltip)
	following[tooltip] = nil
end

local function OnDefaultAnchor(tooltip)
	if not anchor.db.enabled or not tooltip or tooltip:IsForbidden() then return end
	if not hookedOwner[tooltip] then
		hookedOwner[tooltip] = true
		-- Any later SetOwner (by Blizzard or another addon) cancels following;
		-- the default-anchor hook below re-enables it after its own SetOwner.
		hooksecurefunc(tooltip, "SetOwner", StopFollowing)
		tooltip:HookScript("OnUpdate", OnTooltipUpdate)
		tooltip:HookScript("OnHide", StopFollowing)
	end
	following[tooltip] = true
	PositionAtCursor(tooltip)
end

function anchor:OnInit()
	hooksecurefunc("GameTooltip_SetDefaultAnchor", OnDefaultAnchor)
	if SharedTooltip_SetDefaultAnchor then
		hooksecurefunc("SharedTooltip_SetDefaultAnchor", OnDefaultAnchor)
	end
end

function anchor:OnEnable() end

function anchor:OnDisable()
	wipe(following)
end

-------------------------------------------------------------------------------
-- Skin (background / border / font from LibSharedMedia-3.0)
-------------------------------------------------------------------------------
local skin = {
	key = "tooltipSkin",
	name = "Skin",
	defaults = {
		enabled = true,
		background = "Solid",
		backgroundColor = "ff000000",
		backgroundOpacity = 85,
		border = "Blizzard Tooltip",
		borderColor = "ff808080",
		borderOpacity = 100,
		borderSize = 16,
		font = "Friz Quadrata TT",
		fontSize = 12,
		fontOutline = "NONE",
	},
}

local TOOLTIPS = {
	"GameTooltip", "ItemRefTooltip",
	"ShoppingTooltip1", "ShoppingTooltip2",
	"ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2",
	"EmbeddedItemTooltip", "GameTooltipTooltip",
}

local FONT_OBJECTS = {
	-- font object name, size offset from the chosen font size
	{ "GameTooltipHeaderText", 2 },
	{ "GameTooltipText", 0 },
	{ "GameTooltipTextSmall", -2 },
}
local originalFonts = {}

local backdrops = {}  -- tooltip -> our BackdropTemplate frame

local function HexToRGB(hex)
	local c = CreateColorFromHexString(hex)
	return c.r, c.g, c.b
end

local function DefaultBorderColor()
	if skin.db.enabled then
		local r, g, b = HexToRGB(skin.db.borderColor)
		return r, g, b, skin.db.borderOpacity / 100
	end
	return 1, 1, 1, 1
end

local function SetTooltipBorderColor(tooltip, r, g, b, a)
	local bd = backdrops[tooltip]
	if skin.db.enabled and bd and bd:IsShown() then
		bd:SetBackdropBorderColor(r, g, b, a)
	elseif tooltip.NineSlice and tooltip.NineSlice.SetBorderColor then
		tooltip.NineSlice:SetBorderColor(r, g, b, a)
	end
end

local function BuildBackdrop()
	local db = skin.db
	local edgeFile = LSM:Fetch("border", db.border, true)
	if edgeFile == "" or (edgeFile and edgeFile:lower() == "interface\\none") then edgeFile = nil end
	local edgeSize = db.borderSize
	local inset = edgeFile and math.floor(edgeSize / 4) or 0
	return {
		-- Backgrounds can also be statusbar textures; the background version wins on a name clash.
		bgFile = LSM:Fetch("background", db.background, true) or LSM:Fetch("statusbar", db.background, true),
		edgeFile = edgeFile,
		edgeSize = edgeSize,
		tile = true,
		tileSize = 16,
		insets = { left = inset, right = inset, top = inset, bottom = inset },
	}
end

local function SkinTooltip(tooltip)
	if not tooltip or tooltip:IsForbidden() or tooltip.IsEmbedded or not tooltip.NineSlice then return end
	local bd = backdrops[tooltip]
	if not bd then
		bd = CreateFrame("Frame", nil, tooltip, "BackdropTemplate")
		bd:SetAllPoints(tooltip)
		bd:SetUsingParentLevel(true)
		backdrops[tooltip] = bd
	end
	local db = skin.db
	bd:SetBackdrop(BuildBackdrop())
	local r, g, b = HexToRGB(db.backgroundColor)
	bd:SetBackdropColor(r, g, b, db.backgroundOpacity / 100)
	bd:SetBackdropBorderColor(DefaultBorderColor())
	bd:Show()
	tooltip.NineSlice:SetAlpha(0)
end

local function UnskinTooltip(tooltip)
	local bd = backdrops[tooltip]
	if bd then bd:Hide() end
	if tooltip.NineSlice then
		tooltip.NineSlice:SetAlpha(1)
		tooltip.NineSlice:SetBorderColor(1, 1, 1, 1)
	end
end

local function ApplyFonts()
	local db = skin.db
	local path = LSM:Fetch("font", db.font, true)
	if not path then return end
	local flags = db.fontOutline ~= "NONE" and db.fontOutline or ""
	for _, info in ipairs(FONT_OBJECTS) do
		local fontObject = _G[info[1]]
		if fontObject then
			if not originalFonts[fontObject] then
				originalFonts[fontObject] = { fontObject:GetFont() }
			end
			fontObject:SetFont(path, math.max(6, db.fontSize + info[2]), flags)
		end
	end
end

local function RestoreFonts()
	for fontObject, f in pairs(originalFonts) do
		if f[1] then fontObject:SetFont(f[1], f[2], f[3]) end
	end
end

local function ApplyAll()
	for _, name in ipairs(TOOLTIPS) do
		local tooltip = _G[name]
		if tooltip then SkinTooltip(tooltip) end
	end
	for tooltip in pairs(backdrops) do SkinTooltip(tooltip) end
	ApplyFonts()
end

function skin:OnInit()
	-- Catches every tooltip using Blizzard's shared template, including ones created later.
	hooksecurefunc("SharedTooltip_SetBackdropStyle", function(tooltip, _, embedded)
		if skin.db.enabled and not embedded then
			SkinTooltip(tooltip)
		end
	end)
	-- Re-apply when other addons register new media after us.
	LSM.RegisterCallback(skin, "LibSharedMedia_Registered", function()
		if skin.db.enabled then ApplyAll() end
	end)
end

function skin:OnEnable()
	ApplyAll()
end

function skin:OnDisable()
	for tooltip in pairs(backdrops) do UnskinTooltip(tooltip) end
	RestoreFonts()
end

function skin:OnSettingChanged()
	ApplyAll()
end

-------------------------------------------------------------------------------
-- Smart border colour (item quality / NPC reaction / player class)
-------------------------------------------------------------------------------
local smart = {
	key = "tooltipSmartBorder",
	name = "Smart border",
	defaults = { enabled = true },
}

local function UnitBorderColor(tooltip)
	local _, unit = tooltip:GetUnit()
	if not unit or Secret(unit) then return end
	local isPlayer = UnitIsPlayer(unit)
	if Secret(isPlayer) then return end
	if isPlayer then
		local _, class = UnitClass(unit)
		if class and not Secret(class) then
			local c = C_ClassColor.GetClassColor(class)
			if c then return c.r, c.g, c.b end
		end
	else
		local reaction = UnitReaction(unit, "player")
		if reaction and not Secret(reaction) then
			local c = FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
			if c then return c.r, c.g, c.b end
		end
	end
end

local function ItemBorderColor(tooltip)
	local _, link = tooltip:GetItem()
	if not link or Secret(link) then return end
	local quality = C_Item.GetItemQualityByID(link)
	if quality and not Secret(quality) then
		local r, g, b = C_Item.GetItemQualityColor(quality)
		if r then return r, g, b end
	end
end

local function ApplySmartColor(tooltip, getColor)
	if not smart.db.enabled or tooltip:IsForbidden() then return end
	local r, g, b = getColor(tooltip)
	if r then
		local _, _, _, a = DefaultBorderColor()
		SetTooltipBorderColor(tooltip, r, g, b, a)
	end
end

local clearHooked = {}
local function HookClear(tooltip)
	if clearHooked[tooltip] then return end
	clearHooked[tooltip] = true
	tooltip:HookScript("OnTooltipCleared", function(self)
		if smart.db.enabled and not self:IsForbidden() then
			SetTooltipBorderColor(self, DefaultBorderColor())
		end
	end)
end

function smart:OnInit()
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
		if tooltip.GetUnit then
			HookClear(tooltip)
			ApplySmartColor(tooltip, UnitBorderColor)
		end
	end)
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
		if tooltip.GetItem then
			HookClear(tooltip)
			ApplySmartColor(tooltip, ItemBorderColor)
		end
	end)
end

function smart:OnEnable() end

function smart:OnDisable()
	for tooltip in pairs(clearHooked) do
		SetTooltipBorderColor(tooltip, DefaultBorderColor())
	end
end

-------------------------------------------------------------------------------
-- Fade out time (world-object tooltips that fade when you mouse off them)
-------------------------------------------------------------------------------
local fade = {
	key = "tooltipFade",
	name = "Fade out",
	defaults = {
		enabled = true,
		fadeTime = 0,
	},
}

-- Blizzard's fade runs in the client and can't be changed, so we run our own
-- (shorter) fade alongside it, or hide immediately when fadeTime is 0.
--
-- While Blizzard's fade is running the client owns the tooltip frame's alpha and
-- overwrites any SetAlpha on it every frame, so instead we fade the tooltip's
-- contents (its text/texture regions and child frames). Their alpha multiplies
-- with the frame's, and the client doesn't touch it.
local fading = {}  -- tooltip -> { start = time, parts = { [object] = originalAlpha } }

-- Unit tooltips (e.g. from mouseover) can mark lines as secret; their GetAlpha()
-- then returns a secret number we may not do maths on. Don't read it for those:
-- assume full opacity (tooltip parts are normally at 1) so they still fade.
local function SafeAlpha(object)
	if object.HasAnySecretAspect and object:HasAnySecretAspect() then
		return 1
	end
	local alpha = object:GetAlpha()
	if issecretvalue(alpha) then return 1 end
	return alpha
end

local function CollectParts(tooltip)
	local parts = {}
	for _, region in ipairs({ tooltip:GetRegions() }) do
		parts[region] = SafeAlpha(region)
	end
	for _, child in ipairs({ tooltip:GetChildren() }) do
		parts[child] = SafeAlpha(child)
	end
	return parts
end

local function SetPartsAlpha(state, factor)
	for object, original in pairs(state.parts) do
		object:SetAlpha(original * factor)
	end
end

local function StopFade(tooltip)
	local state = fading[tooltip]
	if state then
		fading[tooltip] = nil
		SetPartsAlpha(state, 1)
	end
end

local function OnFadeUpdate(tooltip)
	local state = fading[tooltip]
	if not state then return end
	local progress = (GetTime() - state.start) / fade.db.fadeTime
	if progress >= 1 then
		StopFade(tooltip)
		tooltip:Hide()
	else
		SetPartsAlpha(state, 1 - progress)
	end
end

local function OnFadeOut(tooltip)
	if not fade.db.enabled or tooltip:IsForbidden() then return end
	if fade.db.fadeTime <= 0 then
		tooltip:Hide()
	else
		StopFade(tooltip)
		fading[tooltip] = { start = GetTime(), parts = CollectParts(tooltip) }
	end
end

function fade:OnInit()
	hooksecurefunc(GameTooltip, "FadeOut", OnFadeOut)
	GameTooltip:HookScript("OnUpdate", OnFadeUpdate)
	GameTooltip:HookScript("OnShow", StopFade)
	GameTooltip:HookScript("OnHide", StopFade)
	-- Re-hovering while the tooltip is still fading doesn't fire OnShow (it never
	-- hid), but Blizzard re-owns and re-shows it, so cancel the fade there too.
	hooksecurefunc(GameTooltip, "SetOwner", StopFade)
	hooksecurefunc(GameTooltip, "Show", StopFade)
end

function fade:OnEnable() end

function fade:OnDisable()
	for tooltip in pairs(fading) do StopFade(tooltip) end
end

-------------------------------------------------------------------------------
-- Health bar inside the tooltip border
-------------------------------------------------------------------------------
local healthBar = {
	key = "tooltipHealthBar",
	name = "Inner health bar",
	defaults = {
		enabled = true,
		height = 6,
	},
}

local BLIZZARD_BORDER_INSET = 4
local BAR_GAP = 2  -- space between the border and the bar, and between text and bar

-- How far the visible border reaches into the tooltip.
local function BorderInset(tooltip)
	local bd = backdrops[tooltip]
	if skin.db.enabled and bd and bd:IsShown() then
		local edgeFile = LSM:Fetch("border", skin.db.border, true)
		if not edgeFile or edgeFile == "" or edgeFile:lower() == "interface\\none" then return 0 end
		return math.floor(skin.db.borderSize / 4)
	end
	return BLIZZARD_BORDER_INSET
end

local function SetBottomPadding(tooltip, bottom)
	local right = tooltip:GetPadding()
	tooltip:SetPadding(right or 0, bottom, 0, 0)
end

local function LayoutBar(tooltip)
	local bar = tooltip.StatusBar
	if not bar or tooltip:IsForbidden() then return end
	if not healthBar.db.enabled then return end
	local inset = BorderInset(tooltip) + BAR_GAP
	bar:ClearAllPoints()
	bar:SetPoint("BOTTOMLEFT", tooltip, "BOTTOMLEFT", inset, inset)
	bar:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", -inset, inset)
	bar:SetHeight(healthBar.db.height)
	if bar:IsShown() then
		SetBottomPadding(tooltip, healthBar.db.height + BAR_GAP)
		tooltip.drpurrBarPadding = true
	elseif tooltip.drpurrBarPadding then
		SetBottomPadding(tooltip, 0)
		tooltip.drpurrBarPadding = nil
	end
end

local function RestoreBar(tooltip)
	local bar = tooltip.StatusBar
	if not bar then return end
	-- Blizzard's original anchors from GameTooltip.xml.
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", tooltip, "BOTTOMLEFT", 2, -1)
	bar:SetPoint("TOPRIGHT", tooltip, "BOTTOMRIGHT", -2, -1)
	bar:SetHeight(8)
	if tooltip.drpurrBarPadding then
		SetBottomPadding(tooltip, 0)
		tooltip.drpurrBarPadding = nil
	end
end

function healthBar:OnInit()
	local tooltip = GameTooltip
	local bar = tooltip.StatusBar
	if not bar then return end
	-- Blizzard clears padding in GameTooltip's OnShow; our hook runs after it.
	tooltip:HookScript("OnShow", LayoutBar)
	bar:HookScript("OnShow", function() LayoutBar(tooltip) end)
	bar:HookScript("OnHide", function() LayoutBar(tooltip) end)
end

function healthBar:OnEnable()
	LayoutBar(GameTooltip)
end

function healthBar:OnDisable()
	RestoreBar(GameTooltip)
end

function healthBar:OnSettingChanged()
	LayoutBar(GameTooltip)
end

ns:RegisterTweak(anchor)
ns:RegisterTweak(skin)
ns:RegisterTweak(smart)
ns:RegisterTweak(healthBar)
ns:RegisterTweak(fade)
