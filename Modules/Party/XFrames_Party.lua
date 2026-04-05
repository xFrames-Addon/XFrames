local _, ns = ...

local XFrames = ns.XFrames
local Party = {}

local RAID_CLASS_COLORS = RAID_CLASS_COLORS

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local SetPortraitTexture = SetPortraitTexture
local UnitClass = UnitClass
local UnitCreatureType = UnitCreatureType
local UnitExists = UnitExists
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitIsPlayer = UnitIsPlayer
local UnitLevel = UnitLevel
local UnitName = UnitName
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax

local HEALTH_BAR_COLOR = {r = 0.18, g = 0.62, b = 0.32}
local BACKDROP_COLOR = {0.08, 0.09, 0.11, 0.92}
local BORDER_COLOR = {0.24, 0.27, 0.31, 0.95}
local PORTRAIT_BG_COLOR = {0.10, 0.11, 0.14, 0.98}
local SECONDARY_TEXT_COLOR = {0.72, 0.77, 0.84}
local LEVEL_TEXT_COLOR = {0.90, 0.92, 0.96}
local ROLE_BG_COLOR = {0.12, 0.14, 0.18, 0.96}

local function getPartyAccentColor(unit)
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

	bar.valueText = createText(bar, "OVERLAY", "GameFontHighlightSmall", 10, "RIGHT", bar, "RIGHT", -4, 0, "RIGHT")
	return bar
end

local function createBackdropFrame(name, parent, width, height, anchorPoint, relativeTo, relativePoint, x, y, bgColor)
	local frame = CreateFrame("Frame", name, parent, "BackdropTemplate")
	frame:SetSize(width, height)
	frame:SetPoint(anchorPoint, relativeTo, relativePoint, x, y)
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 2,
		insets = {left = 1, right = 1, top = 1, bottom = 1},
	})
	frame:SetBackdropColor(unpack(bgColor or BACKDROP_COLOR))
	frame:SetBackdropBorderColor(unpack(BORDER_COLOR))
	return frame
end

local function getStatusText(unit, fallbackLabel)
	if not UnitExists(unit) then
		return fallbackLabel
	end

	if UnitIsPlayer(unit) then
		local className = UnitClass(unit)
		if className then
			return className
		end
	end

	local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
	if role == "TANK" then
		return "Tank"
	end
	if role == "HEALER" then
		return "Healer"
	end
	if role == "DAMAGER" then
		return "Damage"
	end

	return UnitCreatureType(unit) or "Party Member"
end

local function getRoleInfo(unit)
	local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
	if role == "TANK" then
		return role
	end
	if role == "HEALER" then
		return role
	end
	if role == "DAMAGER" then
		return role
	end

	return nil
end

local function setRoleIcon(texture, role)
	if not texture then
		return
	end

	if role == "TANK" then
		texture:SetAtlas("groupfinder-icon-role-large-tank", true)
		texture:Show()
		return
	end
	if role == "HEALER" then
		texture:SetAtlas("groupfinder-icon-role-large-heal", true)
		texture:Show()
		return
	end
	if role == "DAMAGER" then
		texture:SetAtlas("groupfinder-icon-role-large-dps", true)
		texture:Show()
		return
	end

	texture:Hide()
end

function Party:CreateAnchorFrame()
	if self.anchorFrame then
		return self.anchorFrame
	end

	local config = XFrames.db.profile.party
	local frame = CreateFrame("Frame", "XFramesPartyAnchor", UIParent)
	frame:SetSize(config.width, (config.height * 4) + (config.spacing * 3))
	frame:SetScale(config.scale or 1)
	frame:SetPoint(config.position.point, UIParent, config.position.relativePoint, config.position.x, config.position.y)
	frame:SetFrameStrata("MEDIUM")
	frame:SetFrameLevel(20)
	frame:Hide()

	self.anchorFrame = frame
	XFrames:RegisterMovableFrame(frame, config.position, "Party")
	return frame
end

function Party:CreateUnitFrame(index)
	self.frames = self.frames or {}
	if self.frames[index] then
		return self.frames[index]
	end

	local config = XFrames.db.profile.party
	local anchor = self:CreateAnchorFrame()
	local unit = "party" .. index
	local fallbackLabel = "Party " .. index
	local frame = CreateFrame("Button", "XFramesPartyMemberFrame" .. index, anchor, "SecureUnitButtonTemplate,BackdropTemplate")
	frame.unit = unit
	frame.fallbackLabel = fallbackLabel
	frame:SetSize(config.width, config.height)
	frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, -((index - 1) * (config.height + config.spacing)))
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

	frame.portraitFrame = createBackdropFrame(nil, frame, 52, 52, "TOPLEFT", frame, "TOPLEFT", 6, -6, PORTRAIT_BG_COLOR)
	frame.portraitTexture = frame.portraitFrame:CreateTexture(nil, "ARTWORK")
	frame.portraitTexture:SetPoint("TOPLEFT", frame.portraitFrame, "TOPLEFT", 2, -2)
	frame.portraitTexture:SetSize(48, 48)
	frame.portraitTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	frame.nameText = createText(frame, "OVERLAY", "GameFontNormalLarge", 13, "TOPLEFT", frame, "TOPLEFT", 64, -10, "LEFT")
	frame.nameText:SetWidth(config.width - 124)
	frame.nameText:SetWordWrap(false)
	frame.levelText = createText(frame, "OVERLAY", "GameFontHighlight", 12, "TOPRIGHT", frame, "TOPRIGHT", -10, -10, "RIGHT")
	frame.levelText:SetTextColor(unpack(LEVEL_TEXT_COLOR))
	frame.roleFrame = createBackdropFrame(nil, frame, 20, 20, "RIGHT", frame.levelText, "LEFT", -8, 0, ROLE_BG_COLOR)
	frame.roleIcon = frame:CreateTexture(nil, "OVERLAY")
	frame.roleIcon:SetSize(18, 18)
	frame.roleIcon:SetPoint("CENTER", frame.roleFrame, "CENTER")
	frame.roleIcon:Hide()
	frame.statusText = createText(frame, "OVERLAY", "GameFontHighlightSmall", 10, "TOPLEFT", frame.nameText, "BOTTOMLEFT", 0, -2, "LEFT")
	frame.statusText:SetWidth(config.width - 124)
	frame.statusText:SetWordWrap(false)
	frame.statusText:SetTextColor(unpack(SECONDARY_TEXT_COLOR))

	frame.healthBar = createBar(frame, 14, "TOPLEFT", frame, "TOPLEFT", 64, -40)
	frame.powerBar = createBar(frame, 12, "TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, -6)

	self.frames[index] = frame
	XFrames:RegisterInteractiveUnitFrame(frame, unit, true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(dragFrame)
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

function Party:UpdateFrameBorder(frame)
	local color = getPartyAccentColor(frame.unit)
	frame.accentFrame:SetBackdropBorderColor(color.r, color.g, color.b, 1)
end

function Party:UpdatePortraitBorder(frame)
	local color = getPartyAccentColor(frame.unit)
	frame.portraitFrame:SetBackdropBorderColor(color.r, color.g, color.b, 1)
end

function Party:UpdateName(frame)
	if not UnitExists(frame.unit) then
		frame.nameText:SetText(frame.fallbackLabel)
		frame.nameText:SetTextColor(1, 1, 1)
		return
	end

	local name = UnitName(frame.unit) or frame.fallbackLabel
	local color = getPartyAccentColor(frame.unit)
	frame.nameText:SetText(name)
	frame.nameText:SetTextColor(color.r, color.g, color.b)
end

function Party:UpdateLevel(frame)
	if not UnitExists(frame.unit) then
		frame.levelText:SetText("")
		return
	end

	frame.levelText:SetTextColor(unpack(LEVEL_TEXT_COLOR))
	XFrames:SetValueText(frame.levelText, UnitLevel(frame.unit))
end

function Party:UpdateRole(frame)
	local role = getRoleInfo(frame.unit)
	setRoleIcon(frame.roleIcon, role)
end

function Party:UpdateStatus(frame)
	frame.statusText:SetText(getStatusText(frame.unit, frame.fallbackLabel))
	frame.statusText:SetTextColor(unpack(SECONDARY_TEXT_COLOR))
end

function Party:UpdatePortrait(frame)
	if not UnitExists(frame.unit) then
		frame.portraitTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
		self:UpdatePortraitBorder(frame)
		return
	end

	SetPortraitTexture(frame.portraitTexture, frame.unit)
	self:UpdatePortraitBorder(frame)
end

function Party:UpdateHealth(frame)
	local bar = frame.healthBar
	if not UnitExists(frame.unit) then
		bar:SetStatusBarColor(HEALTH_BAR_COLOR.r, HEALTH_BAR_COLOR.g, HEALTH_BAR_COLOR.b)
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(0)
		bar.valueText:SetText("")
		return
	end

	XFrames:SetBarValues(bar, UnitHealth(frame.unit), UnitHealthMax(frame.unit))
	bar:SetStatusBarColor(HEALTH_BAR_COLOR.r, HEALTH_BAR_COLOR.g, HEALTH_BAR_COLOR.b)
end

function Party:UpdatePower(frame)
	local bar = frame.powerBar
	local _, color = XFrames:GetUnitPowerPresentation(frame.unit, true)
	if not UnitExists(frame.unit) then
		bar:SetStatusBarColor(color.r, color.g, color.b)
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(0)
		bar.valueText:SetText("")
		return
	end

	bar:SetStatusBarColor(color.r, color.g, color.b)
	XFrames:SetBarValues(bar, UnitPower(frame.unit), UnitPowerMax(frame.unit))
end

function Party:RefreshFrame(frame)
	if not frame then
		return
	end

	if not UnitExists(frame.unit) then
		if XFrames:IsFramesUnlocked() then
			frame:Show()
			self:UpdateFrameBorder(frame)
			self:UpdateName(frame)
			self:UpdateLevel(frame)
			self:UpdateRole(frame)
			self:UpdateStatus(frame)
			self:UpdatePortrait(frame)
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
	self:UpdateRole(frame)
	self:UpdateStatus(frame)
	self:UpdatePortrait(frame)
	self:UpdateHealth(frame)
	self:UpdatePower(frame)
end

function Party:RefreshAnchor()
	if not self.anchorFrame then
		return
	end

	if XFrames:IsFramesUnlocked() then
		self.anchorFrame:Show()
		return
	end

	for index = 1, 4 do
		if UnitExists("party" .. index) then
			self.anchorFrame:Show()
			return
		end
	end

	self.anchorFrame:Hide()
end

function Party:RefreshAll()
	for index = 1, 4 do
		self:RefreshFrame(self.frames and self.frames[index])
	end
	self:RefreshAnchor()
end

function Party:OnEvent(event, unit)
	if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
		self:RefreshAll()
		XFrames:ApplyBlizzardFrameVisibility()
		return
	end

	if not unit then
		self:RefreshAll()
		return
	end

	for index = 1, 4 do
		local frame = self.frames and self.frames[index]
		if frame and frame.unit == unit then
			self:RefreshFrame(frame)
			self:RefreshAnchor()
			return
		end
	end

	self:RefreshAll()
end

function Party:RegisterEvents()
	self.eventFrame = self.eventFrame or CreateFrame("Frame")
	local frame = self.eventFrame
	frame:RegisterEvent("GROUP_ROSTER_UPDATE")
	frame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterUnitEvent("UNIT_NAME_UPDATE", "party1", "party2", "party3", "party4")
	frame:RegisterUnitEvent("UNIT_OTHER_PARTY_CHANGED", "party1", "party2", "party3", "party4")
	frame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "party1", "party2", "party3", "party4")
	frame:RegisterUnitEvent("UNIT_HEALTH", "party1", "party2", "party3", "party4")
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", "party1", "party2", "party3", "party4")
	frame:RegisterUnitEvent("UNIT_POWER_UPDATE", "party1", "party2", "party3", "party4")
	frame:RegisterUnitEvent("UNIT_MAXPOWER", "party1", "party2", "party3", "party4")
	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", "party1", "party2", "party3", "party4")
	frame:RegisterUnitEvent("UNIT_LEVEL", "party1", "party2", "party3", "party4")
	frame:SetScript("OnEvent", function(_, eventName, ...)
		XFrames:SafeCall("module Party:OnEvent", self.OnEvent, self, eventName, ...)
	end)
end

function Party:Initialize()
	local playerConfig = XFrames.db.profile.player
	local partyConfig = XFrames.db.profile.party

	partyConfig.width = playerConfig.width
	partyConfig.height = playerConfig.height
	partyConfig.scale = playerConfig.scale
	self.enabled = XFrames.db.profile.party.enabled
end

function Party:Enable()
	if not self.enabled then
		return
	end

	self:CreateAnchorFrame()
	for index = 1, 4 do
		self:CreateUnitFrame(index)
	end
	self:RegisterEvents()
	self:RefreshAll()
	XFrames:Info("Party frames enabled")
end

function Party:ForEachFrame(callback)
	if self.anchorFrame then
		callback(self.anchorFrame)
	end

	for index = 1, 4 do
		if self.frames and self.frames[index] then
			callback(self.frames[index])
		end
	end
end

XFrames:RegisterModule("Party", Party)
