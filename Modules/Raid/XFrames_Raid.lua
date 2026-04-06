local _, ns = ...

local XFrames = ns.XFrames
local Raid = {}

local RAID_CLASS_COLORS = RAID_CLASS_COLORS

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitName = UnitName
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitGroupRolesAssigned = UnitGroupRolesAssigned

local HEALTH_BAR_COLOR = {r = 0.18, g = 0.62, b = 0.32}
local BACKDROP_COLOR = {0.08, 0.09, 0.11, 0.92}
local BORDER_COLOR = {0.24, 0.27, 0.31, 0.95}
local SECONDARY_TEXT_COLOR = {0.72, 0.77, 0.84}
local DEMO_TEMPLATES = {
	{className = "Warrior", classToken = "WARRIOR", role = "TANK", name = "Tankard", health = 920000, healthMax = 1000000, power = 35, powerMax = 100, powerColor = {r = 0.78, g = 0.24, b = 0.18}},
	{className = "Priest", classToken = "PRIEST", role = "HEALER", name = "Mendra", health = 760000, healthMax = 820000, power = 220000, powerMax = 250000, powerColor = {r = 0.20, g = 0.44, b = 0.86}},
	{className = "Rogue", classToken = "ROGUE", role = "DAMAGER", name = "Shade", health = 710000, healthMax = 760000, power = 82, powerMax = 100, powerColor = {r = 0.95, g = 0.78, b = 0.20}},
	{className = "Mage", classToken = "MAGE", role = "DAMAGER", name = "Ember", health = 640000, healthMax = 700000, power = 180000, powerMax = 200000, powerColor = {r = 0.20, g = 0.44, b = 0.86}},
	{className = "Paladin", classToken = "PALADIN", role = "HEALER", name = "Dawn", health = 850000, healthMax = 910000, power = 190000, powerMax = 210000, powerColor = {r = 0.20, g = 0.44, b = 0.86}},
}

local function abbreviateName(name)
	if type(name) ~= "string" or name == "" then
		return ""
	end

	local firstWord = name:match("^(%S+)")
	firstWord = firstWord or name
	if #firstWord <= 6 then
		return firstWord
	end

	return firstWord:sub(1, 6)
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

local function getRaidAccentColor(unit, demoData)
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

local function getDemoMember(index)
	local template = DEMO_TEMPLATES[((index - 1) % #DEMO_TEMPLATES) + 1]
	local member = {}
	for key, value in pairs(template) do
		member[key] = value
	end
	member.name = string.format("%s %d", template.name, index)
	return member
end

function Raid:IsDemoModeActive()
	if not XFrames:IsFramesUnlocked() then
		return false
	end

	local maxUnits = XFrames.db.profile.raid.maxUnits or 20
	for index = 1, maxUnits do
		if UnitExists("raid" .. index) then
			return false
		end
	end

	return true
end

function Raid:GetDemoData(frame)
	if not frame or not frame.demoIndex or not self:IsDemoModeActive() then
		return nil
	end

	return getDemoMember(frame.demoIndex)
end

function Raid:CreateAnchorFrame()
	if self.anchorFrame then
		return self.anchorFrame
	end

	local config = XFrames.db.profile.raid
	local columns = config.columns or 5
	local maxUnits = config.maxUnits or 20
	local rows = math.ceil(maxUnits / columns)
	local width = (config.width * columns) + (config.spacingX * (columns - 1))
	local height = (config.height * rows) + (config.spacingY * (rows - 1))

	local frame = CreateFrame("Frame", "XFramesRaidAnchor", UIParent)
	frame:SetSize(width, height)
	frame:SetScale(config.scale or 1)
	frame:SetPoint(config.position.point, UIParent, config.position.relativePoint, config.position.x, config.position.y)
	frame:SetFrameStrata("MEDIUM")
	frame:SetFrameLevel(20)
	frame:Hide()

	self.anchorFrame = frame
	XFrames:RegisterMovableFrame(frame, config.position, "Raid")
	return frame
end

function Raid:CreateUnitFrame(index)
	self.frames = self.frames or {}
	if self.frames[index] then
		return self.frames[index]
	end

	local config = XFrames.db.profile.raid
	local anchor = self:CreateAnchorFrame()
	local columns = config.columns or 5
	local col = (index - 1) % columns
	local row = math.floor((index - 1) / columns)

	local frame = CreateFrame("Button", "XFramesRaidMemberFrame" .. index, anchor, "SecureUnitButtonTemplate,BackdropTemplate")
	frame.unit = "raid" .. index
	frame.demoIndex = index
	frame.fallbackLabel = "Raid " .. index
	frame:SetSize(config.width, config.height)
	frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", col * (config.width + config.spacingX), -(row * (config.height + config.spacingY)))
	frame:SetFrameStrata("MEDIUM")
	frame:SetFrameLevel(anchor:GetFrameLevel() + index)
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

	frame.nameText = createText(frame, "OVERLAY", "GameFontNormalSmall", 9, "TOPLEFT", frame, "TOPLEFT", 4, -4, "LEFT")
	frame.nameText:SetWidth(config.width - 8)
	frame.nameText:SetWordWrap(false)
	frame.statusText = createText(frame, "OVERLAY", "GameFontHighlightSmall", 7, "TOPLEFT", frame.nameText, "BOTTOMLEFT", 0, -1, "LEFT")
	frame.statusText:SetWidth(config.width - 8)
	frame.statusText:SetWordWrap(false)
	frame.statusText:SetTextColor(unpack(SECONDARY_TEXT_COLOR))

	frame.healthBar = createBar(frame, 8, "TOPLEFT", frame, "TOPLEFT", 4, -22)
	frame.powerBar = createBar(frame, 4, "TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, -4)

	self.frames[index] = frame
	XFrames:RegisterInteractiveUnitFrame(frame, frame.unit, true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function()
		if not XFrames:IsFramesUnlocked() then
			return
		end
		if InCombatLockdown and InCombatLockdown() then
			return
		end

		anchor:StartMoving()
	end)
	frame:SetScript("OnDragStop", function()
		anchor:StopMovingOrSizing()
		XFrames:SaveFramePosition(anchor)
	end)
	return frame
end

function Raid:UpdateFrameBorder(frame)
	local color = getRaidAccentColor(frame.unit, self:GetDemoData(frame))
	frame.accentFrame:SetBackdropBorderColor(color.r, color.g, color.b, 1)
end

function Raid:UpdateName(frame)
	local demoData = self:GetDemoData(frame)
	if demoData then
		local color = getRaidAccentColor(frame.unit, demoData)
		frame.nameText:SetText(abbreviateName(demoData.name))
		frame.nameText:SetTextColor(color.r, color.g, color.b)
		return
	end

	if not UnitExists(frame.unit) then
		frame.nameText:SetText(frame.fallbackLabel)
		frame.nameText:SetTextColor(1, 1, 1)
		return
	end

	local name = UnitName(frame.unit) or frame.fallbackLabel
	local color = getRaidAccentColor(frame.unit)
	frame.nameText:SetText(abbreviateName(name))
	frame.nameText:SetTextColor(color.r, color.g, color.b)
end

function Raid:UpdateLevel(frame)
	return
end

function Raid:UpdateStatus(frame)
	local demoData = self:GetDemoData(frame)
	if demoData then
		if demoData.role == "TANK" then
			frame.statusText:SetText("T")
		elseif demoData.role == "HEALER" then
			frame.statusText:SetText("H")
		elseif demoData.role == "DAMAGER" then
			frame.statusText:SetText("D")
		else
			frame.statusText:SetText("")
		end
		return
	end

	if not UnitExists(frame.unit) then
		frame.statusText:SetText("")
		return
	end

	local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(frame.unit)
	if role == "TANK" then
		frame.statusText:SetText("T")
	elseif role == "HEALER" then
		frame.statusText:SetText("H")
	elseif role == "DAMAGER" then
		frame.statusText:SetText("D")
	else
		frame.statusText:SetText("")
	end
end

function Raid:UpdateHealth(frame)
	local bar = frame.healthBar
	local demoData = self:GetDemoData(frame)
	bar:SetStatusBarColor(HEALTH_BAR_COLOR.r, HEALTH_BAR_COLOR.g, HEALTH_BAR_COLOR.b)

	if demoData then
		XFrames:SetBarValues(bar, demoData.health, demoData.healthMax)
		return
	end

	if not UnitExists(frame.unit) then
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(0)
		bar.valueText:SetText("")
		return
	end

	XFrames:SetBarValues(bar, UnitHealth(frame.unit), UnitHealthMax(frame.unit))
end

function Raid:UpdatePower(frame)
	local bar = frame.powerBar
	local demoData = self:GetDemoData(frame)
	if demoData then
		bar:SetStatusBarColor(demoData.powerColor.r, demoData.powerColor.g, demoData.powerColor.b)
		XFrames:SetBarValues(bar, demoData.power, demoData.powerMax)
		return
	end

	local _, color = XFrames:GetUnitPowerPresentation(frame.unit, true)
	bar:SetStatusBarColor(color.r, color.g, color.b)

	if not UnitExists(frame.unit) then
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(0)
		bar.valueText:SetText("")
		return
	end

	XFrames:SetBarValues(bar, UnitPower(frame.unit), UnitPowerMax(frame.unit))
end

function Raid:RefreshFrame(frame)
	if not frame then
		return
	end

	if not UnitExists(frame.unit) and not self:GetDemoData(frame) then
		if XFrames:IsFramesUnlocked() then
			frame:Show()
			self:UpdateFrameBorder(frame)
			self:UpdateName(frame)
			self:UpdateLevel(frame)
			self:UpdateStatus(frame)
			self:UpdateHealth(frame)
			self:UpdatePower(frame)
		else
			frame:Hide()
		end
		return
	end

	frame:Show()
	self:UpdateFrameBorder(frame)
	self:UpdateName(frame)
	self:UpdateLevel(frame)
	self:UpdateStatus(frame)
	self:UpdateHealth(frame)
	self:UpdatePower(frame)
end

function Raid:RefreshAnchor()
	if not self.anchorFrame then
		return
	end

	if XFrames:IsFramesUnlocked() then
		self.anchorFrame:Show()
		return
	end

	local maxUnits = XFrames.db.profile.raid.maxUnits or 20
	for index = 1, maxUnits do
		if UnitExists("raid" .. index) then
			self.anchorFrame:Show()
			return
		end
	end

	self.anchorFrame:Hide()
end

function Raid:RefreshAll()
	local maxUnits = XFrames.db.profile.raid.maxUnits or 20
	for index = 1, maxUnits do
		self:RefreshFrame(self.frames and self.frames[index])
	end
	self:RefreshAnchor()
end

function Raid:OnEvent()
	self:RefreshAll()
	XFrames:ApplyBlizzardFrameVisibility()
end

function Raid:RegisterEvents()
	self.eventFrame = self.eventFrame or CreateFrame("Frame")
	local frame = self.eventFrame
	local units = {}
	local maxUnits = XFrames.db.profile.raid.maxUnits or 20

	for index = 1, maxUnits do
		units[#units + 1] = "raid" .. index
	end

	frame:RegisterEvent("GROUP_ROSTER_UPDATE")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterUnitEvent("UNIT_NAME_UPDATE", unpack(units))
	frame:RegisterUnitEvent("UNIT_OTHER_PARTY_CHANGED", unpack(units))
	frame:RegisterUnitEvent("UNIT_HEALTH", unpack(units))
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", unpack(units))
	frame:RegisterUnitEvent("UNIT_POWER_UPDATE", unpack(units))
	frame:RegisterUnitEvent("UNIT_MAXPOWER", unpack(units))
	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", unpack(units))
	frame:RegisterUnitEvent("UNIT_LEVEL", unpack(units))
	frame:SetScript("OnEvent", function(_, eventName, ...)
		XFrames:SafeCall("module Raid:OnEvent", self.OnEvent, self, eventName, ...)
	end)
end

function Raid:Initialize()
	self.enabled = XFrames.db.profile.raid.enabled
end

function Raid:Enable()
	if not self.enabled then
		return
	end

	local maxUnits = XFrames.db.profile.raid.maxUnits or 20
	self:CreateAnchorFrame()
	for index = 1, maxUnits do
		self:CreateUnitFrame(index)
	end
	self:RegisterEvents()
	self:RefreshAll()
	XFrames:Info("Raid frames enabled")
end

function Raid:ForEachFrame(callback)
	if self.anchorFrame then
		callback(self.anchorFrame)
	end

	local maxUnits = XFrames.db.profile.raid.maxUnits or 20
	for index = 1, maxUnits do
		if self.frames and self.frames[index] then
			callback(self.frames[index])
		end
	end
end

XFrames:RegisterModule("Raid", Raid)
