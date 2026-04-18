local _, ns = ...

local XFrames = ns.XFrames
local Player = {}

local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local CreateFrame = CreateFrame
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local UnitClass = UnitClass
local UnitCastingInfo = UnitCastingInfo
local UnitCastingDuration = UnitCastingDuration
local UnitChannelInfo = UnitChannelInfo
local UnitChannelDuration = UnitChannelDuration
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitName = UnitName
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitLevel = UnitLevel

local PERFORMANCE_UPDATE_INTERVAL = 0.5
local HEALTH_BAR_COLOR = {r = 0.18, g = 0.62, b = 0.32}
local PERFORMANCE_TEXT_COLOR = {1.00, 0.82, 0.18}
local BACKDROP_COLOR = {0.08, 0.09, 0.11, 0.92}
local BORDER_COLOR = {0.24, 0.27, 0.31, 0.95}
local PORTRAIT_BG_COLOR = {0.10, 0.11, 0.14, 0.98}
local CAST_BAR_COLOR = {r = 0.86, g = 0.66, b = 0.22}
local CHANNEL_BAR_COLOR = {r = 0.28, g = 0.56, b = 0.86}
local AURA_BORDER_COLOR = {r = 0.18, g = 0.20, b = 0.24}
local AURA_PLACEHOLDER_COLOR = {r = 0.10, g = 0.11, b = 0.14, a = 0.55}
local TIMER_DIRECTION = Enum and Enum.StatusBarTimerDirection
local BAR_INTERPOLATION = Enum and Enum.StatusBarInterpolation

local function getStatusText()
	local className = UnitClass("player")
	return className or "Player"
end

local function getSpecText()
	local specIndex = GetSpecialization and GetSpecialization()
	if not specIndex or not GetSpecializationInfo then
		return getStatusText()
	end

	local _, name = GetSpecializationInfo(specIndex)
	return XFrames:FormatSpecLabel(name)
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
	frame:SetBackdropColor(unpack(BACKDROP_COLOR))
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

function Player:CreateFrame()
	if self.frame then
		return self.frame
	end

	local config = XFrames.db.profile.player
	local frame = CreateFrame("Button", "XFramesPlayerFrame", UIParent, "SecureUnitButtonTemplate,BackdropTemplate")
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

	frame.portraitFrame = createBackdropFrame(nil, frame, 52, 52, "TOPLEFT", frame, "TOPLEFT", 6, -6)
	frame.portraitFrame:SetBackdropColor(unpack(PORTRAIT_BG_COLOR))
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
	frame.statusText:SetWidth(config.width - 148)
	frame.statusText:SetWordWrap(false)
	frame.rankText = createText(frame, "OVERLAY", "GameFontHighlightSmall", 10, "RIGHT", frame, "RIGHT", -10, -24, "RIGHT")
	frame.rankText:SetWidth(90)
	frame.rankText:SetWordWrap(false)
	frame.rankText:SetJustifyH("RIGHT")
	frame.rankText:SetTextColor(unpack(PERFORMANCE_TEXT_COLOR))

	frame.healthBar = createBar(frame, 14, "TOPLEFT", frame, "TOPLEFT", 64, -40)
	frame.healthBar:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
	frame.powerBar = createBar(frame, 12, "TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, -6)
	frame.powerBar:SetPoint("RIGHT", frame, "RIGHT", -10, 0)

	local buffConfig = config.buffs or {}
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

	local debuffConfig = config.debuffs or {}
	local debuffFrame = CreateFrame("Frame", nil, frame)
	debuffFrame:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", -(debuffConfig.xOffset or 6), debuffConfig.yOffset or -8)
	debuffFrame:SetSize(((debuffConfig.size or 22) * (debuffConfig.max or 8)) + ((debuffConfig.spacing or 4) * math.max((debuffConfig.max or 8) - 1, 0)), debuffConfig.size or 22)
	debuffFrame.buttons = {}
	debuffFrame.spacing = debuffConfig.spacing or 4
	frame.debuffFrame = debuffFrame

	for index = 1, (debuffConfig.max or 8) do
		debuffFrame.buttons[index] = XFrames:CreateAuraButton(debuffFrame, index, debuffConfig.size or 22, {
			backgroundColor = PORTRAIT_BG_COLOR,
			borderColor = AURA_BORDER_COLOR,
			placeholderColor = AURA_PLACEHOLDER_COLOR,
			showDispelHighlight = true,
			tooltipAnchor = "ANCHOR_TOP",
		})
	end

	self.frame = frame
	XFrames:RegisterInteractiveUnitFrame(frame, "player", false)
	XFrames:RegisterMovableFrame(frame, config.position, "Player")
	return frame
end

function Player:CreateCastFrame()
	if self.castFrame then
		return self.castFrame
	end

	local config = XFrames.db.profile.player.castBar
	if not config or not config.enabled then
		return nil
	end

	local castFrame = createBackdropFrame("XFramesPlayerCastFrame", UIParent, config.width, config.height, config.position.point, UIParent, config.position.relativePoint, config.position.x, config.position.y)
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
	XFrames:RegisterMovableFrame(castFrame, config.position, "Player Cast")
	return castFrame
end

function Player:UpdatePortraitBorder()
	local color = XFrames:GetUnitAccentColor("player")

	if color then
		self.frame.portraitFrame:SetBackdropBorderColor(color.r, color.g, color.b, 1)
	else
		self.frame.portraitFrame:SetBackdropBorderColor(unpack(BORDER_COLOR))
	end
end

function Player:UpdateFrameBorder()
	local color = XFrames:GetUnitAccentColor("player")
	self.frame.accentFrame:SetBackdropBorderColor(color.r, color.g, color.b, 1)
end

function Player:UpdateName()
	local frame = self.frame
	local name = UnitName("player") or "Player"
	local _, class = UnitClass("player")
	local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]

	frame.nameText:SetText(name)
	if color then
		frame.nameText:SetTextColor(color.r, color.g, color.b)
	else
		frame.nameText:SetTextColor(1, 1, 1)
	end
end

function Player:UpdateLevel()
	XFrames:SetValueText(self.frame.levelText, UnitLevel("player"))
end

function Player:UpdateStatus()
	self.frame.statusText:SetText(getStatusText())
end

function Player:UpdateRank()
	if XFrames:GetPartySubtitleMode() == "performance" then
		self.frame.rankText:SetText(XFrames:GetPerformanceTextForUnit("player") or "")
		self.frame.rankText:SetTextColor(unpack(PERFORMANCE_TEXT_COLOR))
		return
	end

	self.frame.rankText:SetText("")
end

function Player:UpdateSpec()
	self.frame.specText:SetText(getSpecText())
end

function Player:UpdatePortrait()
	XFrames:ApplyUnitPortrait(self.frame.portraitTexture, "player")
	self:UpdatePortraitBorder()
end

function Player:UpdateHealth()
	local bar = self.frame.healthBar
	local value = UnitHealth("player")
	local maxValue = UnitHealthMax("player")

	bar:SetStatusBarColor(HEALTH_BAR_COLOR.r, HEALTH_BAR_COLOR.g, HEALTH_BAR_COLOR.b)
	XFrames:SetBarValues(bar, value, maxValue)
end

function Player:UpdatePower()
	local bar = self.frame.powerBar
	local value = UnitPower("player")
	local maxValue = UnitPowerMax("player")
	local _, color = XFrames:GetUnitPowerPresentation("player")

	bar:SetStatusBarColor(color.r, color.g, color.b)
	XFrames:SetBarValues(bar, value, maxValue)
end

function Player:UpdateBuffs()
	local frame = self.frame
	if not frame or not frame.buffFrame then
		return
	end

	local buffConfig = XFrames.db.profile.player.buffs or {}
	if buffConfig.enabled == false or not XFrames:AreBuffBarsEnabled() then
		frame.buffFrame:Hide()
		for _, button in ipairs(frame.buffFrame.buttons) do
			button:Hide()
		end
		return
	end

	local buttons = frame.buffFrame.buttons
	local unlocked = XFrames:IsFramesUnlocked()
	local maxBuffs = buffConfig.max or #buttons
	local buffs = XFrames:CollectAuraData("player", "HELPFUL", maxBuffs)

	for index, button in ipairs(buttons) do
		local aura = buffs[index]
		if aura then
			XFrames:ApplyAuraButton(button, "player", aura, {
				borderColor = AURA_BORDER_COLOR,
			})
		elseif unlocked then
			XFrames:ResetAuraButton(button, {
				unit = "player",
				borderColor = AURA_BORDER_COLOR,
				placeholderColor = AURA_PLACEHOLDER_COLOR,
			})
			button:Show()
		else
			XFrames:ResetAuraButton(button, {
				unit = "player",
				borderColor = AURA_BORDER_COLOR,
				placeholderColor = AURA_PLACEHOLDER_COLOR,
			})
			button:Hide()
		end
	end

	frame.buffFrame:SetShown(unlocked or #buffs > 0)
end

function Player:UpdateDebuffs()
	local frame = self.frame
	if not frame or not frame.debuffFrame then
		return
	end

	local debuffConfig = XFrames.db.profile.player.debuffs or {}
	if debuffConfig.enabled == false then
		frame.debuffFrame:Hide()
		for _, button in ipairs(frame.debuffFrame.buttons) do
			button:Hide()
		end
		return
	end

	local buttons = frame.debuffFrame.buttons
	local unlocked = XFrames:IsFramesUnlocked()
	local maxDebuffs = debuffConfig.max or #buttons
	local debuffs = XFrames:CollectAuraData("player", "HARMFUL", maxDebuffs)

	for index, button in ipairs(buttons) do
		local aura = debuffs[index]
		if aura then
			XFrames:ApplyAuraButton(button, "player", aura, {
				borderColor = AURA_BORDER_COLOR,
				showDispelHighlight = true,
			})
		elseif unlocked then
			XFrames:ResetAuraButton(button, {
				unit = "player",
				borderColor = AURA_BORDER_COLOR,
				placeholderColor = AURA_PLACEHOLDER_COLOR,
			})
			button:Show()
		else
			XFrames:ResetAuraButton(button, {
				unit = "player",
				borderColor = AURA_BORDER_COLOR,
				placeholderColor = AURA_PLACEHOLDER_COLOR,
			})
			button:Hide()
		end
	end

	frame.debuffFrame:SetShown(unlocked or #debuffs > 0)
end

function Player:StopCastBar()
	if not self.castFrame then
		return
	end

	self.castState = nil
	self.castFrame:SetScript("OnUpdate", nil)
	self:RefreshCastState()
end

function Player:RefreshCastState()
	local castFrame = self.castFrame
	if not castFrame then
		return
	end

	local info = getCastInfo("player")
	local unlocked = XFrames:IsFramesUnlocked()

	if not info then
		self.castState = nil
		castFrame:SetScript("OnUpdate", nil)

		if unlocked then
			castFrame.bar:SetMinMaxValues(0, 1)
			castFrame.bar:SetValue(0)
			castFrame.bar:SetStatusBarColor(CAST_BAR_COLOR.r, CAST_BAR_COLOR.g, CAST_BAR_COLOR.b)
			castFrame.spellText:SetText("Player Cast")
			castFrame.timeText:SetText("")
			castFrame:Show()
		else
			castFrame:Hide()
		end
		return
	end

	self.castState = info
	castFrame:Show()
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

function Player:Refresh()
	if not self.frame then
		return
	end

	self:UpdateFrameBorder()
	self:UpdateName()
	self:UpdateLevel()
	self:UpdateStatus()
	self:UpdateRank()
	self:UpdateSpec()
	self:UpdatePortrait()
	self:UpdateHealth()
	self:UpdatePower()
	self:UpdateBuffs()
	self:UpdateDebuffs()
	self:RefreshCastState()
end

function Player:RefreshPerformanceMode()
	self.performanceElapsed = 0

	if not self.frame then
		return
	end

	self.frame:SetScript("OnUpdate", function(_, elapsed)
		self.performanceElapsed = (self.performanceElapsed or 0) + elapsed
		if self.performanceElapsed < PERFORMANCE_UPDATE_INTERVAL then
			return
		end

		self.performanceElapsed = 0
		self:UpdateStatus()
		self:UpdateRank()
	end)
end

function Player:OnEvent(event, unit)
	if unit and unit ~= "player" and not string.find(event, "^UNIT_SPELLCAST") then
		return
	end

	if event == "PLAYER_LEVEL_UP" then
		self:UpdateLevel()
		return
	end

	if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
		self:UpdateSpec()
		self:UpdateStatus()
		self:UpdateRank()
		return
	end

	if event == "UNIT_NAME_UPDATE" then
		self:UpdateName()
		return
	end

	if event == "UNIT_PORTRAIT_UPDATE" then
		self:UpdatePortrait()
		return
	end

	if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
		self:UpdateHealth()
		return
	end

	if event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
		self:UpdatePower()
		return
	end

	if event == "UNIT_AURA" then
		self:UpdateBuffs()
		self:UpdateDebuffs()
		return
	end

	if string.find(event, "^UNIT_SPELLCAST") then
		self:RefreshCastState()
		return
	end

	if event == "PLAYER_FLAGS_CHANGED" then
		self:UpdateStatus()
		self:UpdateRank()
		return
	end

	self:Refresh()
end

function Player:RegisterEvents()
	local frame = self.frame
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
	frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	frame:RegisterEvent("PLAYER_LEVEL_UP")
	frame:RegisterEvent("PLAYER_FLAGS_CHANGED")
	frame:RegisterUnitEvent("UNIT_HEALTH", "player")
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
	frame:RegisterUnitEvent("UNIT_NAME_UPDATE", "player")
	frame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "player")
	frame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
	frame:RegisterUnitEvent("UNIT_MAXPOWER", "player")
	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
	frame:RegisterUnitEvent("UNIT_AURA", "player")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "player")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
	frame:SetScript("OnEvent", function(_, event, ...)
		XFrames:SafeCall("module Player:OnEvent", self.OnEvent, self, event, ...)
	end)
end

function Player:Initialize()
	self.enabled = XFrames.db.profile.player.enabled
end

function Player:Enable()
	if not self.enabled then
		return
	end

	self:CreateFrame()
	self:CreateCastFrame()
	self:RegisterEvents()
	self:RefreshPerformanceMode()
	self:Refresh()
	self.frame:Show()
	XFrames:Info("Player shell enabled")
end

function Player:ForEachFrame(callback)
	if self.frame then
		callback(self.frame)
	end
	if self.castFrame then
		callback(self.castFrame)
	end
end

XFrames:RegisterModule("Player", Player)
