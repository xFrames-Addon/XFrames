local _, ns = ...

local XFrames = ns.XFrames
local Target = {}

local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local PowerBarColor = PowerBarColor

local CreateFrame = CreateFrame
local SetPortraitTexture = SetPortraitTexture
local UnitClass = UnitClass
local UnitCreatureType = UnitCreatureType
local UnitExists = UnitExists
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitIsAFK = UnitIsAFK
local UnitIsConnected = UnitIsConnected
local UnitIsDND = UnitIsDND
local UnitIsDead = UnitIsDead
local UnitIsGhost = UnitIsGhost
local UnitIsPlayer = UnitIsPlayer
local UnitLevel = UnitLevel
local UnitName = UnitName
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerType = UnitPowerType

local HEALTH_BAR_COLOR = {r = 0.72, g = 0.22, b = 0.22}
local FOCUS_HEALTH_BAR_COLOR = {r = 0.72, g = 0.58, b = 0.22}
local BACKDROP_COLOR = {0.08, 0.09, 0.11, 0.92}
local BORDER_COLOR = {0.24, 0.27, 0.31, 0.95}
local POWER_BAR_COLORS = {
	[0] = {r = 0.18, g = 0.48, b = 0.90},
	[1] = {r = 0.86, g = 0.26, b = 0.20},
	[2] = {r = 0.96, g = 0.78, b = 0.18},
	[3] = {r = 0.96, g = 0.78, b = 0.18},
	[6] = {r = 0.00, g = 0.82, b = 1.00},
}
local POWER_LABELS = {
	[0] = "Mana",
	[1] = "Rage",
	[2] = "Focus",
	[3] = "Energy",
	[6] = "Runic Power",
}

local function shortValue(value)
	if not value then
		return "0"
	end

	if value >= 1000000 then
		return string.format("%.1fm", value / 1000000)
	end

	if value >= 1000 then
		return string.format("%.1fk", value / 1000)
	end

	return tostring(value)
end

local function percentText(current, maximum)
	if not maximum or maximum <= 0 then
		return "0%"
	end

	return string.format("%d%%", (current / maximum) * 100)
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

	bar.valueText = createText(bar, "OVERLAY", "GameFontHighlightSmall", 11, "RIGHT", bar, "RIGHT", -4, 0, "RIGHT")
	bar.percentText = createText(bar, "OVERLAY", "GameFontDisableSmall", 10, "RIGHT", bar.valueText, "LEFT", -10, 0, "RIGHT")

	return bar
end

local function getStatusText(unit, fallbackLabel)
	if not UnitExists(unit) then
		return fallbackLabel
	end
	if not UnitIsConnected(unit) then
		return "Offline"
	end
	if UnitIsDead(unit) then
		return "Dead"
	end
	if UnitIsGhost(unit) then
		return "Ghost"
	end
	if UnitIsAFK(unit) then
		return "AFK"
	end
	if UnitIsDND(unit) then
		return "DND"
	end
	if UnitIsPlayer(unit) then
		local className = UnitClass(unit)
		return className or fallbackLabel
	end

	return UnitCreatureType(unit) or fallbackLabel
end

function Target:CreateUnitFrame(key, unit, config, accent)
	local frameName = key == "focus" and "XFramesFocusFrame" or "XFramesTargetFrame"
	local frame = CreateFrame("Frame", frameName, UIParent, "BackdropTemplate")
	frame.unit = unit
	frame.unitKey = key
	frame.fallbackLabel = key == "focus" and "Focus" or "Target"
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

	frame.portraitTexture = frame:CreateTexture(nil, "ARTWORK")
	frame.portraitTexture:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
	frame.portraitTexture:SetSize(48, 48)
	frame.portraitTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	frame.nameText = createText(frame, "OVERLAY", "GameFontNormalLarge", 13, "TOPLEFT", frame, "TOPLEFT", 64, -10, "LEFT")
	frame.levelText = createText(frame, "OVERLAY", "GameFontHighlight", 12, "TOPRIGHT", frame, "TOPRIGHT", -10, -10, "RIGHT")
	frame.statusText = createText(frame, "OVERLAY", "GameFontHighlightSmall", 10, "TOPLEFT", frame.nameText, "BOTTOMLEFT", 0, -4, "LEFT")

	frame.healthLabel = createText(frame, "OVERLAY", "GameFontNormalSmall", 11, "TOPLEFT", frame, "TOPLEFT", 64, -36, "LEFT")
	frame.healthLabel:SetText("Health")
	frame.healthBar = createBar(frame, 16, "TOPLEFT", frame.healthLabel, "BOTTOMLEFT", 0, -2)
	frame.healthAccent = accent

	frame.powerLabel = createText(frame, "OVERLAY", "GameFontNormalSmall", 11, "TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, -10, "LEFT")
	frame.powerBar = createBar(frame, 14, "TOPLEFT", frame.powerLabel, "BOTTOMLEFT", 0, -2)

	return frame
end

function Target:UpdateName(frame)
	if not UnitExists(frame.unit) then
		frame.nameText:SetText(frame.fallbackLabel)
		frame.nameText:SetTextColor(1, 1, 1)
		return
	end

	local name = UnitName(frame.unit) or frame.fallbackLabel
	local _, class = UnitClass(frame.unit)
	local color = UnitIsPlayer(frame.unit) and class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]

	frame.nameText:SetText(name)
	if color then
		frame.nameText:SetTextColor(color.r, color.g, color.b)
	else
		frame.nameText:SetTextColor(1, 1, 1)
	end
end

function Target:UpdateLevel(frame)
	if not UnitExists(frame.unit) then
		frame.levelText:SetText("")
		return
	end

	local level = UnitLevel(frame.unit) or 0
	if level > 0 then
		frame.levelText:SetText(string.format("Lv %d", level))
	else
		frame.levelText:SetText("??")
	end
end

function Target:UpdateStatus(frame)
	frame.statusText:SetText(getStatusText(frame.unit, frame.fallbackLabel))
end

function Target:UpdatePortrait(frame)
	if not UnitExists(frame.unit) then
		frame.portraitTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
		return
	end

	SetPortraitTexture(frame.portraitTexture, frame.unit)
end

function Target:UpdateHealth(frame)
	local current = UnitHealth(frame.unit) or 0
	local maximum = UnitHealthMax(frame.unit) or 0
	local bar = frame.healthBar
	local accent = frame.healthAccent or HEALTH_BAR_COLOR

	if maximum <= 0 then
		maximum = 1
	end

	bar:SetStatusBarColor(accent.r, accent.g, accent.b)
	bar:SetMinMaxValues(0, maximum)
	bar:SetValue(current)
	bar.valueText:SetText(string.format("%s / %s", shortValue(current), shortValue(maximum)))
	bar.percentText:SetText(percentText(current, maximum))
end

function Target:UpdatePower(frame)
	local powerType = UnitPowerType(frame.unit)
	local current = UnitPower(frame.unit, powerType) or 0
	local maximum = UnitPowerMax(frame.unit, powerType) or 0
	local color = POWER_BAR_COLORS[powerType] or (PowerBarColor and PowerBarColor[powerType]) or POWER_BAR_COLORS[0]
	local bar = frame.powerBar

	if maximum <= 0 then
		maximum = 1
	end

	frame.powerLabel:SetText(POWER_LABELS[powerType] or "Power")
	bar:SetStatusBarColor(color.r, color.g, color.b)
	bar:SetMinMaxValues(0, maximum)
	bar:SetValue(current)
	bar.valueText:SetText(string.format("%s / %s", shortValue(current), shortValue(maximum)))
	bar.percentText:SetText(percentText(current, maximum))
end

function Target:RefreshFrame(frame)
	if not frame then
		return
	end

	if not UnitExists(frame.unit) then
		frame:Hide()
		return
	end

	frame:Show()
	self:UpdateName(frame)
	self:UpdateLevel(frame)
	self:UpdateStatus(frame)
	self:UpdatePortrait(frame)
	self:UpdateHealth(frame)
	self:UpdatePower(frame)
end

function Target:RefreshAll()
	self:RefreshFrame(self.targetFrame)
	self:RefreshFrame(self.focusFrame)
end

function Target:OnEvent(event, unit)
	if event == "PLAYER_TARGET_CHANGED" then
		self:RefreshFrame(self.targetFrame)
		return
	end

	if event == "PLAYER_FOCUS_CHANGED" then
		self:RefreshFrame(self.focusFrame)
		return
	end

	if unit == "target" then
		self:RefreshFrame(self.targetFrame)
		return
	end

	if unit == "focus" then
		self:RefreshFrame(self.focusFrame)
		return
	end

	self:RefreshAll()
end

function Target:RegisterEvents()
	local frame = self.eventFrame
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("PLAYER_TARGET_CHANGED")
	frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
	frame:RegisterEvent("PLAYER_FLAGS_CHANGED")
	frame:RegisterUnitEvent("UNIT_HEALTH", "target", "focus")
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", "target", "focus")
	frame:RegisterUnitEvent("UNIT_POWER_UPDATE", "target", "focus")
	frame:RegisterUnitEvent("UNIT_MAXPOWER", "target", "focus")
	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", "target", "focus")
	frame:RegisterUnitEvent("UNIT_NAME_UPDATE", "target", "focus")
	frame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "target", "focus")
	frame:SetScript("OnEvent", function(_, event, ...)
		XFrames:SafeCall("module Target:OnEvent", self.OnEvent, self, event, ...)
	end)
end

function Target:Initialize()
	self.enabled = XFrames.db.profile.target.enabled
	self.focusEnabled = XFrames.db.profile.target.focus.enabled
	self.targetTargetEnabled = XFrames.db.profile.target.targettarget.enabled
end

function Target:Enable()
	if not self.enabled then
		return
	end

	self.targetFrame = self:CreateUnitFrame("target", "target", XFrames.db.profile.target, HEALTH_BAR_COLOR)
	if self.focusEnabled then
		self.focusFrame = self:CreateUnitFrame("focus", "focus", XFrames.db.profile.target.focus, FOCUS_HEALTH_BAR_COLOR)
	end
	self.eventFrame = self.eventFrame or CreateFrame("Frame")
	self:RegisterEvents()
	self:RefreshAll()
	XFrames:Info("Target shell enabled")
	if self.focusFrame then
		XFrames:Info("Focus shell enabled")
	end
end

XFrames:RegisterModule("Target", Target)
