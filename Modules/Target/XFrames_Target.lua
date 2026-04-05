local _, ns = ...

local XFrames = ns.XFrames
local Target = {}

local RAID_CLASS_COLORS = RAID_CLASS_COLORS

local CreateFrame = CreateFrame
local CanInspect = CanInspect
local ClearInspectPlayer = ClearInspectPlayer
local GetInspectSpecialization = GetInspectSpecialization
local GetSpecializationInfoByID = GetSpecializationInfoByID
local InCombatLockdown = InCombatLockdown
local NotifyInspect = NotifyInspect
local SetPortraitTexture = SetPortraitTexture
local UnitClass = UnitClass
local UnitCreatureType = UnitCreatureType
local UnitExists = UnitExists
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitGUID = UnitGUID
local UnitIsPlayer = UnitIsPlayer
local UnitLevel = UnitLevel
local UnitName = UnitName
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax

local HEALTH_BAR_COLOR = {r = 0.18, g = 0.62, b = 0.32}
local FOCUS_HEALTH_BAR_COLOR = {r = 0.18, g = 0.58, b = 0.34}
local TARGET_TARGET_HEALTH_BAR_COLOR = {r = 0.18, g = 0.55, b = 0.31}
local FOCUS_TARGET_HEALTH_BAR_COLOR = {r = 0.18, g = 0.52, b = 0.30}
local BACKDROP_COLOR = {0.08, 0.09, 0.11, 0.92}
local BORDER_COLOR = {0.24, 0.27, 0.31, 0.95}
local POWER_BAR_COLOR = {r = 0.24, g = 0.28, b = 0.36}
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
		edgeSize = 2,
		insets = {left = 1, right = 1, top = 1, bottom = 1},
	})
	frame:SetBackdropColor(unpack(PORTRAIT_BG_COLOR))
	frame:SetBackdropBorderColor(unpack(BORDER_COLOR))
	return frame
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
	local frame = CreateFrame("Button", frameName, UIParent, "SecureUnitButtonTemplate,BackdropTemplate")
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
	frame.accentFrame = XFrames:CreateAccentFrame(frame, 2, 3)
	frame:Hide()

	frame.portraitFrame = createBackdropFrame(nil, frame, 52, 52, "TOPLEFT", frame, "TOPLEFT", 6, -6)
	frame.portraitTexture = frame.portraitFrame:CreateTexture(nil, "ARTWORK")
	frame.portraitTexture:SetPoint("TOPLEFT", frame.portraitFrame, "TOPLEFT", 2, -2)
	frame.portraitTexture:SetSize(48, 48)
	frame.portraitTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	frame.specText = createText(frame, "OVERLAY", "GameFontHighlightSmall", 10, "TOP", frame.portraitFrame, "BOTTOM", 0, -4, "CENTER")

	frame.nameText = createText(frame, "OVERLAY", "GameFontNormalLarge", 13, "TOPLEFT", frame, "TOPLEFT", 64, -10, "LEFT")
	frame.levelText = createText(frame, "OVERLAY", "GameFontHighlight", 12, "TOPRIGHT", frame, "TOPRIGHT", -10, -10, "RIGHT")
	frame.statusText = createText(frame, "OVERLAY", "GameFontHighlightSmall", 10, "TOPLEFT", frame.nameText, "BOTTOMLEFT", 0, -2, "LEFT")

	frame.healthBar = createBar(frame, 14, "TOPLEFT", frame, "TOPLEFT", 64, -40)
	frame.healthBar:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
	frame.healthAccent = accent

	frame.powerBar = createBar(frame, 12, "TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, -6)
	frame.powerBar:SetPoint("RIGHT", frame, "RIGHT", -10, 0)

	XFrames:RegisterInteractiveUnitFrame(frame, unit, true)
	XFrames:RegisterMovableFrame(frame, config.position, frame.fallbackLabel)
	return frame
end

function Target:UpdatePortraitBorder(frame)
	if not frame.portraitFrame then
		return
	end

	local color = XFrames:GetUnitAccentColor(frame.unit)

	if color then
		frame.portraitFrame:SetBackdropBorderColor(color.r, color.g, color.b, 1)
	else
		frame.portraitFrame:SetBackdropBorderColor(unpack(BORDER_COLOR))
	end
end

function Target:UpdateFrameBorder(frame)
	local color = XFrames:GetUnitAccentColor(frame.unit)
	frame.accentFrame:SetBackdropBorderColor(color.r, color.g, color.b, 1)
end

function Target:CreateCompactUnitFrame(key, unit, config, accent)
	local frameName
	if key == "targettarget" then
		frameName = "XFramesTargetTargetFrame"
	else
		frameName = "XFramesFocusTargetFrame"
	end

	local frame = CreateFrame("Button", frameName, UIParent, "SecureUnitButtonTemplate,BackdropTemplate")
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
	frame.accentFrame = XFrames:CreateAccentFrame(frame, 2, 3)
	frame:Hide()

	frame.nameText = createText(frame, "OVERLAY", "GameFontNormal", 12, "TOPLEFT", frame, "TOPLEFT", 8, -8, "LEFT")
	frame.levelText = createText(frame, "OVERLAY", "GameFontHighlightSmall", 10, "TOPRIGHT", frame, "TOPRIGHT", -8, -9, "RIGHT")
	frame.statusText = nil

	frame.healthBar = createBar(frame, 10, "TOPLEFT", frame, "TOPLEFT", 8, -22)
	frame.healthBar:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
	frame.healthAccent = accent

	frame.powerBar = createBar(frame, 8, "TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, -4)
	frame.powerBar:SetPoint("RIGHT", frame, "RIGHT", -8, 0)

	XFrames:RegisterInteractiveUnitFrame(frame, unit, true)
	XFrames:RegisterMovableFrame(frame, config.position, frame.fallbackLabel)
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

function Target:GetInspectSpecName(unit)
	if not UnitExists(unit) or not UnitIsPlayer(unit) then
		return ""
	end

	local guid = UnitGUID(unit)
	return guid and self.inspectCache and self.inspectCache[guid] or ""
end

function Target:UpdateSpec(frame)
	if not frame.specText then
		return
	end

	frame.specText:SetText(self:GetInspectSpecName(frame.unit))
end

function Target:QueueInspect(unit)
	if not NotifyInspect or not CanInspect or not UnitExists(unit) or not UnitIsPlayer(unit) then
		return
	end

	local guid = UnitGUID(unit)
	if not guid then
		return
	end

	self.inspectCache = self.inspectCache or {}
	self.inspectQueue = self.inspectQueue or {}
	self.inspectQueued = self.inspectQueued or {}

	if self.inspectCache[guid] or self.inspectPendingGUID == guid or self.inspectQueued[guid] then
		return
	end

	self.inspectQueue[#self.inspectQueue + 1] = {guid = guid, unit = unit}
	self.inspectQueued[guid] = true
	self:ProcessInspectQueue()
end

function Target:ProcessInspectQueue()
	if self.inspectPendingGUID or (InCombatLockdown and InCombatLockdown()) then
		return
	end

	while self.inspectQueue and #self.inspectQueue > 0 do
		local item = table.remove(self.inspectQueue, 1)
		self.inspectQueued[item.guid] = nil

		if UnitExists(item.unit) and UnitGUID(item.unit) == item.guid and UnitIsPlayer(item.unit) and CanInspect(item.unit, false) then
			NotifyInspect(item.unit)
			self.inspectPendingGUID = item.guid
			return
		end
	end
end

function Target:HandleInspectReady(inspectGUID)
	if not inspectGUID or not GetInspectSpecialization then
		return
	end

	for _, unit in ipairs({"target", "focus"}) do
		if UnitExists(unit) and UnitGUID(unit) == inspectGUID then
			local specID = GetInspectSpecialization(unit)
			if specID and specID > 0 and GetSpecializationInfoByID then
				local _, name = GetSpecializationInfoByID(specID)
				if name then
					self.inspectCache = self.inspectCache or {}
					self.inspectCache[inspectGUID] = name
				end
			end
		end
	end

	if ClearInspectPlayer then
		ClearInspectPlayer()
	end

	if self.inspectPendingGUID == inspectGUID then
		self.inspectPendingGUID = nil
	end

	self:RefreshFrame(self.targetFrame)
	self:RefreshFrame(self.focusFrame)
	self:ProcessInspectQueue()
end

function Target:UpdateLevel(frame)
	if not UnitExists(frame.unit) then
		frame.levelText:SetText("")
		return
	end

	XFrames:SetValueText(frame.levelText, UnitLevel(frame.unit))
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
		self:UpdatePortraitBorder(frame)
		return
	end

	SetPortraitTexture(frame.portraitTexture, frame.unit)
	self:UpdatePortraitBorder(frame)
end

function Target:UpdateHealth(frame)
	local bar = frame.healthBar
	local accent = frame.healthAccent or HEALTH_BAR_COLOR

	if not UnitExists(frame.unit) then
		bar:SetStatusBarColor(accent.r, accent.g, accent.b)
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(0)
		bar.valueText:SetText("")
		return
	end

	local value = UnitHealth(frame.unit)
	local maxValue = UnitHealthMax(frame.unit)

	bar:SetStatusBarColor(accent.r, accent.g, accent.b)
	XFrames:SetBarValues(bar, value, maxValue)
end

function Target:UpdatePower(frame)
	local bar = frame.powerBar
	local _, color = XFrames:GetUnitPowerPresentation(frame.unit, frame.isCompact)

	if not UnitExists(frame.unit) then
		bar:SetStatusBarColor(color.r, color.g, color.b)
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(0)
		bar.valueText:SetText("")
		return
	end

	local value = UnitPower(frame.unit)
	local maxValue = UnitPowerMax(frame.unit)

	bar:SetStatusBarColor(color.r, color.g, color.b)
	XFrames:SetBarValues(bar, value, maxValue)
end

function Target:RefreshFrame(frame)
	if not frame then
		return
	end

	if not UnitExists(frame.unit) then
		if XFrames:IsFramesUnlocked() then
			frame:Show()
			self:UpdateFrameBorder(frame)
			self:UpdateName(frame)
			self:UpdateLevel(frame)
			self:UpdateStatus(frame)
			self:UpdateSpec(frame)
			self:UpdatePortrait(frame)
			self:UpdateHealth(frame)
			self:UpdatePower(frame)
		end
		return
	end

	if XFrames:IsFramesUnlocked() then
		frame:Show()
	end
	self:UpdateFrameBorder(frame)
	self:UpdateName(frame)
	self:UpdateLevel(frame)
	self:UpdateStatus(frame)
	self:UpdateSpec(frame)
	self:UpdatePortrait(frame)
	self:UpdateHealth(frame)
	self:UpdatePower(frame)

	if frame.specText then
		self:QueueInspect(frame.unit)
	end
end

function Target:RefreshAll()
	self:RefreshFrame(self.targetFrame)
	self:RefreshFrame(self.focusFrame)
	self:RefreshFrame(self.targetTargetFrame)
	self:RefreshFrame(self.focusTargetFrame)
end

function Target:OnEvent(event, unit)
	if event == "INSPECT_READY" then
		self:HandleInspectReady(unit)
		return
	end

	if event == "PLAYER_REGEN_ENABLED" then
		self:ProcessInspectQueue()
		return
	end

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
	frame:RegisterEvent("INSPECT_READY")
	frame:RegisterEvent("PLAYER_TARGET_CHANGED")
	frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	frame:RegisterUnitEvent("UNIT_TARGET", "target", "focus")
	frame:RegisterUnitEvent("UNIT_HEALTH", "target", "focus", "targettarget", "focustarget")
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", "target", "focus", "targettarget", "focustarget")
	frame:RegisterUnitEvent("UNIT_LEVEL", "target", "focus", "targettarget", "focustarget")
	frame:RegisterUnitEvent("UNIT_NAME_UPDATE", "target", "focus", "targettarget", "focustarget")
	frame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "target", "focus", "targettarget", "focustarget")
	frame:RegisterUnitEvent("UNIT_POWER_UPDATE", "target", "focus", "targettarget", "focustarget")
	frame:RegisterUnitEvent("UNIT_MAXPOWER", "target", "focus", "targettarget", "focustarget")
	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", "target", "focus", "targettarget", "focustarget")
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

function Target:ForEachFrame(callback)
	if self.targetFrame then
		callback(self.targetFrame)
	end
	if self.focusFrame then
		callback(self.focusFrame)
	end
	if self.targetTargetFrame then
		callback(self.targetTargetFrame)
	end
	if self.focusTargetFrame then
		callback(self.focusTargetFrame)
	end
end

XFrames:RegisterModule("Target", Target)
