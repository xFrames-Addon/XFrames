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
local UnitClass = UnitClass
local UnitCastingInfo = UnitCastingInfo
local UnitCastingDuration = UnitCastingDuration
local UnitChannelInfo = UnitChannelInfo
local UnitChannelDuration = UnitChannelDuration
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
local AURA_BORDER_COLOR = {r = 0.18, g = 0.20, b = 0.24}
local AURA_PLACEHOLDER_COLOR = {r = 0.10, g = 0.11, b = 0.14, a = 0.55}
local CAST_BAR_COLOR = {r = 0.22, g = 0.78, b = 0.32}
local CHANNEL_BAR_COLOR = {r = 0.22, g = 0.78, b = 0.32}
local DIM_TEXT_COLOR = {0.55, 0.57, 0.60}
local DIM_BAR_COLOR = {r = 0.16, g = 0.16, b = 0.18}
local DIM_BORDER_COLOR = {0.18, 0.18, 0.20, 0.95}
local TIMER_DIRECTION = Enum and Enum.StatusBarTimerDirection
local BAR_INTERPOLATION = Enum and Enum.StatusBarInterpolation
local BOSS_HEALTH_BAR_COLOR = {r = 0.78, g = 0.22, b = 0.22}

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

local function getCastInfo(unit)
	local name = UnitCastingInfo(unit)
	if name then
		return {
			name = name,
			channel = false,
			duration = UnitCastingDuration and UnitCastingDuration(unit) or nil,
		}
	end

	local channelName = UnitChannelInfo(unit)
	if channelName then
		return {
			name = channelName,
			channel = true,
			duration = UnitChannelDuration and UnitChannelDuration(unit) or nil,
		}
	end

	return nil
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
	frame.specText:SetWidth(52)
	frame.specText:SetWordWrap(false)
	frame.specText:SetMaxLines(1)
	frame.specText:SetJustifyH("CENTER")

	frame.nameText = createText(frame, "OVERLAY", "GameFontNormalLarge", 13, "TOPLEFT", frame, "TOPLEFT", 64, -10, "LEFT")
	frame.levelText = createText(frame, "OVERLAY", "GameFontHighlight", 12, "TOPRIGHT", frame, "TOPRIGHT", -10, -10, "RIGHT")
	frame.statusText = createText(frame, "OVERLAY", "GameFontHighlightSmall", 10, "TOPLEFT", frame.nameText, "BOTTOMLEFT", 0, -2, "LEFT")

	frame.healthBar = createBar(frame, 14, "TOPLEFT", frame, "TOPLEFT", 64, -40)
	frame.healthBar:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
	frame.healthAccent = accent

	frame.powerBar = createBar(frame, 12, "TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, -6)
	frame.powerBar:SetPoint("RIGHT", frame, "RIGHT", -10, 0)

	local buffConfig = config.buffs or {}
	if buffConfig.max and buffConfig.max > 0 then
		local buffFrame = CreateFrame("Frame", nil, frame)
		buffFrame:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -(buffConfig.xOffset or 6), buffConfig.yOffset or 8)
		buffFrame:SetSize(((buffConfig.size or 22) * (buffConfig.max or 8)) + ((buffConfig.spacing or 4) * math.max((buffConfig.max or 8) - 1, 0)), buffConfig.size or 22)
		buffFrame.buttons = {}
		buffFrame.spacing = buffConfig.spacing or 4
		frame.buffFrame = buffFrame

		for index = 1, (buffConfig.max or 8) do
			buffFrame.buttons[index] = XFrames:CreateAuraButton(buffFrame, index, buffConfig.size or 22, {
				backgroundColor = PORTRAIT_BG_COLOR,
				borderColor = AURA_BORDER_COLOR,
				placeholderColor = AURA_PLACEHOLDER_COLOR,
				tooltipAnchor = "ANCHOR_BOTTOM",
			})
		end
	end

	XFrames:RegisterInteractiveUnitFrame(frame, unit, true)
	XFrames:RegisterMovableFrame(frame, config.position, frame.fallbackLabel)
	return frame
end

function Target:IsOutOfRange(frame)
	if not frame or frame.isBoss or not UnitExists(frame.unit) then
		return false
	end

	return XFrames:IsUnitOutOfRange(frame.unit)
end

function Target:UpdatePortraitBorder(frame)
	if not frame.portraitFrame then
		return
	end

	if self:IsOutOfRange(frame) then
		frame.portraitFrame:SetBackdropBorderColor(DIM_BORDER_COLOR[1], DIM_BORDER_COLOR[2], DIM_BORDER_COLOR[3], 1)
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
	if self:IsOutOfRange(frame) then
		frame.accentFrame:SetBackdropBorderColor(DIM_BORDER_COLOR[1], DIM_BORDER_COLOR[2], DIM_BORDER_COLOR[3], 1)
		return
	end

	local color = XFrames:GetUnitAccentColor(frame.unit)
	frame.accentFrame:SetBackdropBorderColor(color.r, color.g, color.b, 1)
end

function Target:CreateTargetCastFrame()
	if self.castFrame then
		return self.castFrame
	end

	local config = XFrames.db.profile.target.castBar
	if not config or not config.enabled then
		return nil
	end

	local castFrame = createBackdropFrame("XFramesTargetCastFrame", UIParent, config.width, config.height, config.position.point, UIParent, config.position.relativePoint, config.position.x, config.position.y)
	castFrame:SetFrameStrata("MEDIUM")
	castFrame:SetBackdropColor(unpack(BACKDROP_COLOR))
	castFrame.bar = createBar(castFrame, config.height - 6, "TOPLEFT", castFrame, "TOPLEFT", 3, -3)
	castFrame.bar:SetPoint("RIGHT", castFrame, "RIGHT", -3, 0)
	castFrame.bar.labelText:Show()
	castFrame.bar.labelText:SetWidth(math.max(40, config.width - 70))
	castFrame.bar.labelText:SetWordWrap(false)
	castFrame.bar.labelText:SetTextColor(1, 1, 1)
	castFrame.bar.valueText:Hide()
	castFrame.bar.percentText:Hide()
	castFrame.spellText = castFrame.bar.labelText
	castFrame.timeText = createText(castFrame.bar, "OVERLAY", "GameFontHighlightSmall", 10, "RIGHT", castFrame.bar, "RIGHT", -6, 0, "RIGHT")
	castFrame.spellText:SetText("")
	castFrame.timeText:SetText("")
	castFrame:Hide()

	self.castFrame = castFrame
	XFrames:RegisterMovableFrame(castFrame, config.position, "Target Cast")
	return castFrame
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

function Target:CreateBossAnchor()
	if self.bossAnchor then
		return self.bossAnchor
	end

	local config = XFrames.db.profile.target.boss
	local frame = CreateFrame("Frame", "XFramesBossAnchor", UIParent)
	frame:SetFrameStrata("MEDIUM")
	frame:SetFrameLevel(20)
	frame:Hide()

	self.bossAnchor = frame
	XFrames:RegisterMovableFrame(frame, config.position, "Bosses")
	self:ApplyBossLayout()
	return frame
end

function Target:ApplyBossLayout()
	if not self.bossAnchor then
		return
	end

	local config = XFrames.db.profile.target.boss
	local maxUnits = config.maxUnits or 5
	local spacing = config.spacing or 8
	local width = config.width or 188
	local height = config.height or 60

	self.bossAnchor:SetSize(width, (height * maxUnits) + (spacing * math.max(maxUnits - 1, 0)))
	self.bossAnchor:SetScale(config.scale or 1)

	for index = 1, maxUnits do
		local frame = self.bossFrames and self.bossFrames[index]
		if frame then
			frame:SetSize(width, height)
			frame:ClearAllPoints()
			frame:SetPoint("TOPRIGHT", self.bossAnchor, "TOPRIGHT", 0, -((index - 1) * (height + spacing)))
		end
	end
end

function Target:CreateBossFrame(index)
	self.bossFrames = self.bossFrames or {}
	if self.bossFrames[index] then
		return self.bossFrames[index]
	end

	local config = XFrames.db.profile.target.boss
	local anchor = self:CreateBossAnchor()
	local unit = "boss" .. index
	local frame = CreateFrame("Button", "XFramesBossFrame" .. index, anchor, "SecureUnitButtonTemplate,BackdropTemplate")
	frame.unit = unit
	frame.unitKey = unit
	frame.fallbackLabel = "Boss " .. index
	frame.isCompact = true
	frame.isBoss = true
	frame:SetSize(config.width, config.height)
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

	frame.nameText = createText(frame, "OVERLAY", "GameFontNormal", 12, "TOPLEFT", frame, "TOPLEFT", 8, -8, "LEFT")
	frame.nameText:SetWidth((config.width or 188) - 48)
	frame.nameText:SetWordWrap(false)
	frame.levelText = createText(frame, "OVERLAY", "GameFontHighlightSmall", 10, "TOPRIGHT", frame, "TOPRIGHT", -8, -9, "RIGHT")
	frame.statusText = createText(frame, "OVERLAY", "GameFontHighlightSmall", 9, "TOPLEFT", frame.nameText, "BOTTOMLEFT", 0, -2, "LEFT")
	frame.statusText:SetWidth((config.width or 188) - 16)
	frame.statusText:SetWordWrap(false)
	frame.healthBar = createBar(frame, 10, "TOPLEFT", frame, "TOPLEFT", 8, -24)
	frame.healthBar:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
	frame.healthAccent = BOSS_HEALTH_BAR_COLOR
	frame.powerBar = createBar(frame, 8, "TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, -4)
	frame.powerBar:SetPoint("RIGHT", frame, "RIGHT", -8, 0)

	self.bossFrames[index] = frame
	XFrames:RegisterInteractiveUnitFrame(frame, unit, true)
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
	if self:IsOutOfRange(frame) then
		frame.nameText:SetTextColor(unpack(DIM_TEXT_COLOR))
	elseif color then
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
	if self:IsOutOfRange(frame) then
		frame.specText:SetTextColor(unpack(DIM_TEXT_COLOR))
	else
		frame.specText:SetTextColor(1, 1, 1)
	end
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

		if UnitExists(item.unit) and UnitIsPlayer(item.unit) and CanInspect(item.unit, false) then
			NotifyInspect(item.unit)
			self.inspectPendingGUID = item.guid
			self.inspectPendingUnit = item.unit
			return
		end
	end
end

function Target:HandleInspectReady(inspectGUID)
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

	self:RefreshFrame(self.targetFrame)
	self:RefreshFrame(self.focusFrame)
	self:ProcessInspectQueue()
end

function Target:UpdateLevel(frame)
	if not UnitExists(frame.unit) then
		frame.levelText:SetText("")
		return
	end

	if self:IsOutOfRange(frame) then
		frame.levelText:SetTextColor(unpack(DIM_TEXT_COLOR))
	else
		frame.levelText:SetTextColor(1, 1, 1)
	end
	XFrames:SetValueText(frame.levelText, UnitLevel(frame.unit))
end

function Target:UpdateStatus(frame)
	if frame.statusText then
		frame.statusText:SetText(getStatusText(frame.unit, frame.fallbackLabel))
		if self:IsOutOfRange(frame) then
			frame.statusText:SetTextColor(unpack(DIM_TEXT_COLOR))
		else
			frame.statusText:SetTextColor(1, 1, 1)
		end
	end
end

function Target:UpdatePortrait(frame)
	if not frame.portraitTexture then
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

	if self:IsOutOfRange(frame) then
		bar:SetStatusBarColor(DIM_BAR_COLOR.r, DIM_BAR_COLOR.g, DIM_BAR_COLOR.b)
	else
		bar:SetStatusBarColor(accent.r, accent.g, accent.b)
	end
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

	if self:IsOutOfRange(frame) then
		bar:SetStatusBarColor(DIM_BAR_COLOR.r, DIM_BAR_COLOR.g, DIM_BAR_COLOR.b)
	else
		bar:SetStatusBarColor(color.r, color.g, color.b)
	end
	XFrames:SetBarValues(bar, value, maxValue)
end

function Target:UpdateBuffs(frame)
	if not frame or not frame.buffFrame then
		return
	end

	local buffConfig = (frame.unitKey == "target" and XFrames.db.profile.target and XFrames.db.profile.target.buffs) or {}
	if buffConfig.enabled == false or not XFrames:AreBuffBarsEnabled() then
		frame.buffFrame:Hide()
		for _, button in ipairs(frame.buffFrame.buttons) do
			button:Hide()
		end
		return
	end

	local buttons = frame.buffFrame.buttons
	local unlocked = XFrames:IsFramesUnlocked()
	local unit = frame.unit
	local maxBuffs = buffConfig.max or #buttons
	local buffs = UnitExists(unit) and XFrames:CollectAuraData(unit, "HELPFUL", maxBuffs) or {}

	for index, button in ipairs(buttons) do
		local aura = buffs[index]
		if aura then
			XFrames:ApplyAuraButton(button, unit, aura, {
				borderColor = AURA_BORDER_COLOR,
			})
		elseif unlocked then
			XFrames:ResetAuraButton(button, {
				unit = unit,
				borderColor = AURA_BORDER_COLOR,
				placeholderColor = AURA_PLACEHOLDER_COLOR,
			})
			button:Show()
		else
			XFrames:ResetAuraButton(button, {
				unit = unit,
				borderColor = AURA_BORDER_COLOR,
				placeholderColor = AURA_PLACEHOLDER_COLOR,
			})
			button:Hide()
		end
	end

	frame.buffFrame:SetShown(unlocked or #buffs > 0)
end

function Target:RefreshCastState()
	local castFrame = self.castFrame
	if not castFrame then
		return
	end

	local info = getCastInfo("target")
	local unlocked = XFrames:IsFramesUnlocked()

	if not info then
		self.castState = nil
		castFrame:SetScript("OnUpdate", nil)
		if self.targetFrame then
			self:UpdateFrameBorder(self.targetFrame)
		end

		if unlocked then
			castFrame.bar:SetMinMaxValues(0, 1)
			castFrame.bar:SetValue(0)
			castFrame.bar:SetStatusBarColor(CAST_BAR_COLOR.r, CAST_BAR_COLOR.g, CAST_BAR_COLOR.b)
			castFrame.spellText:SetText("Target Cast")
			castFrame.timeText:SetText("")
			castFrame:Show()
		else
			castFrame:Hide()
		end
		return
	end

	self.castState = info
	castFrame:Show()
	if self.targetFrame then
		self:UpdateFrameBorder(self.targetFrame)
	end

	local color = info.channel and CHANNEL_BAR_COLOR or CAST_BAR_COLOR
	castFrame.bar:SetStatusBarColor(color.r, color.g, color.b)
	castFrame.spellText:SetText(info.name or "")
	if info.duration and castFrame.bar.SetTimerDuration then
		local direction = info.channel and (TIMER_DIRECTION and TIMER_DIRECTION.RemainingTime or 1)
			or (TIMER_DIRECTION and TIMER_DIRECTION.ElapsedTime or 0)
		castFrame.bar:SetTimerDuration(
			info.duration,
			BAR_INTERPOLATION and BAR_INTERPOLATION.Immediate or 0,
			direction
		)
		castFrame.timeText:SetText("")
		castFrame:SetScript("OnUpdate", nil)
		return
	end

	castFrame.bar:SetMinMaxValues(0, 1)
	castFrame.bar:SetValue(info.channel and 0.35 or 1)
	castFrame.timeText:SetText("")
	castFrame:SetScript("OnUpdate", nil)
end

function Target:RefreshFrame(frame)
	if not frame then
		return
	end

	if not UnitExists(frame.unit) then
		if XFrames:IsFramesUnlocked() then
			XFrames:SetFrameShownSafely(frame, true)
			self:UpdateFrameBorder(frame)
			self:UpdateName(frame)
			self:UpdateLevel(frame)
			self:UpdateStatus(frame)
			self:UpdateSpec(frame)
			self:UpdatePortrait(frame)
			self:UpdateHealth(frame)
			self:UpdatePower(frame)
			self:UpdateBuffs(frame)
		end
		return
	end

	if XFrames:IsFramesUnlocked() then
		XFrames:SetFrameShownSafely(frame, true)
	end
	self:UpdateFrameBorder(frame)
	self:UpdateName(frame)
	self:UpdateLevel(frame)
	self:UpdateStatus(frame)
	self:UpdateSpec(frame)
	self:UpdatePortrait(frame)
	self:UpdateHealth(frame)
	self:UpdatePower(frame)
	self:UpdateBuffs(frame)

	if frame.specText then
		self:QueueInspect(frame.unit)
	end
end

function Target:RefreshAll()
	self:ApplyBossLayout()
	self:RefreshFrame(self.targetFrame)
	self:RefreshFrame(self.focusFrame)
	self:RefreshFrame(self.targetTargetFrame)
	self:RefreshFrame(self.focusTargetFrame)
	self:RefreshBossFrames()
	self:RefreshCastState()
end

function Target:RefreshBossFrames()
	if not self.bossAnchor then
		return
	end

	local enabled = XFrames.db.profile.target.boss and XFrames.db.profile.target.boss.enabled ~= false
	if not enabled then
		XFrames:SetFrameShownSafely(self.bossAnchor, false)
		for index = 1, (XFrames.db.profile.target.boss.maxUnits or 5) do
			local frame = self.bossFrames and self.bossFrames[index]
			if frame then
				XFrames:SetFrameShownSafely(frame, false)
			end
		end
		return
	end

	local anyVisible = false
	local maxUnits = XFrames.db.profile.target.boss.maxUnits or 5
	for index = 1, maxUnits do
		local frame = self.bossFrames and self.bossFrames[index]
		if frame then
			if UnitExists(frame.unit) then
				XFrames:SetFrameShownSafely(frame, true)
				self:UpdateFrameBorder(frame)
				self:UpdateName(frame)
				self:UpdateLevel(frame)
				frame.statusText:SetText("Boss")
				self:UpdateHealth(frame)
				self:UpdatePower(frame)
				anyVisible = true
			elseif XFrames:IsFramesUnlocked() then
				XFrames:SetFrameShownSafely(frame, true)
				frame.nameText:SetText(frame.fallbackLabel)
				frame.nameText:SetTextColor(1, 1, 1)
				frame.levelText:SetText("")
				frame.statusText:SetText("Boss")
				frame.accentFrame:SetBackdropBorderColor(BOSS_HEALTH_BAR_COLOR.r, BOSS_HEALTH_BAR_COLOR.g, BOSS_HEALTH_BAR_COLOR.b, 1)
				frame.healthBar:SetStatusBarColor(BOSS_HEALTH_BAR_COLOR.r, BOSS_HEALTH_BAR_COLOR.g, BOSS_HEALTH_BAR_COLOR.b)
				frame.healthBar:SetMinMaxValues(0, 1)
				frame.healthBar:SetValue(0)
				frame.healthBar.valueText:SetText("")
				frame.powerBar:SetStatusBarColor(POWER_BAR_COLOR.r, POWER_BAR_COLOR.g, POWER_BAR_COLOR.b)
				frame.powerBar:SetMinMaxValues(0, 1)
				frame.powerBar:SetValue(0)
				frame.powerBar.valueText:SetText("")
				anyVisible = true
			else
				XFrames:SetFrameShownSafely(frame, false)
			end
		end
	end

	if anyVisible then
		XFrames:SetFrameShownSafely(self.bossAnchor, true)
	else
		XFrames:SetFrameShownSafely(self.bossAnchor, false)
	end
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
		self:RefreshBossFrames()
		self:RefreshCastState()
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
		if string.find(event, "^UNIT_SPELLCAST") then
			self:RefreshCastState()
			return
		end
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

	if type(unit) == "string" and unit:match("^boss%d+$") then
		self:RefreshBossFrames()
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
	frame:RegisterUnitEvent("UNIT_HEALTH", "target", "focus", "targettarget", "focustarget", "boss1", "boss2", "boss3", "boss4", "boss5")
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", "target", "focus", "targettarget", "focustarget", "boss1", "boss2", "boss3", "boss4", "boss5")
	frame:RegisterUnitEvent("UNIT_LEVEL", "target", "focus", "targettarget", "focustarget", "boss1", "boss2", "boss3", "boss4", "boss5")
	frame:RegisterUnitEvent("UNIT_NAME_UPDATE", "target", "focus", "targettarget", "focustarget", "boss1", "boss2", "boss3", "boss4", "boss5")
	frame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "target", "focus", "targettarget", "focustarget")
	frame:RegisterUnitEvent("UNIT_POWER_UPDATE", "target", "focus", "targettarget", "focustarget", "boss1", "boss2", "boss3", "boss4", "boss5")
	frame:RegisterUnitEvent("UNIT_MAXPOWER", "target", "focus", "targettarget", "focustarget", "boss1", "boss2", "boss3", "boss4", "boss5")
	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", "target", "focus", "targettarget", "focustarget", "boss1", "boss2", "boss3", "boss4", "boss5")
	frame:RegisterUnitEvent("UNIT_AURA", "target")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_START", "target")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "target")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "target")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "target")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "target")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "target")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "target")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "target")
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
	self:CreateTargetCastFrame()
	if self.focusEnabled then
		self.focusFrame = self:CreateUnitFrame("focus", "focus", XFrames.db.profile.target.focus, FOCUS_HEALTH_BAR_COLOR)
	end
	if self.targetTargetEnabled then
		self.targetTargetFrame = self:CreateCompactUnitFrame("targettarget", "targettarget", XFrames.db.profile.target.targettarget, TARGET_TARGET_HEALTH_BAR_COLOR)
	end
	if self.focusTargetEnabled then
		self.focusTargetFrame = self:CreateCompactUnitFrame("focustarget", "focustarget", XFrames.db.profile.target.focustarget, FOCUS_TARGET_HEALTH_BAR_COLOR)
	end
	if XFrames.db.profile.target.boss and XFrames.db.profile.target.boss.enabled ~= false then
		self:CreateBossAnchor()
		for index = 1, (XFrames.db.profile.target.boss.maxUnits or 5) do
			self:CreateBossFrame(index)
		end
	end
	self.eventFrame = self.eventFrame or CreateFrame("Frame")
	self:RegisterEvents()
	self:RefreshAll()
	self:RefreshCastState()
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
	if self.bossFrames and self.bossFrames[1] then
		XFrames:Info("Boss shell enabled")
	end
end

function Target:ForEachFrame(callback)
	if self.targetFrame then
		callback(self.targetFrame)
	end
	if self.castFrame then
		callback(self.castFrame)
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
	if self.bossAnchor then
		callback(self.bossAnchor)
	end
	if self.bossFrames then
		for index = 1, (XFrames.db.profile.target.boss.maxUnits or 5) do
			if self.bossFrames[index] then
				callback(self.bossFrames[index])
			end
		end
	end
end

XFrames:RegisterModule("Target", Target)
