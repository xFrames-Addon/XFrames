local _, ns = ...

local XFrames = ns.XFrames
local Party = {}

local RAID_CLASS_COLORS = RAID_CLASS_COLORS

local CreateFrame = CreateFrame
local CanInspect = CanInspect
local ClearInspectPlayer = ClearInspectPlayer
local GetTime = GetTime
local GetInspectSpecialization = GetInspectSpecialization
local GetSpecializationInfoByID = GetSpecializationInfoByID
local InCombatLockdown = InCombatLockdown
local NotifyInspect = NotifyInspect
local UnitClass = UnitClass
local UnitCreatureType = UnitCreatureType
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitIsPlayer = UnitIsPlayer
local UnitLevel = UnitLevel
local UnitName = UnitName
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local GetReadyCheckStatus = GetReadyCheckStatus

local PERFORMANCE_UPDATE_INTERVAL = 0.5

local HEALTH_BAR_COLOR = {r = 0.18, g = 0.62, b = 0.32}
local PERFORMANCE_TEXT_COLOR = {1.00, 0.82, 0.18}
local BACKDROP_COLOR = {0.08, 0.09, 0.11, 0.92}
local BORDER_COLOR = {0.24, 0.27, 0.31, 0.95}
local PORTRAIT_BG_COLOR = {0.10, 0.11, 0.14, 0.98}
local SECONDARY_TEXT_COLOR = {0.72, 0.77, 0.84}
local LEVEL_TEXT_COLOR = {0.90, 0.92, 0.96}
local ROLE_BG_COLOR = {0.12, 0.14, 0.18, 0.96}
local READY_CHECK_READY_TEX = "Interface\\RaidFrame\\ReadyCheck-Ready"
local READY_CHECK_NOT_READY_TEX = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local READY_CHECK_WAITING_TEX = "Interface\\RaidFrame\\ReadyCheck-Waiting"
local DEAD_BACKDROP_COLOR = {0.03, 0.03, 0.04, 0.96}
local DEAD_BORDER_COLOR = {0.16, 0.16, 0.18, 0.95}
local DEAD_TEXT_COLOR = {0.56, 0.58, 0.62}
local DEAD_BAR_COLOR = {r = 0.12, g = 0.12, b = 0.14}
local DIM_BACKDROP_COLOR = {0.04, 0.04, 0.05, 0.94}
local DIM_BORDER_COLOR = {0.18, 0.18, 0.20, 0.95}
local DIM_TEXT_COLOR = {0.55, 0.57, 0.60}
local DIM_BAR_COLOR = {r = 0.16, g = 0.16, b = 0.18}
local RANGE_UPDATE_INTERVAL = 0.25
local LOW_HEALTH_THRESHOLD = 0.30
local LOW_HEALTH_FLASH_INTERVAL = 0.40
local LOW_HEALTH_ALERT_COLOR = {1.00, 0.18, 0.18}
local DISPEL_ALERT_FALLBACK_COLOR = {r = 1.00, g = 0.18, b = 0.18}
local DEMO_MEMBERS = {
	{className = "Warrior", classToken = "WARRIOR", role = "TANK", name = "Tankard", level = 80, health = 920000, healthMax = 1000000, power = 35, powerMax = 100, powerColor = {r = 0.78, g = 0.24, b = 0.18}},
	{className = "Priest", classToken = "PRIEST", role = "HEALER", name = "Mendra", level = 80, health = 760000, healthMax = 820000, power = 220000, powerMax = 250000, powerColor = {r = 0.20, g = 0.44, b = 0.86}},
	{className = "Rogue", classToken = "ROGUE", role = "DAMAGER", name = "Shade", level = 80, health = 710000, healthMax = 760000, power = 82, powerMax = 100, powerColor = {r = 0.95, g = 0.78, b = 0.20}},
	{className = "Mage", classToken = "MAGE", role = "DAMAGER", name = "Ember", level = 80, health = 640000, healthMax = 700000, power = 180000, powerMax = 200000, powerColor = {r = 0.20, g = 0.44, b = 0.86}},
}

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

local function getClassColorForDemo(classToken)
	local classColor = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
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

local function getSpecText(module, unit)
	if not UnitExists(unit) or not UnitIsPlayer(unit) then
		return ""
	end

	local guid = UnitGUID(unit)
	return guid and module.inspectCache and module.inspectCache[guid] or ""
end

local function setRoleIcon(texture, role)
	if not texture then
		return false
	end

	if role == "TANK" then
		if texture.SetAtlas then
			texture:SetAtlas("UI-LFG-RoleIcon-Tank", false)
		end
		texture:SetVertexColor(1, 1, 1, 1)
		texture:Show()
		return true
	end
	if role == "HEALER" then
		if texture.SetAtlas then
			texture:SetAtlas("UI-LFG-RoleIcon-Healer", false)
		end
		texture:SetVertexColor(1, 1, 1, 1)
		texture:Show()
		return true
	end
	if role == "DAMAGER" then
		if texture.SetAtlas then
			texture:SetAtlas("UI-LFG-RoleIcon-DPS", false)
		end
		texture:SetVertexColor(1, 1, 1, 1)
		texture:Show()
		return true
	end

	texture:Hide()
	return false
end

local function setReadyCheckIcon(texture, status)
	if not texture then
		return false
	end

	if status == "ready" then
		texture:SetTexture(READY_CHECK_READY_TEX)
		texture:SetTexCoord(0, 1, 0, 1)
		texture:Show()
		return true
	end
	if status == "notready" then
		texture:SetTexture(READY_CHECK_NOT_READY_TEX)
		texture:SetTexCoord(0, 1, 0, 1)
		texture:Show()
		return true
	end
	if status == "waiting" then
		texture:SetTexture(READY_CHECK_WAITING_TEX)
		texture:SetTexCoord(0, 1, 0, 1)
		texture:Show()
		return true
	end

	texture:Hide()
	return false
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
	frame.demoIndex = index
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
	frame.specText = createText(frame, "OVERLAY", "GameFontHighlightSmall", 10, "TOP", frame.portraitFrame, "BOTTOM", 0, -4, "CENTER")
	frame.specText:SetWidth(52)
	frame.specText:SetWordWrap(false)
	frame.specText:SetMaxLines(1)
	frame.specText:SetJustifyH("CENTER")

	frame.nameText = createText(frame, "OVERLAY", "GameFontNormalLarge", 13, "TOPLEFT", frame, "TOPLEFT", 64, -10, "LEFT")
	frame.nameText:SetWidth(config.width - 124)
	frame.nameText:SetWordWrap(false)
	frame.levelText = createText(frame, "OVERLAY", "GameFontHighlight", 12, "TOPRIGHT", frame, "TOPRIGHT", -10, -10, "RIGHT")
	frame.levelText:SetTextColor(unpack(LEVEL_TEXT_COLOR))
	frame.roleFrame = createBackdropFrame(nil, frame, 20, 20, "RIGHT", frame.levelText, "LEFT", -8, 0, ROLE_BG_COLOR)
	frame.roleIcon = frame.roleFrame:CreateTexture(nil, "OVERLAY")
	frame.roleIcon:SetSize(18, 18)
	frame.roleIcon:SetPoint("CENTER", frame.roleFrame, "CENTER")
	frame.roleIcon:Hide()
	frame.readyCheckIcon = frame:CreateTexture(nil, "OVERLAY")
	frame.readyCheckIcon:SetSize(18, 18)
	frame.readyCheckIcon:SetPoint("RIGHT", frame.roleFrame, "LEFT", -6, 0)
	frame.readyCheckIcon:Hide()
	frame.deadFrame = CreateFrame("Frame", nil, frame)
	frame.deadFrame:SetAllPoints(frame)
	frame.deadFrame:SetFrameLevel(frame:GetFrameLevel() + 20)
	frame.deadFrame:Hide()
	frame.deadOverlay = frame.deadFrame:CreateTexture(nil, "OVERLAY")
	frame.deadOverlay:SetPoint("TOPLEFT", frame.deadFrame, "TOPLEFT", 1, -1)
	frame.deadOverlay:SetPoint("BOTTOMRIGHT", frame.deadFrame, "BOTTOMRIGHT", -1, 1)
	frame.deadOverlay:SetColorTexture(0, 0, 0, 0.45)
	frame.deadText = createText(frame.deadFrame, "OVERLAY", "GameFontNormal", 16, "CENTER", frame.deadFrame, "CENTER", 0, 0, "CENTER")
	frame.deadText:SetText("DEAD")
	frame.deadText:SetTextColor(1, 0.2, 0.2)
	frame.statusText = createText(frame, "OVERLAY", "GameFontHighlightSmall", 10, "TOPLEFT", frame.nameText, "BOTTOMLEFT", 0, -2, "LEFT")
	frame.statusText:SetWidth(config.width - 154)
	frame.statusText:SetWordWrap(false)
	frame.statusText:SetTextColor(unpack(SECONDARY_TEXT_COLOR))
	frame.rankText = createText(frame, "OVERLAY", "GameFontHighlightSmall", 10, "RIGHT", frame, "RIGHT", -10, -24, "RIGHT")
	frame.rankText:SetWidth(90)
	frame.rankText:SetWordWrap(false)
	frame.rankText:SetJustifyH("RIGHT")
	frame.rankText:SetTextColor(unpack(PERFORMANCE_TEXT_COLOR))

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
	if self:IsDead(frame) then
		frame.accentFrame:SetBackdropBorderColor(DEAD_BORDER_COLOR[1], DEAD_BORDER_COLOR[2], DEAD_BORDER_COLOR[3], 1)
		return
	end

	if self:IsOutOfRange(frame) then
		frame.accentFrame:SetBackdropBorderColor(DIM_BORDER_COLOR[1], DIM_BORDER_COLOR[2], DIM_BORDER_COLOR[3], 1)
		return
	end

	local demoData = self:GetDemoData(frame)
	local color
	if demoData then
		color = getClassColorForDemo(demoData.classToken)
	else
		color = getPartyAccentColor(frame.unit)
	end

	local dispelColor = self:GetDispellableAlertColor(frame)
	if dispelColor then
		local phase = GetTime and GetTime() or 0
		local flashOn = math.floor(phase / LOW_HEALTH_FLASH_INTERVAL) % 2 == 0
		if flashOn then
			frame.accentFrame:SetBackdropBorderColor(dispelColor.r, dispelColor.g, dispelColor.b, 1)
		else
			frame.accentFrame:SetBackdropBorderColor(color.r, color.g, color.b, 1)
		end
		return
	end

	if self:IsLowHealth(frame) then
		local phase = GetTime and GetTime() or 0
		local flashOn = math.floor(phase / LOW_HEALTH_FLASH_INTERVAL) % 2 == 0
		if flashOn then
			frame.accentFrame:SetBackdropBorderColor(LOW_HEALTH_ALERT_COLOR[1], LOW_HEALTH_ALERT_COLOR[2], LOW_HEALTH_ALERT_COLOR[3], 1)
		else
			frame.accentFrame:SetBackdropBorderColor(color.r, color.g, color.b, 1)
		end
		return
	end

	frame.accentFrame:SetBackdropBorderColor(color.r, color.g, color.b, 1)
end

function Party:UpdatePortraitBorder(frame)
	if self:IsDead(frame) then
		frame.portraitFrame:SetBackdropBorderColor(DEAD_BORDER_COLOR[1], DEAD_BORDER_COLOR[2], DEAD_BORDER_COLOR[3], 1)
		return
	end

	if self:IsOutOfRange(frame) then
		frame.portraitFrame:SetBackdropBorderColor(DIM_BORDER_COLOR[1], DIM_BORDER_COLOR[2], DIM_BORDER_COLOR[3], 1)
		return
	end

	local demoData = self:GetDemoData(frame)
	local color
	if demoData and RAID_CLASS_COLORS and RAID_CLASS_COLORS[demoData.classToken] then
		color = RAID_CLASS_COLORS[demoData.classToken]
	else
		color = getPartyAccentColor(frame.unit)
	end
	frame.portraitFrame:SetBackdropBorderColor(color.r, color.g, color.b, 1)
end

function Party:IsDead(frame)
	if not frame then
		return false
	end

	local demoData = self:GetDemoData(frame)
	if demoData then
		return demoData.isDead == true or demoData.isGhost == true
	end

	return UnitExists(frame.unit) and UnitIsDeadOrGhost and UnitIsDeadOrGhost(frame.unit) or false
end

function Party:IsOutOfRange(frame)
	if not frame or self:GetDemoData(frame) or self:IsDead(frame) then
		return false
	end

	return UnitExists(frame.unit) and XFrames:IsUnitOutOfRange(frame.unit) or false
end

function Party:IsLowHealth(frame)
	if not frame or self:IsDead(frame) or self:IsOutOfRange(frame) then
		return false
	end

	local demoData = self:GetDemoData(frame)
	if demoData then
		local maxHealth = demoData.healthMax or 0
		return maxHealth > 0 and ((demoData.health or 0) / maxHealth) <= LOW_HEALTH_THRESHOLD
	end

	if not UnitExists(frame.unit) then
		return false
	end

	local maxHealth = UnitHealthMax(frame.unit)
	if not maxHealth or maxHealth <= 0 then
		return false
	end

	return (UnitHealth(frame.unit) / maxHealth) <= LOW_HEALTH_THRESHOLD
end

function Party:GetDispellableAlertColor(frame)
	if not frame or self:GetDemoData(frame) or self:IsDead(frame) or self:IsOutOfRange(frame) then
		return nil
	end

	local aura = XFrames:GetFirstDispellableAura(frame.unit)
	if not aura then
		return nil
	end

	return XFrames:GetDispellableAuraColor(frame.unit, aura) or DISPEL_ALERT_FALLBACK_COLOR
end

function Party:IsDemoModeActive()
	if XFrames:IsTestingPreviewActive("party") then
		return true
	end

	if not XFrames:IsFramesUnlocked() then
		return false
	end

	for index = 1, 4 do
		if UnitExists("party" .. index) then
			return false
		end
	end

	return true
end

function Party:GetDemoData(frame)
	if not frame or not frame.demoIndex then
		return nil
	end

	local testingData = XFrames:GetTestingPreviewData("party", frame.demoIndex)
	if testingData then
		return testingData
	end

	if not self:IsDemoModeActive() then
		return nil
	end

	return DEMO_MEMBERS[frame.demoIndex]
end

function Party:UpdateName(frame)
	local demoData = self:GetDemoData(frame)
	if demoData then
		local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[demoData.classToken]
		frame.nameText:SetText(demoData.name)
		if self:IsDead(frame) then
			frame.nameText:SetTextColor(unpack(DEAD_TEXT_COLOR))
			return
		end
		if color then
			frame.nameText:SetTextColor(color.r, color.g, color.b)
		else
			frame.nameText:SetTextColor(1, 1, 1)
		end
		return
	end

	if not UnitExists(frame.unit) then
		frame.nameText:SetText(frame.fallbackLabel)
		frame.nameText:SetTextColor(1, 1, 1)
		return
	end

	local name = UnitName(frame.unit) or frame.fallbackLabel
	local color = getPartyAccentColor(frame.unit)
	frame.nameText:SetText(name)
	if self:IsDead(frame) then
		frame.nameText:SetTextColor(unpack(DEAD_TEXT_COLOR))
		return
	end
	frame.nameText:SetTextColor(color.r, color.g, color.b)
end

function Party:UpdateLevel(frame)
	local demoData = self:GetDemoData(frame)
	if demoData then
		frame.levelText:SetTextColor(unpack(LEVEL_TEXT_COLOR))
		XFrames:SetValueText(frame.levelText, demoData.level)
		return
	end

	if not UnitExists(frame.unit) then
		frame.levelText:SetText("")
		return
	end

	if self:IsOutOfRange(frame) then
		frame.levelText:SetTextColor(unpack(DIM_TEXT_COLOR))
	else
		frame.levelText:SetTextColor(unpack(LEVEL_TEXT_COLOR))
	end
	XFrames:SetValueText(frame.levelText, UnitLevel(frame.unit))
end

function Party:UpdateRole(frame)
	local demoData = self:GetDemoData(frame)
	local role = demoData and demoData.role or getRoleInfo(frame.unit)
	if self:IsDead(frame) then
		frame.roleFrame:Hide()
		return
	end
	frame.roleFrame:SetShown(setRoleIcon(frame.roleIcon, role))
	if frame.roleFrame:IsShown() then
		if self:IsOutOfRange(frame) then
			frame.roleFrame:SetBackdropBorderColor(DIM_BORDER_COLOR[1], DIM_BORDER_COLOR[2], DIM_BORDER_COLOR[3], 1)
			frame.roleIcon:SetVertexColor(0.6, 0.6, 0.6)
			frame.roleIcon:SetAlpha(0.75)
		else
			frame.roleFrame:SetBackdropBorderColor(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], 1)
			frame.roleIcon:SetVertexColor(1, 1, 1)
			frame.roleIcon:SetAlpha(1)
		end
	end
end

function Party:UpdateReadyCheck(frame)
	local demoData = self:GetDemoData(frame)
	if demoData then
		setReadyCheckIcon(frame.readyCheckIcon, demoData.readyCheckStatus)
		return
	end

	if not UnitExists(frame.unit) or not GetReadyCheckStatus then
		frame.readyCheckIcon:Hide()
		return
	end

	setReadyCheckIcon(frame.readyCheckIcon, GetReadyCheckStatus(frame.unit))
end

function Party:UpdateStatus(frame)
	local demoData = self:GetDemoData(frame)
	if self:IsDead(frame) then
		frame.statusText:SetText("")
		frame.statusText:SetTextColor(unpack(DEAD_TEXT_COLOR))
		return
	end

	if demoData then
		frame.statusText:SetText(demoData.className)
	else
		frame.statusText:SetText(getStatusText(frame.unit, frame.fallbackLabel))
	end
	frame.statusText:SetTextColor(unpack(SECONDARY_TEXT_COLOR))
end

function Party:UpdateRank(frame)
	local demoData = self:GetDemoData(frame)
	if demoData then
		frame.rankText:SetText("")
	elseif XFrames:GetPartySubtitleMode() == "performance" and UnitExists(frame.unit) then
		frame.rankText:SetText(XFrames:GetPerformanceTextForUnit(frame.unit) or "")
	else
		frame.rankText:SetText("")
	end
	if XFrames:GetPartySubtitleMode() == "performance" then
		frame.rankText:SetTextColor(unpack(PERFORMANCE_TEXT_COLOR))
	else
		frame.rankText:SetTextColor(unpack(SECONDARY_TEXT_COLOR))
	end
end

function Party:UpdateSpec(frame)
	local demoData = self:GetDemoData(frame)
	if demoData then
		frame.specText:SetText("")
		return
	end

	frame.specText:SetText(getSpecText(self, frame.unit))
end

function Party:QueueInspect(unit)
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

function Party:ProcessInspectQueue()
	if self.inspectPendingGUID or (InCombatLockdown and InCombatLockdown()) then
		return
	end

	while self.inspectQueue and #self.inspectQueue > 0 do
		local item = table.remove(self.inspectQueue, 1)
		self.inspectQueued[item.guid] = nil

		if UnitExists(item.unit) and UnitIsPlayer(item.unit) and CanInspect(item.unit, false) then
			NotifyInspect(item.unit)
			self.inspectPendingGUID = item.guid
			self.inspectPendingUnit = item.unit
			return
		end
	end
end

function Party:HandleInspectReady(inspectGUID)
	if inspectGUID == nil or not GetInspectSpecialization then
		return
	end

	local pendingUnit = self.inspectPendingUnit
	if pendingUnit and UnitExists(pendingUnit) then
		local specID = GetInspectSpecialization(pendingUnit)
		if specID ~= nil and GetSpecializationInfoByID then
			local ok, _, name = pcall(GetSpecializationInfoByID, specID)
			if ok and name then
				local pendingGUID = self.inspectPendingGUID
				if pendingGUID then
					self.inspectCache = self.inspectCache or {}
					self.inspectCache[pendingGUID] = XFrames:FormatSpecLabel(name)
				end
			end
		end
	end

	if ClearInspectPlayer then
		ClearInspectPlayer()
	end

	self.inspectPendingGUID = nil
	self.inspectPendingUnit = nil

	self:RefreshAll()
	self:ProcessInspectQueue()
end

function Party:UpdatePortrait(frame)
	local demoData = self:GetDemoData(frame)
	if demoData then
		XFrames:ApplyClassIcon(frame.portraitTexture, demoData.classToken, "Interface\\Icons\\INV_Misc_QuestionMark")
		self:UpdatePortraitBorder(frame)
		return
	end

	if not UnitExists(frame.unit) then
		frame.portraitTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
		frame.portraitTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		self:UpdatePortraitBorder(frame)
		return
	end

	XFrames:ApplyUnitPortrait(frame.portraitTexture, frame.unit)
	if self:IsOutOfRange(frame) and frame.portraitTexture.SetDesaturated then
		frame.portraitTexture:SetDesaturated(true)
		frame.portraitTexture:SetVertexColor(0.7, 0.7, 0.7)
	else
		if frame.portraitTexture.SetDesaturated then
			frame.portraitTexture:SetDesaturated(false)
		end
		frame.portraitTexture:SetVertexColor(1, 1, 1)
	end
	self:UpdatePortraitBorder(frame)
end

function Party:UpdateHealth(frame)
	local bar = frame.healthBar
	local demoData = self:GetDemoData(frame)
	if demoData then
		if self:IsDead(frame) then
			bar:SetStatusBarColor(DEAD_BAR_COLOR.r, DEAD_BAR_COLOR.g, DEAD_BAR_COLOR.b)
			bar:SetMinMaxValues(0, 1)
			bar:SetValue(0)
			bar.valueText:SetText("")
			return
		end
		bar:SetStatusBarColor(HEALTH_BAR_COLOR.r, HEALTH_BAR_COLOR.g, HEALTH_BAR_COLOR.b)
		XFrames:SetBarValues(bar, demoData.health, demoData.healthMax)
		return
	end

	if not UnitExists(frame.unit) then
		bar:SetStatusBarColor(HEALTH_BAR_COLOR.r, HEALTH_BAR_COLOR.g, HEALTH_BAR_COLOR.b)
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(0)
		bar.valueText:SetText("")
		return
	end

	if self:IsDead(frame) then
		bar:SetStatusBarColor(DEAD_BAR_COLOR.r, DEAD_BAR_COLOR.g, DEAD_BAR_COLOR.b)
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(0)
		bar.valueText:SetText("")
		return
	end

	XFrames:SetBarValues(bar, UnitHealth(frame.unit), UnitHealthMax(frame.unit))
	if self:IsOutOfRange(frame) then
		bar:SetStatusBarColor(DIM_BAR_COLOR.r, DIM_BAR_COLOR.g, DIM_BAR_COLOR.b)
	else
		bar:SetStatusBarColor(HEALTH_BAR_COLOR.r, HEALTH_BAR_COLOR.g, HEALTH_BAR_COLOR.b)
	end
end

function Party:UpdatePower(frame)
	local bar = frame.powerBar
	local demoData = self:GetDemoData(frame)
	if demoData then
		if self:IsDead(frame) then
			bar:SetStatusBarColor(DEAD_BAR_COLOR.r, DEAD_BAR_COLOR.g, DEAD_BAR_COLOR.b)
			bar:SetMinMaxValues(0, 1)
			bar:SetValue(0)
			bar.valueText:SetText("")
			return
		end
		bar:SetStatusBarColor(demoData.powerColor.r, demoData.powerColor.g, demoData.powerColor.b)
		XFrames:SetBarValues(bar, demoData.power, demoData.powerMax)
		return
	end

	local _, color = XFrames:GetUnitPowerPresentation(frame.unit, true)
	if not UnitExists(frame.unit) then
		bar:SetStatusBarColor(color.r, color.g, color.b)
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(0)
		bar.valueText:SetText("")
		return
	end

	if self:IsDead(frame) then
		bar:SetStatusBarColor(DEAD_BAR_COLOR.r, DEAD_BAR_COLOR.g, DEAD_BAR_COLOR.b)
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(0)
		bar.valueText:SetText("")
		return
	end

	if self:IsOutOfRange(frame) then
		bar:SetStatusBarColor(DIM_BAR_COLOR.r, DIM_BAR_COLOR.g, DIM_BAR_COLOR.b)
	else
		bar:SetStatusBarColor(color.r, color.g, color.b)
	end
	XFrames:SetBarValues(bar, UnitPower(frame.unit), UnitPowerMax(frame.unit))
end

function Party:UpdateDeadState(frame)
	if not frame then
		return
	end

	if self:IsDead(frame) then
		frame:SetBackdropColor(unpack(DEAD_BACKDROP_COLOR))
		frame:SetBackdropBorderColor(unpack(DEAD_BORDER_COLOR))
		frame.deadFrame:Show()
		return
	end

	if self:IsOutOfRange(frame) then
		frame:SetBackdropColor(unpack(DIM_BACKDROP_COLOR))
		frame:SetBackdropBorderColor(unpack(DIM_BORDER_COLOR))
		frame.deadFrame:Hide()
		return
	end

	frame:SetBackdropColor(unpack(BACKDROP_COLOR))
	frame:SetBackdropBorderColor(unpack(BORDER_COLOR))
	frame.deadFrame:Hide()
end

function Party:UpdateRangeText(frame)
	if not frame or self:IsDead(frame) or not self:IsOutOfRange(frame) then
		return
	end

	frame.nameText:SetTextColor(unpack(DIM_TEXT_COLOR))
	frame.statusText:SetTextColor(unpack(DIM_TEXT_COLOR))
	frame.specText:SetTextColor(unpack(DIM_TEXT_COLOR))
	frame.rankText:SetTextColor(unpack(DIM_TEXT_COLOR))
end

function Party:UpdateRangeState(frame)
	if not frame then
		return
	end

	self:UpdateDeadState(frame)
	self:UpdateFrameBorder(frame)
	self:UpdatePortraitBorder(frame)
	self:UpdateName(frame)
	self:UpdateLevel(frame)
	self:UpdateStatus(frame)
	self:UpdateSpec(frame)
	self:UpdateRank(frame)
	self:UpdateHealth(frame)
	self:UpdatePower(frame)
	self:UpdateRangeText(frame)
end

function Party:RefreshFrame(frame)
	if not frame then
		return
	end

	local demoData = self:GetDemoData(frame)
	if not UnitExists(frame.unit) and not demoData then
		if XFrames:IsFramesUnlocked() then
			XFrames:SetFrameShownSafely(frame, true)
			self:UpdateDeadState(frame)
			self:UpdateFrameBorder(frame)
			self:UpdateName(frame)
			self:UpdateLevel(frame)
			self:UpdateRole(frame)
			self:UpdateReadyCheck(frame)
			self:UpdateStatus(frame)
			self:UpdateRank(frame)
			self:UpdateSpec(frame)
			self:UpdatePortrait(frame)
			self:UpdateHealth(frame)
			self:UpdatePower(frame)
			self:UpdateRangeState(frame)
		else
			XFrames:SetFrameShownSafely(frame, false)
		end
		return
	end

	XFrames:SetFrameShownSafely(frame, true)
	self:UpdateDeadState(frame)
	self:UpdateFrameBorder(frame)
	self:UpdateName(frame)
	self:UpdateLevel(frame)
	self:UpdateRole(frame)
	self:UpdateReadyCheck(frame)
	self:UpdateStatus(frame)
	self:UpdateRank(frame)
	self:UpdateSpec(frame)
	self:UpdatePortrait(frame)
	self:UpdateHealth(frame)
	self:UpdatePower(frame)
	self:UpdateRangeState(frame)
	if UnitExists(frame.unit) then
		self:QueueInspect(frame.unit)
	end
end

function Party:RefreshAnchor()
	if not self.anchorFrame then
		return
	end

	if XFrames:IsFramesUnlocked() then
		XFrames:SetFrameShownSafely(self.anchorFrame, true)
		return
	end

	if XFrames:IsTestingPreviewActive("party") then
		XFrames:SetFrameShownSafely(self.anchorFrame, true)
		return
	end

	for index = 1, 4 do
		if UnitExists("party" .. index) then
			XFrames:SetFrameShownSafely(self.anchorFrame, true)
			return
		end
	end

	XFrames:SetFrameShownSafely(self.anchorFrame, false)
end

function Party:RefreshAll()
	for index = 1, 4 do
		self:RefreshFrame(self.frames and self.frames[index])
	end
	self:RefreshAnchor()
end

function Party:RefreshPerformanceMode()
	self.performanceElapsed = 0
	self.rangeElapsed = 0

	if not self.eventFrame then
		return
	end

	self.eventFrame:SetScript("OnUpdate", function(_, elapsed)
		local shouldRefresh

		self.rangeElapsed = (self.rangeElapsed or 0) + elapsed
		if self.rangeElapsed >= RANGE_UPDATE_INTERVAL then
			self.rangeElapsed = 0
			shouldRefresh = true
		end

		if XFrames:GetPartySubtitleMode() == "performance" then
			self.performanceElapsed = (self.performanceElapsed or 0) + elapsed
			if self.performanceElapsed >= PERFORMANCE_UPDATE_INTERVAL then
				self.performanceElapsed = 0
				shouldRefresh = true
			end
		end

		if shouldRefresh then
			self:RefreshAll()
		end
	end)

	self:RefreshAll()
end

function Party:OnEvent(event, unit)
	if event == "INSPECT_READY" then
		self:HandleInspectReady(unit)
		return
	end

	if event == "PLAYER_REGEN_ENABLED" then
		self:ProcessInspectQueue()
		return
	end

	if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
		self:RefreshAll()
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
	frame:RegisterEvent("READY_CHECK")
	frame:RegisterEvent("READY_CHECK_CONFIRM")
	frame:RegisterEvent("READY_CHECK_FINISHED")
	frame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("INSPECT_READY")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	frame:RegisterUnitEvent("UNIT_NAME_UPDATE", "party1", "party2", "party3", "party4")
	frame:RegisterUnitEvent("UNIT_OTHER_PARTY_CHANGED", "party1", "party2", "party3", "party4")
	frame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "party1", "party2", "party3", "party4")
	frame:RegisterUnitEvent("UNIT_HEALTH", "party1", "party2", "party3", "party4")
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", "party1", "party2", "party3", "party4")
	frame:RegisterUnitEvent("UNIT_POWER_UPDATE", "party1", "party2", "party3", "party4")
	frame:RegisterUnitEvent("UNIT_MAXPOWER", "party1", "party2", "party3", "party4")
	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", "party1", "party2", "party3", "party4")
	frame:RegisterUnitEvent("UNIT_LEVEL", "party1", "party2", "party3", "party4")
	frame:RegisterUnitEvent("UNIT_FLAGS", "party1", "party2", "party3", "party4")
	frame:RegisterUnitEvent("UNIT_AURA", "party1", "party2", "party3", "party4")
	frame:SetScript("OnEvent", function(_, eventName, ...)
		XFrames:SafeCall("module Party:OnEvent", self.OnEvent, self, eventName, ...)
	end)
	self:RefreshPerformanceMode()
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
