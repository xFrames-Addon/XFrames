local _, ns = ...

local XFrames = ns.XFrames
local Player = {}

local RAID_CLASS_COLORS = RAID_CLASS_COLORS

local CreateFrame = CreateFrame
local SetPortraitTexture = SetPortraitTexture
local UnitClass = UnitClass
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitName = UnitName
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitLevel = UnitLevel

local HEALTH_BAR_COLOR = {r = 0.18, g = 0.62, b = 0.32}
local BACKDROP_COLOR = {0.08, 0.09, 0.11, 0.92}
local BORDER_COLOR = {0.24, 0.27, 0.31, 0.95}
local POWER_BAR_COLOR = {r = 0.24, g = 0.28, b = 0.36}
local PORTRAIT_BG_COLOR = {0.10, 0.11, 0.14, 0.98}

local function getStatusText()
	local className = UnitClass("player")
	return className or "Player"
end

local function createText(parent, layer, template, size, anchorPoint, relativeTo, relativePoint, x, y, justify)
	local text = parent:CreateFontString(nil, layer, template)
	text:SetPoint(anchorPoint, relativeTo, relativePoint, x, y)
	text:SetJustifyH(justify or "LEFT")

	local font, _, flags = text:GetFont()
	if font then
		text:SetFont(font, size, flags)
	end
	return text
end

local function createBar(parent, height, anchorPoint, relativeTo, relativePoint, x, y)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetHeight(height)
	bar:SetPoint(anchorPoint, relativeTo, relativePoint, x, y)
	bar:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)

	bar.bg = bar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetAllPoints()
	bar.bg:SetColorTexture(0.12, 0.13, 0.16, 0.95)

	bar.labelText = createText(bar, "OVERLAY", "GameFontNormalSmall", 10, "LEFT", bar, "LEFT", 6, 0, "LEFT")
	bar.valueText = createText(bar, "OVERLAY", "GameFontHighlightSmall", 11, "RIGHT", bar, "RIGHT", -4, 0, "RIGHT")
	bar.percentText = createText(bar, "OVERLAY", "GameFontDisableSmall", 10, "RIGHT", bar.valueText, "LEFT", -10, 0, "RIGHT")
	bar.valueText:SetText("")
	bar.percentText:SetText("")
	bar.labelText:Hide()
	bar.percentText:Hide()

	return bar
end

local function createBackdropFrame(name, parent, width, height, anchorPoint, relativeTo, relativePoint, x, y)
	local frame = CreateFrame("Frame", name, parent, "BackdropTemplate")
	frame:SetSize(width, height)
	frame:SetPoint(anchorPoint, relativeTo, relativePoint, x, y)
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
		insets = {left = 1, right = 1, top = 1, bottom = 1},
	})
	frame:SetBackdropColor(unpack(BACKDROP_COLOR))
	frame:SetBackdropBorderColor(unpack(BORDER_COLOR))
	return frame
end

function Player:CreateFrame()
	if self.frame then
		return self.frame
	end

	local config = XFrames.db.profile.player
	local frame = CreateFrame("Button", "XFramesPlayerFrame", UIParent, "SecureUnitButtonTemplate,BackdropTemplate")
	frame:SetSize(config.width, config.height)
	frame:SetScale(config.scale or 1)
	frame:SetPoint(config.position.point, UIParent, config.position.relativePoint, config.position.x, config.position.y)
	frame:SetFrameStrata("MEDIUM")
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
		insets = {left = 1, right = 1, top = 1, bottom = 1},
	})
	frame:SetBackdropColor(unpack(BACKDROP_COLOR))
	frame:SetBackdropBorderColor(unpack(BORDER_COLOR))

	frame.portraitFrame = createBackdropFrame(nil, frame, 52, 52, "TOPLEFT", frame, "TOPLEFT", 6, -6)
	frame.portraitFrame:SetBackdropColor(unpack(PORTRAIT_BG_COLOR))
	frame.portraitTexture = frame.portraitFrame:CreateTexture(nil, "ARTWORK")
	frame.portraitTexture:SetPoint("TOPLEFT", frame.portraitFrame, "TOPLEFT", 2, -2)
	frame.portraitTexture:SetSize(48, 48)
	frame.portraitTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	frame.nameText = createText(frame, "OVERLAY", "GameFontNormalLarge", 13, "TOPLEFT", frame, "TOPLEFT", 64, -10, "LEFT")
	frame.levelText = createText(frame, "OVERLAY", "GameFontHighlight", 12, "TOPRIGHT", frame, "TOPRIGHT", -10, -10, "RIGHT")
	frame.statusText = createText(frame, "OVERLAY", "GameFontHighlightSmall", 10, "TOPLEFT", frame.nameText, "BOTTOMLEFT", 0, -2, "LEFT")

	frame.healthBar = createBar(frame, 14, "TOPLEFT", frame, "TOPLEFT", 64, -40)
	frame.healthBar:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
	frame.powerBar = createBar(frame, 12, "TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, -6)
	frame.powerBar:SetPoint("RIGHT", frame, "RIGHT", -10, 0)

	if config.castBar and config.castBar.enabled then
		frame.castFrame = createBackdropFrame(nil, frame, config.castBar.width, config.castBar.height, "TOPLEFT", frame, "BOTTOMLEFT", 0, -8)
		frame.castBar = createBar(frame.castFrame, config.castBar.height - 6, "TOPLEFT", frame.castFrame, "TOPLEFT", 3, -3)
		frame.castBar:SetPoint("RIGHT", frame.castFrame, "RIGHT", -3, 0)
		frame.castBar.valueText:Hide()
		frame.castBar.percentText:Hide()
		frame.castSpellText = createText(frame.castFrame, "OVERLAY", "GameFontHighlightSmall", 11, "LEFT", frame.castBar, "LEFT", 6, 0, "LEFT")
		frame.castTimeText = createText(frame.castFrame, "OVERLAY", "GameFontHighlightSmall", 10, "RIGHT", frame.castBar, "RIGHT", -6, 0, "RIGHT")
		frame.castSpellText:SetText("")
		frame.castTimeText:SetText("")
		frame.castFrame:Hide()
	end

	self.frame = frame
	XFrames:RegisterInteractiveUnitFrame(frame, "player", false)
	XFrames:RegisterMovableFrame(frame, config.position, "Player")
	return frame
end

function Player:UpdatePortraitBorder()
	local _, class = UnitClass("player")
	local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]

	if color then
		self.frame.portraitFrame:SetBackdropBorderColor(color.r, color.g, color.b, 1)
	else
		self.frame.portraitFrame:SetBackdropBorderColor(unpack(BORDER_COLOR))
	end
end

function Player:UpdateName()
	local frame = self.frame
	local name = UnitName("player") or "Player"
	local _, class = UnitClass("player")
	local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]

	frame.nameText:SetText(name)
	if color then
		frame.nameText:SetTextColor(color.r, color.g, color.b)
	else
		frame.nameText:SetTextColor(1, 1, 1)
	end
end

function Player:UpdateLevel()
	XFrames:SetValueText(self.frame.levelText, UnitLevel("player"))
end

function Player:UpdateStatus()
	self.frame.statusText:SetText(getStatusText())
end

function Player:UpdatePortrait()
	SetPortraitTexture(self.frame.portraitTexture, "player")
	self:UpdatePortraitBorder()
end

function Player:UpdateHealth()
	local bar = self.frame.healthBar
	local value = UnitHealth("player")
	local maxValue = UnitHealthMax("player")

	bar:SetStatusBarColor(HEALTH_BAR_COLOR.r, HEALTH_BAR_COLOR.g, HEALTH_BAR_COLOR.b)
	XFrames:SetBarValues(bar, value, maxValue)
end

function Player:UpdatePower()
	local bar = self.frame.powerBar
	local value = UnitPower("player")
	local maxValue = UnitPowerMax("player")
	local _, color = XFrames:GetUnitPowerPresentation("player")

	bar:SetStatusBarColor(color.r, color.g, color.b)
	XFrames:SetBarValues(bar, value, maxValue)
end

function Player:StopCastBar()
	if not self.frame or not self.frame.castFrame then
		return
	end

	self.castState = nil
	if self.frame.castFrame then
		self.frame.castFrame:Hide()
		self.frame.castFrame:SetScript("OnUpdate", nil)
	end
end

function Player:RefreshCastState()
	self:StopCastBar()
end

function Player:Refresh()
	if not self.frame then
		return
	end

	self:UpdateName()
	self:UpdateLevel()
	self:UpdateStatus()
	self:UpdatePortrait()
	self:UpdateHealth()
	self:UpdatePower()
	self:RefreshCastState()
end

function Player:OnEvent(event, unit)
	if unit and unit ~= "player" and not string.find(event, "^UNIT_SPELLCAST") then
		return
	end

	if event == "PLAYER_LEVEL_UP" then
		self:UpdateLevel()
		return
	end

	if event == "UNIT_NAME_UPDATE" then
		self:UpdateName()
		return
	end

	if event == "UNIT_PORTRAIT_UPDATE" then
		self:UpdatePortrait()
		return
	end

	if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
		self:UpdateHealth()
		return
	end

	if event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
		self:UpdatePower()
		return
	end

	if event == "PLAYER_FLAGS_CHANGED" then
		self:UpdateStatus()
		return
	end

	self:Refresh()
end

function Player:RegisterEvents()
	local frame = self.frame
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("PLAYER_LEVEL_UP")
	frame:RegisterEvent("PLAYER_FLAGS_CHANGED")
	frame:RegisterUnitEvent("UNIT_HEALTH", "player")
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
	frame:RegisterUnitEvent("UNIT_NAME_UPDATE", "player")
	frame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "player")
	frame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
	frame:RegisterUnitEvent("UNIT_MAXPOWER", "player")
	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
	frame:SetScript("OnEvent", function(_, event, ...)
		XFrames:SafeCall("module Player:OnEvent", self.OnEvent, self, event, ...)
	end)
end

function Player:Initialize()
	self.enabled = XFrames.db.profile.player.enabled
end

function Player:Enable()
	if not self.enabled then
		return
	end

	self:CreateFrame()
	self:RegisterEvents()
	self:Refresh()
	self.frame:Show()
	XFrames:Info("Player shell enabled")
end

function Player:ForEachFrame(callback)
	if self.frame then
		callback(self.frame)
	end
end

XFrames:RegisterModule("Player", Player)
