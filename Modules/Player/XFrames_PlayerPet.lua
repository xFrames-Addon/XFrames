local _, ns = ...

local XFrames = ns.XFrames
local PlayerPet = {}

local CreateFrame = CreateFrame
local SetPortraitTexture = SetPortraitTexture
local UnitExists = UnitExists
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitName = UnitName
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax

local BACKDROP_COLOR = {0.08, 0.09, 0.11, 0.92}
local BORDER_COLOR = {0.24, 0.27, 0.31, 0.95}
local HEALTH_BAR_COLOR = {r = 0.18, g = 0.62, b = 0.32}
local POWER_BAR_COLOR = {r = 0.23, g = 0.27, b = 0.35}
local PORTRAIT_BG_COLOR = {0.10, 0.11, 0.14, 0.98}

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
	bar:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)

	bar.bg = bar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetAllPoints()
	bar.bg:SetColorTexture(0.12, 0.13, 0.16, 0.95)

	bar.labelText = createText(bar, "OVERLAY", "GameFontNormalSmall", 9, "LEFT", bar, "LEFT", 5, 0, "LEFT")
	bar.valueText = createText(bar, "OVERLAY", "GameFontHighlightSmall", 10, "RIGHT", bar, "RIGHT", -4, 0, "RIGHT")
	bar.percentText = createText(bar, "OVERLAY", "GameFontDisableSmall", 9, "RIGHT", bar.valueText, "LEFT", -8, 0, "RIGHT")
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
	frame:SetBackdropColor(unpack(PORTRAIT_BG_COLOR))
	frame:SetBackdropBorderColor(unpack(BORDER_COLOR))
	return frame
end

function PlayerPet:CreateFrame()
	if self.frame then
		return self.frame
	end

	local config = XFrames.db.profile.player.pet
	local frame = CreateFrame("Frame", "XFramesPlayerPetFrame", UIParent, "BackdropTemplate")
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
	frame:Hide()

	frame.portraitFrame = createBackdropFrame(nil, frame, 42, 42, "TOPLEFT", frame, "TOPLEFT", 4, -4)
	frame.portraitTexture = frame.portraitFrame:CreateTexture(nil, "ARTWORK")
	frame.portraitTexture:SetPoint("TOPLEFT", frame.portraitFrame, "TOPLEFT", 2, -2)
	frame.portraitTexture:SetSize(38, 38)
	frame.portraitTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	frame.nameText = createText(frame, "OVERLAY", "GameFontNormal", 12, "TOPLEFT", frame, "TOPLEFT", 50, -8, "LEFT")
	frame.statusText = createText(frame, "OVERLAY", "GameFontHighlightSmall", 10, "TOPLEFT", frame.nameText, "BOTTOMLEFT", 0, -2, "LEFT")

	frame.healthBar = createBar(frame, 11, "TOPLEFT", frame, "TOPLEFT", 50, -28)
	frame.powerBar = createBar(frame, 9, "TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, -5)

	self.frame = frame
	return frame
end

function PlayerPet:UpdateName()
	local frame = self.frame
	if not UnitExists("pet") then
		frame.nameText:SetText("Pet")
		return
	end

	frame.nameText:SetText(UnitName("pet") or "Pet")
end

function PlayerPet:UpdateStatus()
	self.frame.statusText:SetText("Pet")
end

function PlayerPet:UpdatePortrait()
	if not UnitExists("pet") then
		self.frame.portraitTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
		return
	end

	SetPortraitTexture(self.frame.portraitTexture, "pet")
end

function PlayerPet:UpdateHealth()
	local bar = self.frame.healthBar
	local value = UnitHealth("pet")
	local maxValue = UnitHealthMax("pet")

	bar:SetStatusBarColor(HEALTH_BAR_COLOR.r, HEALTH_BAR_COLOR.g, HEALTH_BAR_COLOR.b)
	XFrames:SetBarValues(bar, value, maxValue)
end

function PlayerPet:UpdatePower()
	local bar = self.frame.powerBar
	local value = UnitPower("pet")
	local maxValue = UnitPowerMax("pet")
	local _, color = XFrames:GetUnitPowerPresentation("pet", true)

	bar:SetStatusBarColor(color.r, color.g, color.b)
	XFrames:SetBarValues(bar, value, maxValue)
end

function PlayerPet:Refresh()
	if not self.frame then
		return
	end

	if not UnitExists("pet") then
		self.frame:Hide()
		return
	end

	self.frame:Show()
	self:UpdateName()
	self:UpdateStatus()
	self:UpdatePortrait()
	self:UpdateHealth()
	self:UpdatePower()
end

function PlayerPet:OnEvent(event, unit)
	if unit and unit ~= "pet" and unit ~= "player" then
		return
	end

	if event == "UNIT_PET" then
		self:Refresh()
		return
	end

	self:Refresh()
end

function PlayerPet:RegisterEvents()
	local frame = self.frame
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterUnitEvent("UNIT_PET", "player")
	frame:RegisterUnitEvent("UNIT_HEALTH", "pet")
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", "pet")
	frame:RegisterUnitEvent("UNIT_NAME_UPDATE", "pet")
	frame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "pet")
	frame:RegisterUnitEvent("UNIT_POWER_UPDATE", "pet")
	frame:RegisterUnitEvent("UNIT_MAXPOWER", "pet")
	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", "pet")
	frame:SetScript("OnEvent", function(_, event, ...)
		XFrames:SafeCall("module PlayerPet:OnEvent", self.OnEvent, self, event, ...)
	end)
end

function PlayerPet:Initialize()
	self.enabled = XFrames.db.profile.player.pet.enabled
end

function PlayerPet:Enable()
	if not self.enabled then
		return
	end

	self:CreateFrame()
	self:RegisterEvents()
	self:Refresh()
	XFrames:Info("Player pet shell enabled")
end

XFrames:RegisterModule("PlayerPet", PlayerPet)
