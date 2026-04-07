local _, ns = ...

local XFrames = ns.XFrames
local Player = {}

local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local DebuffTypeColor = DebuffTypeColor

local C_UnitAuras = C_UnitAuras
local CreateFrame = CreateFrame
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local GameTooltip = GameTooltip
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
local BACKDROP_COLOR = {0.08, 0.09, 0.11, 0.92}
local BORDER_COLOR = {0.24, 0.27, 0.31, 0.95}
local POWER_BAR_COLOR = {r = 0.24, g = 0.28, b = 0.36}
local PORTRAIT_BG_COLOR = {0.10, 0.11, 0.14, 0.98}
local CAST_BAR_COLOR = {r = 0.86, g = 0.66, b = 0.22}
local CHANNEL_BAR_COLOR = {r = 0.28, g = 0.56, b = 0.86}
local LOCKED_BAR_COLOR = {r = 0.55, g = 0.55, b = 0.58}
local DEBUFF_BORDER_COLOR = {r = 0.18, g = 0.20, b = 0.24}
local DEBUFF_PLACEHOLDER_COLOR = {r = 0.10, g = 0.11, b = 0.14, a = 0.55}
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

local function createDebuffButton(parent, index, size)
	local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
	button:SetSize(size, size)
	if index == 1 then
		button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
	else
		button:SetPoint("RIGHT", parent.buttons[index - 1], "LEFT", -parent.spacing, 0)
	end

	button:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
		insets = {left = 1, right = 1, top = 1, bottom = 1},
	})
	button:SetBackdropColor(unpack(PORTRAIT_BG_COLOR))
	button:SetBackdropBorderColor(DEBUFF_BORDER_COLOR.r, DEBUFF_BORDER_COLOR.g, DEBUFF_BORDER_COLOR.b, 0.9)

	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
	button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
	button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	button.icon:SetColorTexture(DEBUFF_PLACEHOLDER_COLOR.r, DEBUFF_PLACEHOLDER_COLOR.g, DEBUFF_PLACEHOLDER_COLOR.b, DEBUFF_PLACEHOLDER_COLOR.a)

	button.countText = createText(button, "OVERLAY", "GameFontNormalSmall", 10, "BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2, "RIGHT")
	button.countText:SetText("")

	button.dispelGlow = CreateFrame("Frame", nil, button, "BackdropTemplate")
	button.dispelGlow:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
	button.dispelGlow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
	button.dispelGlow:SetBackdrop({
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 2,
	})
	button.dispelGlow:SetBackdropBorderColor(0.95, 0.95, 0.95, 0)
	button.dispelGlow:Hide()

	button:SetScript("OnEnter", function(selfButton)
		if GameTooltip:IsForbidden() or not selfButton.auraInstanceID then
			return
		end

		GameTooltip:SetOwner(selfButton, "ANCHOR_TOP")
		GameTooltip:SetUnitAuraByAuraInstanceID("player", selfButton.auraInstanceID)
	end)

	button:SetScript("OnLeave", function()
		if GameTooltip:IsForbidden() then
			return
		end

		GameTooltip:Hide()
	end)

	button:Hide()
	return button
end

local function getDispelColor(dispelName)
	if not dispelName or not DebuffTypeColor then
		return nil
	end

	return DebuffTypeColor[dispelName]
end

local function getDebuffData(unit, filter, maxCount)
	local results = {}
	if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then
		return results
	end

	for index = 1, maxCount do
		local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
		if not aura then
			break
		end

		results[#results + 1] = aura
	end

	return results
end

local function getAuraCountText(aura)
	if not aura then
		return ""
	end

	local applications = aura.applications
	if applications == nil then
		return ""
	end

	if canaccessvalue then
		if not canaccessvalue(applications) then
			return ""
		end
	elseif issecretvalue and issecretvalue(applications) then
		return ""
	end

	local ok, countValue = pcall(tonumber, applications)
	if not ok or not countValue or countValue <= 1 then
		return ""
	end

	return countValue
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

	frame.healthBar = createBar(frame, 14, "TOPLEFT", frame, "TOPLEFT", 64, -40)
	frame.healthBar:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
	frame.powerBar = createBar(frame, 12, "TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, -6)
	frame.powerBar:SetPoint("RIGHT", frame, "RIGHT", -10, 0)

	local debuffConfig = config.debuffs or {}
	local debuffFrame = CreateFrame("Frame", nil, frame)
	debuffFrame:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", -(debuffConfig.xOffset or 6), debuffConfig.yOffset or -8)
	debuffFrame:SetSize(((debuffConfig.size or 22) * (debuffConfig.max or 8)) + ((debuffConfig.spacing or 4) * math.max((debuffConfig.max or 8) - 1, 0)), debuffConfig.size or 22)
	debuffFrame.buttons = {}
	debuffFrame.spacing = debuffConfig.spacing or 4
	frame.debuffFrame = debuffFrame

	for index = 1, (debuffConfig.max or 8) do
		debuffFrame.buttons[index] = createDebuffButton(debuffFrame, index, debuffConfig.size or 22)
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
	if XFrames:GetPartySubtitleMode() == "performance" then
		self.frame.statusText:SetText(XFrames:GetPerformanceTextForUnit("player") or getStatusText())
		return
	end

	self.frame.statusText:SetText(getStatusText())
end

function Player:UpdateRank()
	if XFrames:GetPartySubtitleMode() == "performance" then
		self.frame.rankText:SetText(XFrames:GetPerformanceRankText("player"))
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
	local debuffs = getDebuffData("player", "HARMFUL", maxDebuffs)
	local dispellableAuras = {}

	for _, aura in ipairs(getDebuffData("player", "HARMFUL|RAID", maxDebuffs)) do
		if aura.auraInstanceID then
			dispellableAuras[aura.auraInstanceID] = aura.dispelName or true
		end
	end

	for index, button in ipairs(buttons) do
		local aura = debuffs[index]
		if aura then
			button.icon:SetTexture(aura.icon or 134400)
			button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			button.icon:SetVertexColor(1, 1, 1, 1)
			button.countText:SetText(getAuraCountText(aura))
			button.auraInstanceID = aura.auraInstanceID
			button:SetBackdropBorderColor(DEBUFF_BORDER_COLOR.r, DEBUFF_BORDER_COLOR.g, DEBUFF_BORDER_COLOR.b, 0.9)

			local dispelName = dispellableAuras[aura.auraInstanceID]
			local dispelColor = getDispelColor(type(dispelName) == "string" and dispelName or aura.dispelName)
			if dispelName then
				local color = dispelColor or {r = 0.95, g = 0.95, b = 0.45}
				button.dispelGlow:SetBackdropBorderColor(color.r, color.g, color.b, 0.95)
				button.dispelGlow:Show()
			else
				button.dispelGlow:Hide()
			end

			button:Show()
		elseif unlocked then
			button.auraInstanceID = nil
			button.icon:SetTexture("Interface\\Buttons\\WHITE8x8")
			button.icon:SetTexCoord(0, 1, 0, 1)
			button.icon:SetVertexColor(DEBUFF_PLACEHOLDER_COLOR.r, DEBUFF_PLACEHOLDER_COLOR.g, DEBUFF_PLACEHOLDER_COLOR.b, DEBUFF_PLACEHOLDER_COLOR.a)
			button.countText:SetText("")
			button.dispelGlow:Hide()
			button:SetBackdropBorderColor(DEBUFF_BORDER_COLOR.r, DEBUFF_BORDER_COLOR.g, DEBUFF_BORDER_COLOR.b, 0.6)
			button:Show()
		else
			button.auraInstanceID = nil
			button.dispelGlow:Hide()
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
