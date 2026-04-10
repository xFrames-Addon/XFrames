local _, ns = ...

local XFrames = ns.XFrames

local C_UnitAuras = C_UnitAuras
local CreateFrame = CreateFrame
local DebuffTypeColor = DebuffTypeColor
local GameTooltip = GameTooltip

local DEFAULT_AURA_BG_COLOR = {0.10, 0.11, 0.14, 0.98}
local DEFAULT_AURA_BORDER_COLOR = {0.18, 0.20, 0.24, 0.90}
local DEFAULT_PLACEHOLDER_COLOR = {r = 0.10, g = 0.11, b = 0.14, a = 0.55}

local function createAuraCountText(parent)
	local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	text:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -2, 2)
	local font, _, flags = text:GetFont()
	if font then
		text:SetFont(font, 10, flags)
	end
	text:SetJustifyH("RIGHT")
	text:SetText("")
	return text
end

function XFrames:CollectAuraData(unit, filter, maxCount)
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

function XFrames:GetAuraCountText(unit, aura)
	if not unit or not aura then
		return ""
	end

	if not (C_UnitAuras and C_UnitAuras.GetAuraApplicationDisplayCount and aura.auraInstanceID) then
		return ""
	end

	local ok, displayCount = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, unit, aura.auraInstanceID)
	if not ok or displayCount == nil then
		return ""
	end

	return displayCount
end

function XFrames:GetAuraDispelColor(dispelName)
	if not dispelName or not DebuffTypeColor then
		return nil
	end

	return DebuffTypeColor[dispelName]
end

function XFrames:CreateAuraButton(parent, index, size, options)
	options = options or {}

	local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
	button:SetSize(size, size)

	if options.growLeft == false then
		if index == 1 then
			button:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
		else
			button:SetPoint("LEFT", parent.buttons[index - 1], "RIGHT", parent.spacing, 0)
		end
	else
		if index == 1 then
			button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
		else
			button:SetPoint("RIGHT", parent.buttons[index - 1], "LEFT", -parent.spacing, 0)
		end
	end

	button:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
		insets = {left = 1, right = 1, top = 1, bottom = 1},
	})
	button:SetBackdropColor(unpack(options.backgroundColor or DEFAULT_AURA_BG_COLOR))
	local borderColor = options.borderColor or DEFAULT_AURA_BORDER_COLOR
	button:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a or 0.9)

	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
	button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
	button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	button.countText = createAuraCountText(button)

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
		if GameTooltip:IsForbidden() or not selfButton.auraInstanceID or not selfButton.xfUnit then
			return
		end

		GameTooltip:SetOwner(selfButton, options.tooltipAnchor or "ANCHOR_TOP")
		GameTooltip:SetUnitAuraByAuraInstanceID(selfButton.xfUnit, selfButton.auraInstanceID)
	end)

	button:SetScript("OnLeave", function()
		if GameTooltip:IsForbidden() then
			return
		end

		GameTooltip:Hide()
	end)

	self:ResetAuraButton(button, options, true)
	button:Hide()
	return button
end

function XFrames:ResetAuraButton(button, options, preserveVisibility)
	if not button then
		return
	end

	options = options or {}
	local placeholderColor = options.placeholderColor or DEFAULT_PLACEHOLDER_COLOR
	local borderColor = options.borderColor or DEFAULT_AURA_BORDER_COLOR

	button.auraInstanceID = nil
	button.xfUnit = options.unit or button.xfUnit
	button.icon:SetTexture("Interface\\Buttons\\WHITE8x8")
	button.icon:SetTexCoord(0, 1, 0, 1)
	button.icon:SetVertexColor(placeholderColor.r, placeholderColor.g, placeholderColor.b, placeholderColor.a)
	button.countText:SetText("")
	button.dispelGlow:Hide()
	button:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, options.placeholderBorderAlpha or 0.6)
	if not preserveVisibility then
		button:Hide()
	end
end

function XFrames:ApplyAuraButton(button, unit, aura, options)
	if not button or not aura then
		return
	end

	options = options or {}
	local borderColor = options.borderColor or DEFAULT_AURA_BORDER_COLOR

	button.xfUnit = unit
	button.auraInstanceID = aura.auraInstanceID
	button.icon:SetTexture(aura.icon or 134400)
	button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	button.icon:SetVertexColor(1, 1, 1, 1)
	button.countText:SetText(self:GetAuraCountText(unit, aura))
	button:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a or 0.9)

	if options.showDispelHighlight then
		local dispelColor = self:GetAuraDispelColor(aura.dispelName)
		if dispelColor then
			button.dispelGlow:SetBackdropBorderColor(dispelColor.r, dispelColor.g, dispelColor.b, 0.95)
			button.dispelGlow:Show()
		else
			button.dispelGlow:Hide()
		end
	else
		button.dispelGlow:Hide()
	end

	button:Show()
end
