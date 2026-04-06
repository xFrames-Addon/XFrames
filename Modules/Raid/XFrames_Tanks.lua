local _, ns = ...

local XFrames = ns.XFrames
local Tanks = {}

local RAID_CLASS_COLORS = RAID_CLASS_COLORS

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitLevel = UnitLevel
local UnitName = UnitName
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax

local HEALTH_BAR_COLOR = {r = 0.18, g = 0.62, b = 0.32}
local BACKDROP_COLOR = {0.08, 0.09, 0.11, 0.92}
local BORDER_COLOR = {0.24, 0.27, 0.31, 0.95}
local POWER_BAR_COLOR = {r = 0.24, g = 0.28, b = 0.36}
local PORTRAIT_BG_COLOR = {0.10, 0.11, 0.14, 0.98}
local SECONDARY_TEXT_COLOR = {0.72, 0.77, 0.84}
local DEMO_MEMBERS = {
	{
		name = "Tankard",
		className = "Warrior",
		classToken = "WARRIOR",
		level = 80,
		health = 920000,
		healthMax = 1000000,
		power = 35,
		powerMax = 100,
		powerColor = {r = 0.78, g = 0.24, b = 0.18},
		target = {
			name = "Ogre Brute",
			level = 80,
			health = 540000,
			healthMax = 750000,
			power = 80,
			powerMax = 100,
			powerColor = POWER_BAR_COLOR,
		},
	},
	{
		name = "Bulwark",
		className = "Paladin",
		classToken = "PALADIN",
		level = 80,
		health = 860000,
		healthMax = 930000,
		power = 185000,
		powerMax = 210000,
		powerColor = {r = 0.20, g = 0.44, b = 0.86},
		target = {
			name = "Void Hound",
			level = 80,
			health = 410000,
			healthMax = 610000,
			power = 0,
			powerMax = 100,
			powerColor = POWER_BAR_COLOR,
		},
	},
}

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
	frame:SetBackdropColor(unpack(BACKDROP_COLOR))
	frame:SetBackdropBorderColor(unpack(BORDER_COLOR))
	return frame
end

local function createBar(parent, height, anchorPoint, relativeTo, relativePoint, x, y, rightInset)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetHeight(height)
	bar:SetPoint(anchorPoint, relativeTo, relativePoint, x, y)
	bar:SetPoint("RIGHT", parent, "RIGHT", -(rightInset or 10), 0)
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)

	bar.bg = bar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetAllPoints()
	bar.bg:SetColorTexture(0.12, 0.13, 0.16, 0.95)

	bar.valueText = createText(bar, "OVERLAY", "GameFontHighlightSmall", 11, "RIGHT", bar, "RIGHT", -4, 0, "RIGHT")
	bar.valueText:SetText("")
	return bar
end

local function getClassColor(unit, demoData)
	local classToken
	if demoData then
		classToken = demoData.classToken
	else
		local _, liveClassToken = UnitClass(unit)
		classToken = liveClassToken
	end

	local classColor = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
	if classColor then
		return classColor
	end

	return {r = BORDER_COLOR[1], g = BORDER_COLOR[2], b = BORDER_COLOR[3]}
end

local function getLiveTankUnits()
	local units = {}
	for index = 1, 40 do
		local unit = "raid" .. index
		if UnitExists(unit) and UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) == "TANK" then
			units[#units + 1] = unit
		end
	end
	return units
end

function Tanks:IsDemoModeActive()
	if not XFrames:IsTankFramesEnabled() then
		return false
	end

	if not XFrames:IsFramesUnlocked() then
		return false
	end

	return #getLiveTankUnits() == 0
end

function Tanks:GetDemoData(index)
	if not self:IsDemoModeActive() then
		return nil
	end

	local template = DEMO_MEMBERS[index]
	if not template then
		return nil
	end

	local member = {}
	for key, value in pairs(template) do
		if type(value) == "table" then
			member[key] = {}
			for nestedKey, nestedValue in pairs(value) do
				member[key][nestedKey] = nestedValue
			end
		else
			member[key] = value
		end
	end

	return member
end

function Tanks:GetAssignedTankUnits()
	return getLiveTankUnits()
end

function Tanks:CreateAnchorFrame()
	if self.anchorFrame then
		return self.anchorFrame
	end

	local config = XFrames.db.profile.raid.tanks
	local frame = CreateFrame("Frame", "XFramesTankAnchor", UIParent)
	frame:SetScale(config.scale or 1)
	frame:SetFrameStrata("MEDIUM")
	frame:SetFrameLevel(24)
	frame:Hide()

	self.anchorFrame = frame
	XFrames:RegisterMovableFrame(frame, config.position, "Tanks")
	return frame
end

function Tanks:LayoutFrames()
	local anchor = self:CreateAnchorFrame()
	local config = XFrames.db.profile.raid.tanks
	local targetConfig = config.targets or {}
	local maxUnits = config.maxUnits or 4
	local spacing = config.spacing or 10
	local targetsEnabled = XFrames:IsTankTargetsEnabled()
	local totalWidth = config.width

	if targetsEnabled then
		totalWidth = math.max(totalWidth, config.width + (targetConfig.xOffset or 12) + (targetConfig.width or 180))
	end

	local totalHeight = (config.height * maxUnits) + (spacing * math.max(maxUnits - 1, 0))
	anchor:SetSize(totalWidth, totalHeight)

	for index = 1, maxUnits do
		local frame = self:CreateUnitFrame(index)
		frame:SetSize(config.width, config.height)
		frame:SetScale(config.scale or 1)
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, -((index - 1) * (config.height + spacing)))

		local targetFrame = frame.targetFrame
		targetFrame:SetSize(targetConfig.width or 180, targetConfig.height or 56)
		targetFrame:SetScale(targetConfig.scale or 0.9)
		targetFrame:ClearAllPoints()
		targetFrame:SetPoint("LEFT", frame, "RIGHT", targetConfig.xOffset or 12, 0)
	end
end

function Tanks:CreateTargetFrame(parentFrame, index)
	local config = XFrames.db.profile.raid.tanks.targets or {}
	local frame = CreateFrame("Button", "XFramesTankTargetFrame" .. index, parentFrame:GetParent(), "SecureUnitButtonTemplate,BackdropTemplate")
	frame:SetSize(config.width or 180, config.height or 56)
	frame:SetFrameStrata("MEDIUM")
	frame:SetFrameLevel(parentFrame:GetFrameLevel() + 1)
	frame.fallbackLabel = "Target"
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
		insets = {left = 1, right = 1, top = 1, bottom = 1},
	})
	frame:SetBackdropColor(unpack(BACKDROP_COLOR))
	frame:SetBackdropBorderColor(unpack(BORDER_COLOR))
	frame.accentFrame = XFrames:CreateAccentFrame(frame, 2, 3)

	frame.nameText = createText(frame, "OVERLAY", "GameFontNormalSmall", 11, "TOPLEFT", frame, "TOPLEFT", 8, -8, "LEFT")
	frame.nameText:SetWidth((config.width or 180) - 16)
	frame.nameText:SetWordWrap(false)
	frame.statusText = createText(frame, "OVERLAY", "GameFontHighlightSmall", 9, "TOPLEFT", frame.nameText, "BOTTOMLEFT", 0, -2, "LEFT")
	frame.statusText:SetWidth((config.width or 180) - 16)
	frame.statusText:SetWordWrap(false)
	frame.statusText:SetTextColor(unpack(SECONDARY_TEXT_COLOR))
	frame.healthBar = createBar(frame, 10, "TOPLEFT", frame, "TOPLEFT", 8, -26, 8)
	frame.powerBar = createBar(frame, 6, "TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, -4, 8)

	XFrames:RegisterInteractiveUnitFrame(frame, nil, false)

	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function()
		if not XFrames:IsFramesUnlocked() then
			return
		end
		if InCombatLockdown and InCombatLockdown() then
			return
		end

		self.anchorFrame:StartMoving()
	end)
	frame:SetScript("OnDragStop", function()
		self.anchorFrame:StopMovingOrSizing()
		XFrames:SaveFramePosition(self.anchorFrame)
	end)

	return frame
end

function Tanks:CreateUnitFrame(index)
	self.frames = self.frames or {}
	if self.frames[index] then
		return self.frames[index]
	end

	local config = XFrames.db.profile.raid.tanks
	local frame = CreateFrame("Button", "XFramesTankFrame" .. index, self:CreateAnchorFrame(), "SecureUnitButtonTemplate,BackdropTemplate")
	frame:SetSize(config.width, config.height)
	frame:SetFrameStrata("MEDIUM")
	frame:SetFrameLevel(self.anchorFrame:GetFrameLevel() + index)
	frame.fallbackLabel = "Tank " .. index
	frame.demoIndex = index
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
		insets = {left = 1, right = 1, top = 1, bottom = 1},
	})
	frame:SetBackdropColor(unpack(BACKDROP_COLOR))
	frame:SetBackdropBorderColor(unpack(BORDER_COLOR))
	frame.accentFrame = XFrames:CreateAccentFrame(frame, 2, 3)

	frame.portraitFrame = createBackdropFrame(nil, frame, 52, 52, "TOPLEFT", frame, "TOPLEFT", 6, -6)
	frame.portraitFrame:SetBackdropColor(unpack(PORTRAIT_BG_COLOR))
	frame.portraitTexture = frame.portraitFrame:CreateTexture(nil, "ARTWORK")
	frame.portraitTexture:SetPoint("TOPLEFT", frame.portraitFrame, "TOPLEFT", 2, -2)
	frame.portraitTexture:SetSize(48, 48)
	frame.portraitTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	frame.nameText = createText(frame, "OVERLAY", "GameFontNormalLarge", 13, "TOPLEFT", frame, "TOPLEFT", 64, -10, "LEFT")
	frame.levelText = createText(frame, "OVERLAY", "GameFontHighlight", 12, "TOPRIGHT", frame, "TOPRIGHT", -10, -10, "RIGHT")
	frame.statusText = createText(frame, "OVERLAY", "GameFontHighlightSmall", 10, "TOPLEFT", frame.nameText, "BOTTOMLEFT", 0, -2, "LEFT")
	frame.statusText:SetWidth(config.width - 148)
	frame.statusText:SetWordWrap(false)
	frame.healthBar = createBar(frame, 14, "TOPLEFT", frame, "TOPLEFT", 64, -40)
	frame.powerBar = createBar(frame, 12, "TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, -6)

	frame.targetFrame = self:CreateTargetFrame(frame, index)

	self.frames[index] = frame

	XFrames:RegisterInteractiveUnitFrame(frame, nil, false)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function()
		if not XFrames:IsFramesUnlocked() then
			return
		end
		if InCombatLockdown and InCombatLockdown() then
			return
		end

		self.anchorFrame:StartMoving()
	end)
	frame:SetScript("OnDragStop", function()
		self.anchorFrame:StopMovingOrSizing()
		XFrames:SaveFramePosition(self.anchorFrame)
	end)

	return frame
end

function Tanks:UpdateMainFrame(frame, unit, demoData)
	local displayName
	local className
	local level
	local health
	local healthMax
	local power
	local powerMax
	local powerColor

	if demoData then
		displayName = demoData.name
		className = demoData.className or "Tank"
		level = demoData.level or 80
		health = demoData.health or 0
		healthMax = demoData.healthMax or 1
		power = demoData.power or 0
		powerMax = demoData.powerMax or 1
		powerColor = demoData.powerColor or POWER_BAR_COLOR
		if demoData.classToken then
			XFrames:ApplyClassIcon(frame.portraitTexture, demoData.classToken)
		else
			frame.portraitTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
		end
	else
		displayName = UnitExists(unit) and UnitName(unit) or frame.fallbackLabel
		className = UnitExists(unit) and (UnitClass(unit)) or "Tank"
		level = UnitExists(unit) and UnitLevel(unit) or nil
		health = UnitExists(unit) and UnitHealth(unit) or 0
		healthMax = UnitExists(unit) and UnitHealthMax(unit) or 1
		power = UnitExists(unit) and UnitPower(unit) or 0
		powerMax = UnitExists(unit) and UnitPowerMax(unit) or 1
		local _, livePowerColor = XFrames:GetUnitPowerPresentation(unit, false)
		powerColor = livePowerColor
		XFrames:ApplyUnitPortrait(frame.portraitTexture, unit)
	end

	local classColor = getClassColor(unit, demoData)
	frame.nameText:SetText(displayName or frame.fallbackLabel)
	frame.nameText:SetTextColor(classColor.r, classColor.g, classColor.b)
	frame.statusText:SetText(className or "Tank")
	frame.statusText:SetTextColor(unpack(SECONDARY_TEXT_COLOR))
	frame.levelText:SetText(level and tostring(level) or "")
	frame.accentFrame:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b, 1)

	XFrames:SetBarValues(frame.healthBar, health, healthMax)
	frame.healthBar:SetStatusBarColor(HEALTH_BAR_COLOR.r, HEALTH_BAR_COLOR.g, HEALTH_BAR_COLOR.b)
	frame.powerBar:SetStatusBarColor(powerColor.r, powerColor.g, powerColor.b)
	XFrames:SetBarValues(frame.powerBar, power, powerMax)

	if UnitExists(unit) and UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then
		frame:SetAlpha(0.6)
	else
		frame:SetAlpha(1)
	end
end

function Tanks:UpdateTargetFrame(frame, unit, demoTarget)
	local targetFrame = frame.targetFrame
	local targetUnit = unit and (unit .. "target") or nil
	local activeDemo = demoTarget ~= nil
	local shouldShow = XFrames:IsTankTargetsEnabled() and (activeDemo or (targetUnit and UnitExists(targetUnit)) or XFrames:IsFramesUnlocked())

	if not XFrames:IsTankTargetsEnabled() then
		targetFrame:Hide()
		return
	end

	if activeDemo then
		targetFrame.nameText:SetText(demoTarget.name or targetFrame.fallbackLabel)
		targetFrame.statusText:SetText("Target")
		targetFrame.statusText:SetTextColor(unpack(SECONDARY_TEXT_COLOR))
		targetFrame.accentFrame:SetBackdropBorderColor(0.78, 0.25, 0.22, 1)
		targetFrame.healthBar:SetStatusBarColor(HEALTH_BAR_COLOR.r, HEALTH_BAR_COLOR.g, HEALTH_BAR_COLOR.b)
		XFrames:SetBarValues(targetFrame.healthBar, demoTarget.health or 0, demoTarget.healthMax or 1)
		targetFrame.powerBar:SetStatusBarColor((demoTarget.powerColor or POWER_BAR_COLOR).r, (demoTarget.powerColor or POWER_BAR_COLOR).g, (demoTarget.powerColor or POWER_BAR_COLOR).b)
		XFrames:SetBarValues(targetFrame.powerBar, demoTarget.power or 0, demoTarget.powerMax or 1)
		XFrames:AssignInteractiveUnit(targetFrame, nil)
		targetFrame:Show()
		return
	end

	if not shouldShow then
		targetFrame:Hide()
		return
	end

	if not XFrames:AssignInteractiveUnit(targetFrame, targetUnit) and targetUnit then
		self.pendingAssignmentRefresh = true
	end

	if targetUnit and UnitExists(targetUnit) then
		targetFrame.nameText:SetText(UnitName(targetUnit) or targetFrame.fallbackLabel)
		targetFrame.statusText:SetText("Target")
		targetFrame.statusText:SetTextColor(unpack(SECONDARY_TEXT_COLOR))
		targetFrame.accentFrame:SetBackdropBorderColor(0.78, 0.25, 0.22, 1)
		targetFrame.healthBar:SetStatusBarColor(HEALTH_BAR_COLOR.r, HEALTH_BAR_COLOR.g, HEALTH_BAR_COLOR.b)
		XFrames:SetBarValues(targetFrame.healthBar, UnitHealth(targetUnit), UnitHealthMax(targetUnit))
		local _, color = XFrames:GetUnitPowerPresentation(targetUnit, true)
		targetFrame.powerBar:SetStatusBarColor(color.r, color.g, color.b)
		XFrames:SetBarValues(targetFrame.powerBar, UnitPower(targetUnit), UnitPowerMax(targetUnit))
		targetFrame:SetAlpha(UnitIsDeadOrGhost and UnitIsDeadOrGhost(targetUnit) and 0.6 or 1)
	else
		targetFrame.nameText:SetText(targetFrame.fallbackLabel)
		targetFrame.statusText:SetText("")
		targetFrame.healthBar:SetStatusBarColor(HEALTH_BAR_COLOR.r, HEALTH_BAR_COLOR.g, HEALTH_BAR_COLOR.b)
		targetFrame.healthBar:SetMinMaxValues(0, 1)
		targetFrame.healthBar:SetValue(0)
		targetFrame.healthBar.valueText:SetText("")
		targetFrame.powerBar:SetStatusBarColor(POWER_BAR_COLOR.r, POWER_BAR_COLOR.g, POWER_BAR_COLOR.b)
		targetFrame.powerBar:SetMinMaxValues(0, 1)
		targetFrame.powerBar:SetValue(0)
		targetFrame.powerBar.valueText:SetText("")
		targetFrame:SetAlpha(1)
	end

	targetFrame:Show()
end

function Tanks:RefreshFrame(index, unit)
	local frame = self:CreateUnitFrame(index)
	local demoData = self:GetDemoData(index)
	local targetDemo = demoData and demoData.target or nil

	if demoData then
		XFrames:AssignInteractiveUnit(frame, nil)
		self:UpdateMainFrame(frame, nil, demoData)
		self:UpdateTargetFrame(frame, nil, targetDemo)
		frame:Show()
		return
	end

	if unit then
		if not XFrames:AssignInteractiveUnit(frame, unit) then
			self.pendingAssignmentRefresh = true
		end
		self:UpdateMainFrame(frame, unit, nil)
		self:UpdateTargetFrame(frame, unit, nil)
		frame:Show()
		return
	end

	-- Outside raids, unlocked mode shows a lightweight placeholder for layout.
	if XFrames:IsFramesUnlocked() and XFrames:IsTankFramesEnabled() then
		XFrames:AssignInteractiveUnit(frame, nil)
		frame.nameText:SetText(frame.fallbackLabel)
		frame.nameText:SetTextColor(1, 1, 1)
		frame.statusText:SetText("Tank")
		frame.statusText:SetTextColor(unpack(SECONDARY_TEXT_COLOR))
		frame.levelText:SetText("")
		frame.accentFrame:SetBackdropBorderColor(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], 1)
		frame.healthBar:SetStatusBarColor(HEALTH_BAR_COLOR.r, HEALTH_BAR_COLOR.g, HEALTH_BAR_COLOR.b)
		frame.healthBar:SetMinMaxValues(0, 1)
		frame.healthBar:SetValue(0)
		frame.healthBar.valueText:SetText("")
		frame.powerBar:SetStatusBarColor(POWER_BAR_COLOR.r, POWER_BAR_COLOR.g, POWER_BAR_COLOR.b)
		frame.powerBar:SetMinMaxValues(0, 1)
		frame.powerBar:SetValue(0)
		frame.powerBar.valueText:SetText("")
		frame:SetAlpha(1)
		self:UpdateTargetFrame(frame, nil, nil)
		frame:Show()
		return
	end

	frame:Hide()
	frame.targetFrame:Hide()
end

function Tanks:RefreshAnchor()
	if not self.anchorFrame then
		return
	end

	if not XFrames:IsTankFramesEnabled() then
		self.anchorFrame:Hide()
		return
	end

	if XFrames:IsFramesUnlocked() or self:IsDemoModeActive() then
		self.anchorFrame:Show()
		return
	end

	if #self:GetAssignedTankUnits() > 0 then
		self.anchorFrame:Show()
		return
	end

	self.anchorFrame:Hide()
end

function Tanks:RefreshAll()
	self:LayoutFrames()

	local maxUnits = XFrames.db.profile.raid.tanks.maxUnits or 4
	if not XFrames:IsTankFramesEnabled() then
		for index = 1, maxUnits do
			local frame = self.frames and self.frames[index]
			if frame then
				frame:Hide()
				if frame.targetFrame then
					frame.targetFrame:Hide()
				end
			end
		end
		self:RefreshAnchor()
		return
	end

	local assignedUnits = self:GetAssignedTankUnits()
	for index = 1, maxUnits do
		self:RefreshFrame(index, assignedUnits[index])
	end

	self:RefreshAnchor()
end

function Tanks:OnEvent(eventName)
	if eventName == "PLAYER_REGEN_ENABLED" then
		self.pendingAssignmentRefresh = nil
	end
	self:RefreshAll()
end

function Tanks:RegisterEvents()
	self.eventFrame = self.eventFrame or CreateFrame("Frame")
	local frame = self.eventFrame
	local units = {}
	local targetUnits = {}

	for index = 1, 40 do
		units[#units + 1] = "raid" .. index
		targetUnits[#targetUnits + 1] = "raid" .. index .. "target"
	end

	frame:RegisterEvent("GROUP_ROSTER_UPDATE")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	frame:RegisterUnitEvent("UNIT_NAME_UPDATE", unpack(units))
	frame:RegisterUnitEvent("UNIT_HEALTH", unpack(units))
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", unpack(units))
	frame:RegisterUnitEvent("UNIT_POWER_UPDATE", unpack(units))
	frame:RegisterUnitEvent("UNIT_MAXPOWER", unpack(units))
	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", unpack(units))
	frame:RegisterUnitEvent("UNIT_FLAGS", unpack(units))
	frame:RegisterUnitEvent("UNIT_LEVEL", unpack(units))
	frame:RegisterUnitEvent("UNIT_TARGET", unpack(units))
	frame:RegisterUnitEvent("UNIT_NAME_UPDATE", unpack(targetUnits))
	frame:RegisterUnitEvent("UNIT_HEALTH", unpack(targetUnits))
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", unpack(targetUnits))
	frame:RegisterUnitEvent("UNIT_POWER_UPDATE", unpack(targetUnits))
	frame:RegisterUnitEvent("UNIT_MAXPOWER", unpack(targetUnits))
	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", unpack(targetUnits))
	frame:RegisterUnitEvent("UNIT_FLAGS", unpack(targetUnits))
	frame:SetScript("OnEvent", function(_, eventName, ...)
		XFrames:SafeCall("module RaidTanks:OnEvent", self.OnEvent, self, eventName, ...)
	end)
end

function Tanks:Initialize()
	self.enabled = XFrames:IsTankFramesEnabled()
end

function Tanks:Enable()
	if not self.enabled then
		return
	end

	self:CreateAnchorFrame()
	self:LayoutFrames()
	self:RegisterEvents()
	self:RefreshAll()
	XFrames:Info("Tank frames enabled")
end

function Tanks:ForEachFrame(callback)
	if self.anchorFrame then
		callback(self.anchorFrame)
	end

	local maxUnits = XFrames.db.profile.raid.tanks.maxUnits or 4
	for index = 1, maxUnits do
		local frame = self.frames and self.frames[index]
		if frame then
			callback(frame)
			if frame.targetFrame then
				callback(frame.targetFrame)
			end
		end
	end
end

XFrames:RegisterModule("RaidTanks", Tanks)
