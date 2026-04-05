local _, ns = ...

local XFrames = ns.XFrames
local Target = {}

local RAID_CLASS_COLORS = RAID_CLASS_COLORS

local CreateFrame = CreateFrame
local SetPortraitTexture = SetPortraitTexture
local UnitClass = UnitClass
local UnitCreatureType = UnitCreatureType
local UnitExists = UnitExists
local UnitIsPlayer = UnitIsPlayer
local UnitName = UnitName

local HEALTH_BAR_COLOR = {r = 0.33, g = 0.24, b = 0.24}
local FOCUS_HEALTH_BAR_COLOR = {r = 0.33, g = 0.30, b = 0.22}
local TARGET_TARGET_HEALTH_BAR_COLOR = {r = 0.31, g = 0.24, b = 0.24}
local FOCUS_TARGET_HEALTH_BAR_COLOR = {r = 0.31, g = 0.28, b = 0.22}
local BACKDROP_COLOR = {0.08, 0.09, 0.11, 0.92}
local BORDER_COLOR = {0.24, 0.27, 0.31, 0.95}
local POWER_BAR_COLOR = {r = 0.24, g = 0.28, b = 0.36}
local PLACEHOLDER_BAR_VALUE = 0.62
local PLACEHOLDER_VALUE_TEXT = "Restricted"

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
	bar.percentText:Hide()

	return bar
end

local function getStatusText(unit, fallbackLabel)
	if not UnitExists(unit) then
		return fallbackLabel
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
	frame.statusText = createText(frame, "OVERLAY", "GameFontHighlightSmall", 10, "TOPLEFT", frame.nameText, "BOTTOMLEFT", 0, -2, "LEFT")

	frame.healthBar = createBar(frame, 14, "TOPLEFT", frame, "TOPLEFT", 64, -40)
	frame.healthBar:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
	frame.healthBar.labelText:SetText("Health")
	frame.healthAccent = accent

	frame.powerBar = createBar(frame, 12, "TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, -6)
	frame.powerBar:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
	frame.powerBar.labelText:SetText("Power")

	return frame
end

function Target:CreateCompactUnitFrame(key, unit, config, accent)
	local frameName
	if key == "targettarget" then
		frameName = "XFramesTargetTargetFrame"
	else
		frameName = "XFramesFocusTargetFrame"
	end

	local frame = CreateFrame("Frame", frameName, UIParent, "BackdropTemplate")
	frame.unit = unit
	frame.unitKey = key
	frame.fallbackLabel = key == "targettarget" and "ToT" or "FoT"
	frame.isCompact = true
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

	frame.nameText = createText(frame, "OVERLAY", "GameFontNormal", 12, "TOPLEFT", frame, "TOPLEFT", 8, -8, "LEFT")
	frame.levelText = createText(frame, "OVERLAY", "GameFontHighlightSmall", 10, "TOPRIGHT", frame, "TOPRIGHT", -8, -9, "RIGHT")
	frame.statusText = nil

	frame.healthBar = createBar(frame, 10, "TOPLEFT", frame, "TOPLEFT", 8, -22)
	frame.healthBar:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
	frame.healthBar.labelText:SetText("HP")
	frame.healthAccent = accent

	frame.powerBar = createBar(frame, 8, "TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, -4)
	frame.powerBar:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
	frame.powerBar.labelText:SetText("PW")

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
	frame.levelText:SetText("")
end

function Target:UpdateStatus(frame)
	if frame.statusText then
		frame.statusText:SetText(getStatusText(frame.unit, frame.fallbackLabel))
	end
end

function Target:UpdatePortrait(frame)
	if not frame.portraitTexture then
		return
	end

	if not UnitExists(frame.unit) then
		frame.portraitTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
		return
	end

	SetPortraitTexture(frame.portraitTexture, frame.unit)
end

function Target:UpdateHealth(frame)
	local bar = frame.healthBar
	local accent = frame.healthAccent or HEALTH_BAR_COLOR

	bar:SetStatusBarColor(accent.r, accent.g, accent.b)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(PLACEHOLDER_BAR_VALUE)
	if frame.isCompact then
		bar.labelText:SetText("HP")
	else
		bar.labelText:SetText("Health")
	end
	bar.valueText:SetText(PLACEHOLDER_VALUE_TEXT)
end

function Target:UpdatePower(frame)
	local bar = frame.powerBar

	if frame.isCompact then
		bar.labelText:SetText("PW")
	else
		bar.labelText:SetText("Power")
	end
	bar:SetStatusBarColor(POWER_BAR_COLOR.r, POWER_BAR_COLOR.g, POWER_BAR_COLOR.b)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(PLACEHOLDER_BAR_VALUE)
	bar.valueText:SetText(PLACEHOLDER_VALUE_TEXT)
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
	self:RefreshFrame(self.targetTargetFrame)
	self:RefreshFrame(self.focusTargetFrame)
end

function Target:OnEvent(event, unit)
	if event == "PLAYER_TARGET_CHANGED" then
		self:RefreshFrame(self.targetFrame)
		self:RefreshFrame(self.targetTargetFrame)
		return
	end

	if event == "PLAYER_FOCUS_CHANGED" then
		self:RefreshFrame(self.focusFrame)
		self:RefreshFrame(self.focusTargetFrame)
		return
	end

	if event == "UNIT_TARGET" then
		if unit == "target" then
			self:RefreshFrame(self.targetTargetFrame)
			return
		end
		if unit == "focus" then
			self:RefreshFrame(self.focusTargetFrame)
			return
		end
	end

	if unit == "target" then
		self:RefreshFrame(self.targetFrame)
		return
	end

	if unit == "focus" then
		self:RefreshFrame(self.focusFrame)
		return
	end

	if unit == "targettarget" then
		self:RefreshFrame(self.targetTargetFrame)
		return
	end

	if unit == "focustarget" then
		self:RefreshFrame(self.focusTargetFrame)
		return
	end

	self:RefreshAll()
end

function Target:RegisterEvents()
	local frame = self.eventFrame
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("PLAYER_TARGET_CHANGED")
	frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
	frame:RegisterUnitEvent("UNIT_TARGET", "target", "focus")
	frame:RegisterUnitEvent("UNIT_NAME_UPDATE", "target", "focus", "targettarget", "focustarget")
	frame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "target", "focus", "targettarget", "focustarget")
	frame:SetScript("OnEvent", function(_, event, ...)
		XFrames:SafeCall("module Target:OnEvent", self.OnEvent, self, event, ...)
	end)
end

function Target:Initialize()
	self.enabled = XFrames.db.profile.target.enabled
	self.focusEnabled = XFrames.db.profile.target.focus.enabled
	self.targetTargetEnabled = XFrames.db.profile.target.targettarget.enabled
	self.focusTargetEnabled = XFrames.db.profile.target.focustarget.enabled
end

function Target:Enable()
	if not self.enabled then
		return
	end

	self.targetFrame = self:CreateUnitFrame("target", "target", XFrames.db.profile.target, HEALTH_BAR_COLOR)
	if self.focusEnabled then
		self.focusFrame = self:CreateUnitFrame("focus", "focus", XFrames.db.profile.target.focus, FOCUS_HEALTH_BAR_COLOR)
	end
	if self.targetTargetEnabled then
		self.targetTargetFrame = self:CreateCompactUnitFrame("targettarget", "targettarget", XFrames.db.profile.target.targettarget, TARGET_TARGET_HEALTH_BAR_COLOR)
	end
	if self.focusTargetEnabled then
		self.focusTargetFrame = self:CreateCompactUnitFrame("focustarget", "focustarget", XFrames.db.profile.target.focustarget, FOCUS_TARGET_HEALTH_BAR_COLOR)
	end
	self.eventFrame = self.eventFrame or CreateFrame("Frame")
	self:RegisterEvents()
	self:RefreshAll()
	XFrames:Info("Target shell enabled")
	if self.focusFrame then
		XFrames:Info("Focus shell enabled")
	end
	if self.targetTargetFrame then
		XFrames:Info("Target-of-target shell enabled")
	end
	if self.focusTargetFrame then
		XFrames:Info("Focus-target shell enabled")
	end
end

XFrames:RegisterModule("Target", Target)
