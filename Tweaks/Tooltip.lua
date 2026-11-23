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
	name = "Anchor tooltip to mouse",
	tooltip = "Tooltips that would appear in Blizzard's default spot follow the cursor instead.",
	defaults = {
		enabled = true,
		corner = "BOTTOMLEFT",
		offsetX = 0,
		offsetY = 0,
	},
}

-- Corner = which side of the cursor the tooltip opens on.
-- Value = the tooltip point that sits on the cursor.
local CORNER_POINT = {
	BOTTOMLEFT = "TOPRIGHT",
	BOTTOMRIGHT = "TOPLEFT",
	TOPLEFT = "BOTTOMRIGHT",
	TOPRIGHT = "BOTTOMLEFT",
}
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
	local x, y = GetCursorPosition()
	local scale = tooltip:GetEffectiveScale()
	tooltip:ClearAllPoints()
	tooltip:SetPoint(CORNER_POINT[db.corner] or "TOPRIGHT", UIParent, "BOTTOMLEFT",
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
	name = "Skin tooltips",
	tooltip = "Replace the tooltip background, border and font with LibSharedMedia choices.",
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
		bgFile = LSM:Fetch("background", db.background, true),
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
	name = "Smart border color",
	tooltip = "Colour the tooltip border by item quality, NPC reaction or player class. Overrides Border color when it applies.",
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

ns:RegisterTweak(anchor)
ns:RegisterTweak(skin)
ns:RegisterTweak(smart)
