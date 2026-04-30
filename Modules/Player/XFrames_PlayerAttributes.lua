local _, ns = ...

local XFrames = ns.XFrames
local Attributes = {}

local CreateFrame = CreateFrame
local GetCombatRatingBonus = GetCombatRatingBonus
local GetCritChance = GetCritChance
local GetHaste = GetHaste
local GetMasteryEffect = GetMasteryEffect
local GetSpecialization = GetSpecialization
local UnitStat = UnitStat

local STAT_STRENGTH = LE_UNIT_STAT_STRENGTH or 1
local STAT_AGILITY = LE_UNIT_STAT_AGILITY or 2
local STAT_INTELLECT = LE_UNIT_STAT_INTELLECT or 4

local BACKDROP_COLOR = {0.05, 0.06, 0.08, 0.26}
local BORDER_COLOR = {0.24, 0.27, 0.31, 0.42}
local TITLE_COLOR = {1.00, 0.82, 0.18}
local LABEL_COLOR = {0.76, 0.80, 0.87}
local VALUE_COLOR = {0.96, 0.98, 1.00}
local PRIMARY_VALUE_COLOR = {1.00, 0.90, 0.48}
local ROW_KEYS = {"primary", "crit", "haste", "mastery", "vers"}
local ROW_LABELS = {
	primary = "Primary",
	crit = "Crit",
	haste = "Haste",
	mastery = "Mastery",
	vers = "Vers",
}
local PRIMARY_LABELS = {
	[STAT_STRENGTH] = "Strength",
	[STAT_AGILITY] = "Agility",
	[STAT_INTELLECT] = "Intellect",
}

local function createText(parent, template, size, anchorPoint, relativeTo, relativePoint, x, y, justify)
	local text = parent:CreateFontString(nil, "OVERLAY", template)
	text:SetPoint(anchorPoint, relativeTo, relativePoint, x, y)
	text:SetJustifyH(justify or "LEFT")

	local font, _, flags = text:GetFont()
	if font then
		text:SetFont(font, size, flags)
	end

	return text
end

local function getUnitStatTotal(index)
	if not UnitStat then
		return 0
	end

	local base, effective = UnitStat("player", index)
	return effective or base or 0
end

local function getPrimaryStat()
	local strength = getUnitStatTotal(STAT_STRENGTH)
	local agility = getUnitStatTotal(STAT_AGILITY)
	local intellect = getUnitStatTotal(STAT_INTELLECT)

	local bestIndex = STAT_STRENGTH
	local bestValue = strength

	if agility > bestValue then
		bestIndex = STAT_AGILITY
		bestValue = agility
	end

	if intellect > bestValue then
		bestIndex = STAT_INTELLECT
		bestValue = intellect
	end

	return PRIMARY_LABELS[bestIndex] or "Primary", bestValue
end

local function getVersatilityBonus()
	if GetCombatRatingBonus and CR_VERSATILITY_DAMAGE_DONE then
		return GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) or 0
	end

	if GetVersatilityBonus and CR_VERSATILITY_DAMAGE_DONE then
		return GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE) or 0
	end

	return 0
end

function Attributes:CreateFrame()
	if self.frame then
		return self.frame
	end

	local config = XFrames.db.profile.attributes
	local frame = CreateFrame("Frame", "XFramesAttributesFrame", UIParent, "BackdropTemplate")
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

	frame.titleText = createText(frame, "GameFontNormalSmall", 11, "TOPLEFT", frame, "TOPLEFT", 10, -10, "LEFT")
	frame.titleText:SetText("Attributes")
	frame.titleText:SetTextColor(unpack(TITLE_COLOR))

	frame.rows = {}
	local previous
	for index, key in ipairs(ROW_KEYS) do
		local label = createText(frame, "GameFontHighlightSmall", 10, "TOPLEFT", previous or frame.titleText, "BOTTOMLEFT", 0, previous and -6 or -10, "LEFT")
		local value = createText(frame, "GameFontHighlightSmall", 10, "TOPRIGHT", frame, "TOPRIGHT", -10, -((index - 1) * 16) - 31, "RIGHT")
		label:SetText(ROW_LABELS[key])
		label:SetTextColor(unpack(LABEL_COLOR))
		value:SetTextColor(unpack(key == "primary" and PRIMARY_VALUE_COLOR or VALUE_COLOR))
		frame.rows[key] = {
			label = label,
			value = value,
		}
		previous = label
	end

	self.frame = frame
	XFrames:RegisterMovableFrame(frame, config.position, "Attributes")
	return frame
end

function Attributes:UpdateValues()
	local frame = self.frame
	if not frame then
		return
	end

	local primaryLabel, primaryValue = getPrimaryStat()
	frame.rows.primary.label:SetText(primaryLabel)
	frame.rows.primary.value:SetText(string.format("%d", primaryValue or 0))
	frame.rows.crit.value:SetText(string.format("%.1f%%", (GetCritChance and GetCritChance() or 0)))
	frame.rows.haste.value:SetText(string.format("%.1f%%", (GetHaste and GetHaste() or 0)))
	frame.rows.mastery.value:SetText(string.format("%.1f%%", (GetMasteryEffect and GetMasteryEffect() or 0)))
	frame.rows.vers.value:SetText(string.format("%.1f%%", getVersatilityBonus()))
end

function Attributes:Refresh()
	if not self.frame then
		return
	end

	local enabled = XFrames:IsAttributesFrameEnabled()
	XFrames:SetFrameShownSafely(self.frame, enabled)
	if enabled then
		self:UpdateValues()
	end
end

function Attributes:OnEvent(event, unit)
	if unit and unit ~= "player" then
		return
	end

	self:Refresh()
end

function Attributes:RegisterEvents()
	if self.eventFrame then
		return
	end

	local frame = CreateFrame("Frame")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
	frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	frame:RegisterEvent("PLAYER_DAMAGE_DONE_MODS")
	frame:RegisterEvent("COMBAT_RATING_UPDATE")
	frame:RegisterEvent("MASTERY_UPDATE")
	frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	frame:RegisterEvent("UNIT_STATS")
	frame:SetScript("OnEvent", function(_, event, ...)
		XFrames:SafeCall("module Attributes:OnEvent", self.OnEvent, self, event, ...)
	end)
	self.eventFrame = frame
end

function Attributes:Initialize()
	self.enabled = XFrames:IsAttributesFrameEnabled()
end

function Attributes:Enable()
	self:CreateFrame()
	self:RegisterEvents()
	self:Refresh()
	XFrames:Info("Attribute frame enabled")
end

function Attributes:ForEachFrame(callback)
	if self.frame then
		callback(self.frame)
	end
end

XFrames:RegisterModule("Attributes", Attributes)
