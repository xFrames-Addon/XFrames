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
local UnitName = UnitName
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax

local HEALTH_BAR_COLOR = {r = 0.18, g = 0.62, b = 0.32}
local BACKDROP_COLOR = {0.08, 0.09, 0.11, 0.92}
local BORDER_COLOR = {0.24, 0.27, 0.31, 0.95}
local SECONDARY_TEXT_COLOR = {0.72, 0.77, 0.84}
local ROLE_BG_COLOR = {0.12, 0.14, 0.18, 0.96}
local ROLE_ICON_TEXTURE = "Interface\\LFGFrame\\UI-LFG-ICON-ROLES"
local DEMO_MEMBERS = {
	{className = "Warrior", classToken = "WARRIOR", role = "TANK", name = "Tankard", health = 920000, healthMax = 1000000, power = 35, powerMax = 100, powerColor = {r = 0.78, g = 0.24, b = 0.18}, target = {name = "Brute", health = 540000, healthMax = 750000, power = 60, powerMax = 100, powerColor = {r = 0.24, g = 0.28, b = 0.36}}},
	{className = "Paladin", classToken = "PALADIN", role = "TANK", name = "Bulwark", health = 860000, healthMax = 930000, power = 185000, powerMax = 210000, powerColor = {r = 0.20, g = 0.44, b = 0.86}, target = {name = "Hound", health = 410000, healthMax = 610000, power = 0, powerMax = 100, powerColor = {r = 0.24, g = 0.28, b = 0.36}}},
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

local function createBar(parent, height, anchorPoint, relativeTo, relativePoint, x, y)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetHeight(height)
	bar:SetPoint(anchorPoint, relativeTo, relativePoint, x, y)
	bar:SetPoint("RIGHT", parent, "RIGHT", -3, 0)
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)

	bar.bg = bar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetAllPoints()
	bar.bg:SetColorTexture(0.12, 0.13, 0.16, 0.95)

	bar.valueText = createText(bar, "OVERLAY", "GameFontHighlightSmall", 8, "RIGHT", bar, "RIGHT", -2, 0, "RIGHT")
	bar.valueText:Hide()
	return bar
end

local function setRoleIcon(texture, role)
	if not texture then
		return false
	end

	if role == "TANK" then
		if texture.SetAtlas then
			texture:SetAtlas("UI-LFG-RoleIcon-Tank", false)
		else
			texture:SetTexture(ROLE_ICON_TEXTURE)
			texture:SetTexCoord(0, 19 / 64, 22 / 64, 41 / 64)
		end
		texture:SetVertexColor(1, 1, 1, 1)
		texture:Show()
		return true
	end

	texture:Hide()
	return false
end

local function abbreviateName(name)
	if type(name) ~= "string" or name == "" then
		return ""
	end

	local firstWord = name:match("^(%S+)") or name
	if #firstWord <= 6 then
		return firstWord
	end

	return firstWord:sub(1, 6)
end

local function getAccentColor(unit, demoData)
	if demoData and RAID_CLASS_COLORS and RAID_CLASS_COLORS[demoData.classToken] then
		return RAID_CLASS_COLORS[demoData.classToken]
	end

	if not UnitExists(unit) then
		return {r = BORDER_COLOR[1], g = BORDER_COLOR[2], b = BORDER_COLOR[3]}
	end

	local _, class = UnitClass(unit)
	local classColor = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
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
	if not XFrames:IsFramesUnlocked() then
		return false
	end

	if not XFrames:IsRaidFramesEnabled() or not XFrames:IsTankFramesEnabled() then
		return false
	end

	return #getLiveTankUnits() == 0
end

function Tanks:GetDemoData(index)
	if not self:IsDemoModeActive() then
		return nil
	end

	return DEMO_MEMBERS[index]
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
	frame:SetFrameStrata("MEDIUM")
	frame:SetFrameLevel(24)
	frame:Hide()

	self.anchorFrame = frame
	XFrames:RegisterMovableFrame(frame, config.position, "Tanks")
	self:ApplyLayout()
	return frame
end

function Tanks:ApplyLayout()
	if not self.anchorFrame then
		return
	end

	local config = XFrames.db.profile.raid.tanks
	local targetConfig = config.targets or {}
	local width = config.width or 96
	local height = config.height or 40
	local spacing = config.spacing or 6
	local targetsEnabled = XFrames:IsTankTargetsEnabled()
	local maxUnits = config.maxUnits or 4
	local totalWidth = width

	if targetsEnabled then
		totalWidth = width + (targetConfig.xOffset or 8) + (targetConfig.width or 96)
	end

	self.anchorFrame:SetSize(totalWidth, (height * maxUnits) + (spacing * math.max(maxUnits - 1, 0)))
	self.anchorFrame:SetScale(config.scale or 1)

	for index = 1, maxUnits do
		local frame = self:CreateUnitFrame(index)
		frame:SetSize(width, height)
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", self.anchorFrame, "TOPLEFT", 0, -((index - 1) * (height + spacing)))

		local targetFrame = frame.targetFrame
		targetFrame:SetSize(targetConfig.width or 96, targetConfig.height or 40)
		targetFrame:ClearAllPoints()
		targetFrame:SetPoint("LEFT", frame, "RIGHT", targetConfig.xOffset or 8, 0)
	end
end

function Tanks:CreateTargetFrame(parentFrame, index)
	local config = XFrames.db.profile.raid.tanks.targets or {}
	local frame = CreateFrame("Button", "XFramesTankTargetFrame" .. index, parentFrame:GetParent(), "SecureUnitButtonTemplate,BackdropTemplate")
	frame.fallbackLabel = "Target"
	frame:SetSize(config.width or 96, config.height or 40)
	frame:SetFrameStrata("MEDIUM")
	frame:SetFrameLevel(parentFrame:GetFrameLevel() + 1)
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
		insets = {left = 1, right = 1, top = 1, bottom = 1},
	})
	frame:SetBackdropColor(unpack(BACKDROP_COLOR))
	frame:SetBackdropBorderColor(unpack(BORDER_COLOR))
	frame.accentFrame = XFrames:CreateAccentFrame(frame, 2, 3)
	frame.nameText = createText(frame, "OVERLAY", "GameFontNormalSmall", 9, "TOPLEFT", frame, "TOPLEFT", 4, -4, "LEFT")
	frame.nameText:SetWidth((config.width or 96) - 8)
	frame.nameText:SetWordWrap(false)
	frame.statusText = createText(frame, "OVERLAY", "GameFontHighlightSmall", 7, "TOPLEFT", frame.nameText, "BOTTOMLEFT", 0, -1, "LEFT")
	frame.statusText:SetWidth((config.width or 96) - 8)
	frame.statusText:SetWordWrap(false)
	frame.statusText:SetTextColor(unpack(SECONDARY_TEXT_COLOR))
	frame.healthBar = createBar(frame, 8, "TOPLEFT", frame, "TOPLEFT", 4, -22)
	frame.powerBar = createBar(frame, 4, "TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, -4)
	frame:Hide()

	XFrames:RegisterInteractiveUnitFrame(frame, nil, false)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function()
		if not XFrames:IsFramesUnlocked() or (InCombatLockdown and InCombatLockdown()) then
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
	frame.unit = nil
	frame.demoIndex = index
	frame.fallbackLabel = "Tank " .. index
	frame:SetSize(config.width, config.height)
	frame:SetFrameStrata("MEDIUM")
	frame:SetFrameLevel(self.anchorFrame:GetFrameLevel() + index)
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
		insets = {left = 1, right = 1, top = 1, bottom = 1},
	})
	frame:SetBackdropColor(unpack(BACKDROP_COLOR))
	frame:SetBackdropBorderColor(unpack(BORDER_COLOR))
	frame.accentFrame = XFrames:CreateAccentFrame(frame, 2, 3)
	frame.nameText = createText(frame, "OVERLAY", "GameFontNormalSmall", 9, "TOPLEFT", frame, "TOPLEFT", 4, -4, "LEFT")
	frame.nameText:SetWidth((config.width or 96) - 26)
	frame.nameText:SetWordWrap(false)
	frame.roleFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	frame.roleFrame:SetSize(14, 14)
	frame.roleFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
	frame.roleFrame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
		insets = {left = 1, right = 1, top = 1, bottom = 1},
	})
	frame.roleFrame:SetBackdropColor(unpack(ROLE_BG_COLOR))
	frame.roleFrame:SetBackdropBorderColor(unpack(BORDER_COLOR))
	frame.roleIcon = frame.roleFrame:CreateTexture(nil, "OVERLAY")
	frame.roleIcon:SetSize(12, 12)
	frame.roleIcon:SetPoint("CENTER", frame.roleFrame, "CENTER")
	frame.roleIcon:Hide()
	frame.statusText = createText(frame, "OVERLAY", "GameFontHighlightSmall", 7, "TOPLEFT", frame.nameText, "BOTTOMLEFT", 0, -1, "LEFT")
	frame.statusText:SetWidth((config.width or 96) - 8)
	frame.statusText:SetWordWrap(false)
	frame.statusText:SetTextColor(unpack(SECONDARY_TEXT_COLOR))
	frame.healthBar = createBar(frame, 8, "TOPLEFT", frame, "TOPLEFT", 4, -22)
	frame.powerBar = createBar(frame, 4, "TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, -4)
	frame:Hide()

	frame.targetFrame = self:CreateTargetFrame(frame, index)

	self.frames[index] = frame
	XFrames:RegisterInteractiveUnitFrame(frame, nil, false)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function()
		if not XFrames:IsFramesUnlocked() or (InCombatLockdown and InCombatLockdown()) then
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
	local name
	local statusText
	local health
	local healthMax
	local power
	local powerMax
	local powerColor

	if demoData then
		name = abbreviateName(demoData.name)
		statusText = demoData.className or "Tank"
		health = demoData.health or 0
		healthMax = demoData.healthMax or 1
		power = demoData.power or 0
		powerMax = demoData.powerMax or 1
		powerColor = demoData.powerColor or {r = 0.24, g = 0.28, b = 0.36}
	else
		name = UnitExists(unit) and abbreviateName(UnitName(unit) or frame.fallbackLabel) or frame.fallbackLabel
		statusText = UnitExists(unit) and (UnitClass(unit) or "Tank") or "Tank"
		health = UnitExists(unit) and UnitHealth(unit) or 0
		healthMax = UnitExists(unit) and UnitHealthMax(unit) or 1
		power = UnitExists(unit) and UnitPower(unit) or 0
		powerMax = UnitExists(unit) and UnitPowerMax(unit) or 1
		local _, color = XFrames:GetUnitPowerPresentation(unit, true)
		powerColor = color
	end

	local accent = getAccentColor(unit, demoData)
	frame.nameText:SetText(name)
	frame.nameText:SetTextColor(accent.r, accent.g, accent.b)
	frame.statusText:SetText(statusText)
	frame.roleFrame:SetShown(setRoleIcon(frame.roleIcon, "TANK"))
	frame.accentFrame:SetBackdropBorderColor(accent.r, accent.g, accent.b, 1)
	frame.healthBar:SetStatusBarColor(HEALTH_BAR_COLOR.r, HEALTH_BAR_COLOR.g, HEALTH_BAR_COLOR.b)
	XFrames:SetBarValues(frame.healthBar, health, healthMax)
	frame.powerBar:SetStatusBarColor(powerColor.r, powerColor.g, powerColor.b)
	XFrames:SetBarValues(frame.powerBar, power, powerMax)
end

function Tanks:UpdateTargetFrame(frame, unit, demoData)
	local targetFrame = frame.targetFrame
	if not XFrames:IsTankTargetsEnabled() then
		targetFrame:Hide()
		return
	end

	local targetDemo = demoData and demoData.target or nil
	local targetUnit = unit and (unit .. "target") or nil

	if targetDemo then
		targetFrame.nameText:SetText(abbreviateName(targetDemo.name or targetFrame.fallbackLabel))
		targetFrame.statusText:SetText("Target")
		targetFrame.accentFrame:SetBackdropBorderColor(0.78, 0.25, 0.22, 1)
		targetFrame.healthBar:SetStatusBarColor(HEALTH_BAR_COLOR.r, HEALTH_BAR_COLOR.g, HEALTH_BAR_COLOR.b)
		XFrames:SetBarValues(targetFrame.healthBar, targetDemo.health or 0, targetDemo.healthMax or 1)
		targetFrame.powerBar:SetStatusBarColor((targetDemo.powerColor or {r = 0.24, g = 0.28, b = 0.36}).r, (targetDemo.powerColor or {r = 0.24, g = 0.28, b = 0.36}).g, (targetDemo.powerColor or {r = 0.24, g = 0.28, b = 0.36}).b)
		XFrames:SetBarValues(targetFrame.powerBar, targetDemo.power or 0, targetDemo.powerMax or 1)
		XFrames:AssignInteractiveUnit(targetFrame, nil)
		targetFrame:Show()
		return
	end

	if not unit or not UnitExists(targetUnit) then
		if XFrames:IsFramesUnlocked() then
			targetFrame.nameText:SetText(targetFrame.fallbackLabel)
			targetFrame.statusText:SetText("")
			targetFrame.healthBar:SetStatusBarColor(HEALTH_BAR_COLOR.r, HEALTH_BAR_COLOR.g, HEALTH_BAR_COLOR.b)
			targetFrame.healthBar:SetMinMaxValues(0, 1)
			targetFrame.healthBar:SetValue(0)
			targetFrame.healthBar.valueText:SetText("")
			targetFrame.powerBar:SetStatusBarColor(0.24, 0.28, 0.36)
			targetFrame.powerBar:SetMinMaxValues(0, 1)
			targetFrame.powerBar:SetValue(0)
			targetFrame.powerBar.valueText:SetText("")
			XFrames:AssignInteractiveUnit(targetFrame, nil)
			targetFrame:Show()
		else
			targetFrame:Hide()
		end
		return
	end

	if not XFrames:AssignInteractiveUnit(targetFrame, targetUnit) then
		self.pendingAssignmentRefresh = true
	end

	targetFrame.nameText:SetText(abbreviateName(UnitName(targetUnit) or targetFrame.fallbackLabel))
	targetFrame.statusText:SetText("Target")
	targetFrame.accentFrame:SetBackdropBorderColor(0.78, 0.25, 0.22, 1)
	targetFrame.healthBar:SetStatusBarColor(HEALTH_BAR_COLOR.r, HEALTH_BAR_COLOR.g, HEALTH_BAR_COLOR.b)
	XFrames:SetBarValues(targetFrame.healthBar, UnitHealth(targetUnit), UnitHealthMax(targetUnit))
	local _, color = XFrames:GetUnitPowerPresentation(targetUnit, true)
	targetFrame.powerBar:SetStatusBarColor(color.r, color.g, color.b)
	XFrames:SetBarValues(targetFrame.powerBar, UnitPower(targetUnit), UnitPowerMax(targetUnit))
	targetFrame:Show()
end

function Tanks:RefreshFrame(index, unit)
	local frame = self:CreateUnitFrame(index)
	local demoData = self:GetDemoData(index)

	if demoData then
		XFrames:AssignInteractiveUnit(frame, nil)
		self:UpdateMainFrame(frame, nil, demoData)
		self:UpdateTargetFrame(frame, nil, demoData)
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

	-- No live tank in this slot.
	frame:Hide()
	frame.targetFrame:Hide()
end

function Tanks:RefreshAnchor()
	if not self.anchorFrame then
		return
	end

	if not XFrames:IsRaidFramesEnabled() or not XFrames:IsTankFramesEnabled() then
		self.anchorFrame:Hide()
		return
	end

	if self:IsDemoModeActive() then
		self.anchorFrame:Show()
		return
	end

	for _, unit in ipairs(self:GetAssignedTankUnits()) do
		if unit and UnitExists(unit) then
			self.anchorFrame:Show()
			return
		end
	end

	self.anchorFrame:Hide()
end

function Tanks:RefreshAll()
	self:ApplyLayout()

	if not XFrames:IsRaidFramesEnabled() or not XFrames:IsTankFramesEnabled() then
		if self.frames then
			for _, frame in ipairs(self.frames) do
				frame:Hide()
				if frame.targetFrame then
					frame.targetFrame:Hide()
				end
			end
		end
		self:RefreshAnchor()
		return
	end

	local units = self:GetAssignedTankUnits()
	local maxUnits = XFrames.db.profile.raid.tanks.maxUnits or 4
	for index = 1, maxUnits do
		self:RefreshFrame(index, units[index])
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
	frame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	frame:RegisterUnitEvent("UNIT_NAME_UPDATE", unpack(units))
	frame:RegisterUnitEvent("UNIT_HEALTH", unpack(units))
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", unpack(units))
	frame:RegisterUnitEvent("UNIT_POWER_UPDATE", unpack(units))
	frame:RegisterUnitEvent("UNIT_MAXPOWER", unpack(units))
	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", unpack(units))
	frame:RegisterUnitEvent("UNIT_TARGET", unpack(units))
	frame:RegisterUnitEvent("UNIT_NAME_UPDATE", unpack(targetUnits))
	frame:RegisterUnitEvent("UNIT_HEALTH", unpack(targetUnits))
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", unpack(targetUnits))
	frame:RegisterUnitEvent("UNIT_POWER_UPDATE", unpack(targetUnits))
	frame:RegisterUnitEvent("UNIT_MAXPOWER", unpack(targetUnits))
	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", unpack(targetUnits))
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
	for index = 1, (XFrames.db.profile.raid.tanks.maxUnits or 4) do
		self:CreateUnitFrame(index)
	end
	self:RegisterEvents()
	self:RefreshAll()
	XFrames:Info("Tank frames enabled")
end

function Tanks:ForEachFrame(callback)
	if self.anchorFrame then
		callback(self.anchorFrame)
	end

	for index = 1, (XFrames.db.profile.raid.tanks.maxUnits or 4) do
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
