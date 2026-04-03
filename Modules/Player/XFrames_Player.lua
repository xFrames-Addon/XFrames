local _, ns = ...

local XFrames = ns.XFrames
local Player = {}

local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local PowerBarColor = PowerBarColor

local CreateFrame = CreateFrame
local SetPortraitTexture = SetPortraitTexture
local UnitCastingInfo = UnitCastingInfo
local UnitClass = UnitClass
local UnitChannelInfo = UnitChannelInfo
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitIsAFK = UnitIsAFK
local UnitIsDND = UnitIsDND
local UnitIsDead = UnitIsDead
local UnitIsGhost = UnitIsGhost
local UnitIsConnected = UnitIsConnected
local UnitLevel = UnitLevel
local UnitName = UnitName
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerType = UnitPowerType
local GetTime = GetTime

local HEALTH_BAR_COLOR = {r = 0.18, g = 0.78, b = 0.35}
local CAST_BAR_COLOR = {r = 0.87, g = 0.68, b = 0.21}
local CHANNEL_BAR_COLOR = {r = 0.35, g = 0.71, b = 0.92}
local BACKDROP_COLOR = {0.08, 0.09, 0.11, 0.92}
local BORDER_COLOR = {0.24, 0.27, 0.31, 0.95}
local POWER_BAR_COLORS = {
	[0] = {r = 0.18, g = 0.48, b = 0.90}, -- mana
	[1] = {r = 0.86, g = 0.26, b = 0.20}, -- rage
	[2] = {r = 0.96, g = 0.78, b = 0.18}, -- focus
	[3] = {r = 0.96, g = 0.78, b = 0.18}, -- energy
	[6] = {r = 0.00, g = 0.82, b = 1.00}, -- runic power
}
local POWER_LABELS = {
	[0] = "Mana",
	[1] = "Rage",
	[2] = "Focus",
	[3] = "Energy",
	[6] = "Runic Power",
}

local function shortValue(value)
	if not value then
		return "0"
	end

	if value >= 1000000 then
		return string.format("%.1fm", value / 1000000)
	end

	if value >= 1000 then
		return string.format("%.1fk", value / 1000)
	end

	return tostring(value)
end

local function percentText(current, maximum)
	if not maximum or maximum <= 0 then
		return "0%"
	end

	return string.format("%d%%", (current / maximum) * 100)
end

local function getStatusText()
	if not UnitIsConnected("player") then
		return "Offline"
	end
	if UnitIsDead("player") then
		return "Dead"
	end
	if UnitIsGhost("player") then
		return "Ghost"
	end
	if UnitIsAFK("player") then
		return "AFK"
	end
	if UnitIsDND("player") then
		return "DND"
	end

	local className = UnitClass("player")
	return className or "Player"
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

	bar.valueText = createText(bar, "OVERLAY", "GameFontHighlightSmall", 11, "RIGHT", bar, "RIGHT", -4, 0, "RIGHT")
	bar.percentText = createText(bar, "OVERLAY", "GameFontDisableSmall", 10, "RIGHT", bar.valueText, "LEFT", -10, 0, "RIGHT")

	return bar
end

local function createBackdropFrame(name, parent, width, height, anchorPoint, relativeTo, relativePoint, x, y)
	local frame = CreateFrame("Frame", name, parent, "BackdropTemplate")
	frame:SetSize(width, height)
	frame:SetPoint(anchorPoint, relativeTo, relativePoint, x, y)
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
		insets = {left = 1, right = 1, top = 1, bottom = 1},
	})
	frame:SetBackdropColor(unpack(BACKDROP_COLOR))
	frame:SetBackdropBorderColor(unpack(BORDER_COLOR))
	return frame
end

function Player:CreateFrame()
	if self.frame then
		return self.frame
	end

	local config = XFrames.db.profile.player
	local frame = CreateFrame("Frame", "XFramesPlayerFrame", UIParent, "BackdropTemplate")
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

	frame.portraitTexture = frame:CreateTexture(nil, "ARTWORK")
	frame.portraitTexture:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
	frame.portraitTexture:SetSize(48, 48)
	frame.portraitTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	frame.nameText = createText(frame, "OVERLAY", "GameFontNormalLarge", 13, "TOPLEFT", frame, "TOPLEFT", 64, -10, "LEFT")
	frame.levelText = createText(frame, "OVERLAY", "GameFontHighlight", 12, "TOPRIGHT", frame, "TOPRIGHT", -10, -10, "RIGHT")
	frame.statusText = createText(frame, "OVERLAY", "GameFontHighlightSmall", 10, "TOPLEFT", frame.nameText, "BOTTOMLEFT", 0, -4, "LEFT")

	frame.healthLabel = createText(frame, "OVERLAY", "GameFontNormalSmall", 11, "TOPLEFT", frame, "TOPLEFT", 64, -36, "LEFT")
	frame.healthLabel:SetText("Health")
	frame.healthBar = createBar(frame, 16, "TOPLEFT", frame.healthLabel, "BOTTOMLEFT", 0, -2)

	frame.powerLabel = createText(frame, "OVERLAY", "GameFontNormalSmall", 11, "TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, -10, "LEFT")
	frame.powerBar = createBar(frame, 14, "TOPLEFT", frame.powerLabel, "BOTTOMLEFT", 0, -2)

	if config.castBar and config.castBar.enabled then
		frame.castFrame = createBackdropFrame(nil, frame, config.castBar.width, config.castBar.height, "TOPLEFT", frame, "BOTTOMLEFT", 0, -8)
		frame.castBar = createBar(frame.castFrame, config.castBar.height - 6, "TOPLEFT", frame.castFrame, "TOPLEFT", 3, -3)
		frame.castBar:SetPoint("RIGHT", frame.castFrame, "RIGHT", -3, 0)
		frame.castBar.valueText:Hide()
		frame.castBar.percentText:Hide()
		frame.castSpellText = createText(frame.castFrame, "OVERLAY", "GameFontHighlightSmall", 11, "LEFT", frame.castBar, "LEFT", 6, 0, "LEFT")
		frame.castTimeText = createText(frame.castFrame, "OVERLAY", "GameFontHighlightSmall", 10, "RIGHT", frame.castBar, "RIGHT", -6, 0, "RIGHT")
		frame.castFrame:Hide()
	end

	self.frame = frame
	return frame
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
	local frame = self.frame
	local level = UnitLevel("player") or 0
	frame.levelText:SetText(string.format("Lv %d", level > 0 and level or 0))
end

function Player:UpdateStatus()
	self.frame.statusText:SetText(getStatusText())
end

function Player:UpdatePortrait()
	SetPortraitTexture(self.frame.portraitTexture, "player")
end

function Player:UpdateHealth()
	local current = UnitHealth("player") or 0
	local maximum = UnitHealthMax("player") or 0
	local bar = self.frame.healthBar

	if maximum <= 0 then
		maximum = 1
	end

	bar:SetStatusBarColor(HEALTH_BAR_COLOR.r, HEALTH_BAR_COLOR.g, HEALTH_BAR_COLOR.b)
	bar:SetMinMaxValues(0, maximum)
	bar:SetValue(current)
	bar.valueText:SetText(string.format("%s / %s", shortValue(current), shortValue(maximum)))
	bar.percentText:SetText(percentText(current, maximum))
end

function Player:UpdatePower()
	local powerType = UnitPowerType("player")
	local current = UnitPower("player", powerType) or 0
	local maximum = UnitPowerMax("player", powerType) or 0
	local color = POWER_BAR_COLORS[powerType] or PowerBarColor[powerType] or POWER_BAR_COLORS[0]
	local bar = self.frame.powerBar

	if maximum <= 0 then
		maximum = 1
	end

	self.frame.powerLabel:SetText(POWER_LABELS[powerType] or "Power")
	bar:SetStatusBarColor(color.r, color.g, color.b)
	bar:SetMinMaxValues(0, maximum)
	bar:SetValue(current)
	bar.valueText:SetText(string.format("%s / %s", shortValue(current), shortValue(maximum)))
	bar.percentText:SetText(percentText(current, maximum))
end

function Player:StopCastBar()
	if not self.frame or not self.frame.castFrame then
		return
	end

	self.castState = nil
	self.frame.castFrame:Hide()
	self.frame.castFrame:SetScript("OnUpdate", nil)
end

function Player:UpdateCastBarVisual()
	local state = self.castState
	local frame = self.frame
	if not state or not frame or not frame.castBar then
		return
	end

	local now = GetTime()
	local duration
	if state.channeling then
		duration = state.endTime - now
	else
		duration = now - state.startTime
	end

	if duration < 0 then
		duration = 0
	end

	local total = state.endTime - state.startTime
	if total <= 0 then
		total = 0.1
	end

	if now >= state.endTime then
		self:StopCastBar()
		return
	end

	frame.castFrame:Show()
	frame.castBar:SetMinMaxValues(0, total)
	frame.castBar:SetValue(duration)
	frame.castSpellText:SetText(state.spellName or "")
	frame.castTimeText:SetText(string.format("%.1f", state.endTime - now))
end

function Player:StartCastBar(spellName, startMS, endMS, channeling)
	if not self.frame or not self.frame.castFrame then
		return
	end

	local color = channeling and CHANNEL_BAR_COLOR or CAST_BAR_COLOR
	self.castState = {
		spellName = spellName,
		startTime = startMS / 1000,
		endTime = endMS / 1000,
		channeling = channeling,
	}

	self.frame.castBar:SetStatusBarColor(color.r, color.g, color.b)
	self.frame.castFrame:SetScript("OnUpdate", function()
		self:UpdateCastBarVisual()
	end)
	self:UpdateCastBarVisual()
end

function Player:RefreshCastState()
	local spellName, _, _, startMS, endMS = UnitCastingInfo("player")
	if spellName then
		self:StartCastBar(spellName, startMS, endMS, false)
		return
	end

	spellName, _, _, startMS, endMS = UnitChannelInfo("player")
	if spellName then
		self:StartCastBar(spellName, startMS, endMS, true)
		return
	end

	self:StopCastBar()
end

function Player:Refresh()
	if not self.frame then
		return
	end

	self:UpdateName()
	self:UpdateLevel()
	self:UpdateStatus()
	self:UpdatePortrait()
	self:UpdateHealth()
	self:UpdatePower()
	self:RefreshCastState()
end

function Player:OnEvent(event, unit)
	if unit and unit ~= "player" and not string.find(event, "^UNIT_SPELLCAST") then
		return
	end

	if event == "PLAYER_LEVEL_UP" then
		self:UpdateLevel()
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

	if event == "PLAYER_FLAGS_CHANGED" then
		self:UpdateStatus()
		return
	end

	if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" or event == "UNIT_SPELLCAST_DELAYED" then
		self:RefreshCastState()
		return
	end

	if event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
		self:StopCastBar()
		return
	end

	self:Refresh()
end

function Player:RegisterEvents()
	local frame = self.frame
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("PLAYER_LEVEL_UP")
	frame:RegisterEvent("PLAYER_FLAGS_CHANGED")
	frame:RegisterUnitEvent("UNIT_HEALTH", "player")
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
	frame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
	frame:RegisterUnitEvent("UNIT_MAXPOWER", "player")
	frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
	frame:RegisterUnitEvent("UNIT_NAME_UPDATE", "player")
	frame:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "player")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "player")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
	frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
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
	self:RegisterEvents()
	self:Refresh()
	self.frame:Show()
	XFrames:Info("Player shell enabled")
end

XFrames:RegisterModule("Player", Player)
