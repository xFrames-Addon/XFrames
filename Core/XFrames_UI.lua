local _, ns = ...

local XFrames = ns.XFrames

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local ceil = math.ceil
local RegisterStateDriver = RegisterStateDriver
local ReloadUI = ReloadUI
local UIParent = UIParent
local RegisterUnitWatch = RegisterUnitWatch
local UnregisterUnitWatch = UnregisterUnitWatch
local UnregisterStateDriver = UnregisterStateDriver

local PANEL_BG = {0.08, 0.09, 0.11, 0.96}
local PANEL_BORDER = {0.24, 0.27, 0.31, 0.95}
local MINIMAP_BUTTON_BG = {0.12, 0.14, 0.18, 0.95}
local BLIZZARD_UNIT_FRAME_NAMES = {
	"PlayerFrame",
	"TargetFrame",
	"FocusFrame",
	"PetFrame",
	"PartyFrame",
	"CompactPartyFrame",
	"CompactPartyFrameMemberFrame1",
	"CompactPartyFrameMemberFrame2",
	"CompactPartyFrameMemberFrame3",
	"CompactPartyFrameMemberFrame4",
	"CompactPartyFrameMemberFrame5",
	"PartyMemberFrame1",
	"PartyMemberFrame2",
	"PartyMemberFrame3",
	"PartyMemberFrame4",
	"TargetFrameToT",
	"FocusFrameToT",
}
local BLIZZARD_RAID_FRAME_NAMES = {
	"CompactRaidFrameContainer",
}
local BLIZZARD_CAST_BAR_NAMES = {
	"PlayerCastingBarFrame",
	"CastingBarFrame",
	"PetCastingBarFrame",
	"TargetFrameSpellBar",
	"FocusFrameSpellBar",
}

local function createPanel(parent, width, height, anchorPoint, relativeTo, relativePoint, x, y)
	local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	frame:SetSize(width, height)
	frame:SetPoint(anchorPoint, relativeTo, relativePoint, x, y)
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
		insets = {left = 1, right = 1, top = 1, bottom = 1},
	})
	frame:SetBackdropColor(unpack(PANEL_BG))
	frame:SetBackdropBorderColor(unpack(PANEL_BORDER))
	return frame
end

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

local function fitButtonToText(button)
	if not button then
		return
	end

	local fontString = button:GetFontString()
	if not fontString then
		return
	end

	local width = button.xfMinWidth or button:GetWidth() or 80
	local textWidth = fontString.GetUnboundedStringWidth and fontString:GetUnboundedStringWidth() or fontString:GetStringWidth()
	if type(textWidth) == "number" then
		width = math.max(width, ceil(textWidth) + (button.xfPadding or 28))
	end
	if button.xfMaxWidth then
		width = math.min(width, button.xfMaxWidth)
	end
	button:SetWidth(width)
end

local function setButtonLabel(button, label)
	if not button then
		return
	end

	button:SetText(label or "")
	fitButtonToText(button)
end

local function createButton(parent, label, width, anchorPoint, relativeTo, relativePoint, x, y, onClick, maxWidth)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, 24)
	button:SetPoint(anchorPoint, relativeTo, relativePoint, x, y)
	button.xfMinWidth = width
	button.xfMaxWidth = maxWidth
	button.xfPadding = 28
	setButtonLabel(button, label)
	button:SetScript("OnClick", onClick)
	return button
end

function XFrames:GetUISettings()
	return self.db and self.db.profile and self.db.profile.ui
end

function XFrames:GetBlizzardUnitFrames()
	local frames = {}
	for _, frameName in ipairs(BLIZZARD_UNIT_FRAME_NAMES) do
		local frame = _G[frameName]
		if frame then
			frames[#frames + 1] = frame
		end
	end

	if self:IsRaidFramesEnabled() then
		for _, frameName in ipairs(BLIZZARD_RAID_FRAME_NAMES) do
			local frame = _G[frameName]
			if frame then
				frames[#frames + 1] = frame
			end
		end
	end

	return frames
end

function XFrames:GetBlizzardCastBarFrames()
	local frames = {}
	for _, frameName in ipairs(BLIZZARD_CAST_BAR_NAMES) do
		local frame = _G[frameName]
		if frame then
			frames[#frames + 1] = frame
		end
	end

	return frames
end

function XFrames:IsFramesUnlocked()
	local ui = self:GetUISettings()
	return ui and ui.unlocked
end

function XFrames:ApplyStoredPosition(frame, position)
	if not frame or not position then
		return
	end

	frame:ClearAllPoints()
	frame:SetPoint(position.point or "CENTER", UIParent, position.relativePoint or "CENTER", position.x or 0, position.y or 0)
end

function XFrames:SaveFramePosition(frame)
	local position = frame and frame.xfPosition
	if not position then
		return
	end

	local point, _, relativePoint, x, y = frame:GetPoint(1)
	position.point = point or "CENTER"
	position.relativePoint = relativePoint or point or "CENTER"
	position.x = x or 0
	position.y = y or 0
end

function XFrames:RefreshDragState(frame)
	if not frame then
		return
	end

	local unlocked = self:IsFramesUnlocked()
	local previewActive = false
	if frame.unit and type(frame.unit) == "string" then
		if frame.unit:match("^party%d+$") and self:IsTestingPreviewActive("party") then
			previewActive = true
		elseif frame.unit:match("^raid%d+$") and self:IsTestingPreviewActive("raid") then
			previewActive = true
		end
	end

	if frame.xfUnitWatch then
		if unlocked or previewActive then
			if frame.xfUnitWatchActive and not (InCombatLockdown and InCombatLockdown()) then
				UnregisterUnitWatch(frame)
				frame.xfUnitWatchActive = nil
			end
		elseif not frame.xfUnitWatchActive and not (InCombatLockdown and InCombatLockdown()) then
			RegisterUnitWatch(frame)
			frame.xfUnitWatchActive = true
		end
	end

	if not frame.xfMovable then
		return
	end

	frame:EnableMouse(true)

	if frame.xfDragOverlay then
		frame.xfDragOverlay:SetShown(unlocked)
	end
end

function XFrames:RegisterInteractiveUnitFrame(frame, unit, useUnitWatch)
	if not frame or not unit or type(frame.SetAttribute) ~= "function" then
		return
	end

	frame.unit = unit
	frame:SetAttribute("unit", unit)
	frame:SetAttribute("*type1", "target")
	frame:SetAttribute("*type2", "togglemenu")
	frame:RegisterForClicks("AnyUp")
	frame:EnableMouse(true)

	frame:SetScript("OnEnter", function(hoverFrame)
		if not hoverFrame.unit or not UnitExists(hoverFrame.unit) then
			return
		end

		GameTooltip_SetDefaultAnchor(GameTooltip, hoverFrame)
		GameTooltip:SetUnit(hoverFrame.unit)
		GameTooltip:Show()
	end)

	frame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	if useUnitWatch then
		frame.xfUnitWatch = true
		if not frame.xfUnitWatchActive then
			RegisterUnitWatch(frame)
			frame.xfUnitWatchActive = true
		end
	end
end

function XFrames:RegisterMovableFrame(frame, position, label)
	if not frame or not position then
		return
	end

	frame.xfMovable = true
	frame.xfPosition = position
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")

	frame.xfDragOverlay = frame.xfDragOverlay or createText(frame, "GameFontHighlightSmall", 10, "BOTTOM", frame, "TOP", 0, 4, "CENTER")
	frame.xfDragOverlay:SetText(label or frame:GetName() or "Frame")
	frame.xfDragOverlay:Hide()

	frame:SetScript("OnDragStart", function(movableFrame)
		if not XFrames:IsFramesUnlocked() then
			return
		end
		if InCombatLockdown and InCombatLockdown() then
			return
		end

		movableFrame:StartMoving()
	end)

	frame:SetScript("OnDragStop", function(movableFrame)
		movableFrame:StopMovingOrSizing()
		XFrames:SaveFramePosition(movableFrame)
	end)

	self:ApplyStoredPosition(frame, position)
	self:RefreshDragState(frame)
end

function XFrames:RefreshAllFrameLocks()
	for _, module in pairs(self.modules) do
		if type(module.ForEachFrame) == "function" then
			module:ForEachFrame(function(frame)
				self:RefreshDragState(frame)
			end)
		end

		if type(module.RefreshAll) == "function" then
			module:RefreshAll()
		elseif type(module.Refresh) == "function" then
			module:Refresh()
		end
	end

	self:RefreshSettingsPanel()
end

function XFrames:SetFramesUnlocked(unlocked)
	local ui = self:GetUISettings()
	if not ui then
		return
	end

	if InCombatLockdown and InCombatLockdown() then
		self:Warn("Frame lock changes are unavailable in combat")
		return
	end

	ui.unlocked = not not unlocked
	self:Info(string.format("Frames %s", ui.unlocked and "unlocked" or "locked"))
	self:RefreshAllFrameLocks()
end

function XFrames:ApplyBlizzardFrameVisibility()
	local ui = self:GetUISettings()
	if not ui then
		return
	end

	local hidden = ui.hideBlizzard ~= false
	for _, frame in ipairs(self:GetBlizzardUnitFrames()) do
		if hidden then
			RegisterStateDriver(frame, "visibility", "hide")
		else
			UnregisterStateDriver(frame, "visibility")
			if not (InCombatLockdown and InCombatLockdown()) then
				frame:Show()
			end
		end
	end

	self:RefreshSettingsPanel()
end

function XFrames:SetBlizzardFramesHidden(hidden)
	local ui = self:GetUISettings()
	if not ui then
		return
	end

	if InCombatLockdown and InCombatLockdown() then
		self:Warn("Blizzard frame visibility cannot change in combat")
		return
	end

	ui.hideBlizzard = not not hidden
	self:Info(string.format("Blizzard unit frames %s", ui.hideBlizzard and "hidden" or "shown"))
	self:ApplyBlizzardFrameVisibility()
end

function XFrames:ToggleBlizzardFrames()
	local ui = self:GetUISettings()
	self:SetBlizzardFramesHidden(not (ui and ui.hideBlizzard ~= false))
end

function XFrames:ApplyBlizzardCastBarVisibility()
	local ui = self:GetUISettings()
	if not ui then
		return
	end

	local hidden = ui.hideBlizzardCastBars ~= false
	for _, frame in ipairs(self:GetBlizzardCastBarFrames()) do
		if hidden then
			RegisterStateDriver(frame, "visibility", "hide")
		else
			UnregisterStateDriver(frame, "visibility")
			if not (InCombatLockdown and InCombatLockdown()) then
				frame:Show()
			end
		end
	end

	self:RefreshSettingsPanel()
end

function XFrames:SetBlizzardCastBarsHidden(hidden)
	local ui = self:GetUISettings()
	if not ui then
		return
	end

	if InCombatLockdown and InCombatLockdown() then
		self:Warn("Blizzard cast bar visibility cannot change in combat")
		return
	end

	ui.hideBlizzardCastBars = not not hidden
	self:Info(string.format("Blizzard cast bars %s", ui.hideBlizzardCastBars and "hidden" or "shown"))
	self:ApplyBlizzardCastBarVisibility()
end

function XFrames:ToggleBlizzardCastBars()
	local ui = self:GetUISettings()
	self:SetBlizzardCastBarsHidden(not (ui and ui.hideBlizzardCastBars ~= false))
end

function XFrames:ToggleFrameLocks()
	self:SetFramesUnlocked(not self:IsFramesUnlocked())
end

function XFrames:CreateSettingsPanel()
	if self.settingsFrame then
		return self.settingsFrame
	end

	local frame = createPanel(UIParent, 280, 458, "CENTER", UIParent, "CENTER", 0, 0)
	local ui = self:GetUISettings()
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame.xfPosition = ui and ui.settingsPosition or nil
	if frame.xfPosition then
		self:ApplyStoredPosition(frame, frame.xfPosition)
	end
	frame:SetScript("OnDragStart", function(panel)
		panel:StartMoving()
	end)
	frame:SetScript("OnDragStop", function(panel)
		panel:StopMovingOrSizing()
		XFrames:SaveFramePosition(panel)
	end)
	frame:Hide()

	frame.titleText = createText(frame, "GameFontNormalLarge", 13, "TOPLEFT", frame, "TOPLEFT", 12, -12, "LEFT")
	frame.titleText:SetText("XFrames")

	frame.statusText = createText(frame, "GameFontHighlight", 11, "TOPLEFT", frame.titleText, "BOTTOMLEFT", 0, -12, "LEFT")
	frame.statusText:SetWidth(256)
	frame.statusText:SetWordWrap(true)
	frame.helpText = createText(frame, "GameFontHighlightSmall", 10, "TOPLEFT", frame.statusText, "BOTTOMLEFT", 0, -8, "LEFT")
	frame.helpText:SetWidth(256)
	frame.helpText:SetWordWrap(true)
	frame.helpText:SetText("Unlock to drag frames and cast bars with the left mouse button. Drag this panel to move it.")
	frame.partyModeText = createText(frame, "GameFontHighlightSmall", 10, "TOPLEFT", frame.helpText, "BOTTOMLEFT", 0, -12, "LEFT")
	frame.partyModeText:SetWidth(256)
	frame.partyModeText:SetWordWrap(true)
	frame.meterModeText = createText(frame, "GameFontHighlightSmall", 10, "TOPLEFT", frame.partyModeText, "BOTTOMLEFT", 0, -12, "LEFT")
	frame.meterModeText:SetWidth(256)
	frame.meterModeText:SetWordWrap(true)

	frame.lockButton = createButton(frame, "Unlock Frames", 118, "BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 18, function()
		XFrames:ToggleFrameLocks()
	end)
	frame.partyModeButton = createButton(frame, "Show DPS: Off", 118, "TOPLEFT", frame.partyModeText, "BOTTOMLEFT", 0, -10, function()
		if XFrames:GetPartySubtitleMode() == "performance" then
			XFrames:SetPartySubtitleMode("status")
			return
		end

		XFrames:SetPartySubtitleMode("performance")
	end, 220)
	frame.meterModeButton = createButton(frame, "OOC Meter: Segment", 118, "TOPLEFT", frame.meterModeText, "BOTTOMLEFT", 0, -10, function()
		if XFrames:GetOutOfCombatMeterMode() == "overall" then
			XFrames:SetOutOfCombatMeterMode("segment")
			return
		end

		XFrames:SetOutOfCombatMeterMode("overall")
	end, 220)
	frame.blizzardButton = createButton(frame, "Hide Blizzard", 118, "TOPLEFT", frame.meterModeButton, "BOTTOMLEFT", 0, -10, function()
		XFrames:ToggleBlizzardFrames()
	end, 220)
	frame.castBarsButton = createButton(frame, "Hide Cast Bars", 118, "TOPLEFT", frame.blizzardButton, "BOTTOMLEFT", 0, -10, function()
		XFrames:ToggleBlizzardCastBars()
	end, 220)
	frame.portraitsButton = createButton(frame, "Portraits: Live", 118, "TOPLEFT", frame.castBarsButton, "BOTTOMLEFT", 0, -10, function()
		XFrames:TogglePortraitStyle()
	end, 220)
	frame.raidFramesButton = createButton(frame, "Raid Frames: On", 118, "TOPLEFT", frame.portraitsButton, "BOTTOMLEFT", 0, -10, function()
		XFrames:ToggleRaidFramesEnabled()
	end, 220)
	frame.raidLayoutButton = createButton(frame, "Raid Layout: 1x5", 118, "TOPLEFT", frame.raidFramesButton, "BOTTOMLEFT", 0, -10, function()
		XFrames:ToggleRaidLayout()
	end, 220)
	frame.reloadButton = createButton(frame, "Reload UI", 78, "LEFT", frame.lockButton, "RIGHT", 8, 0, function()
		ReloadUI()
	end)
	frame.closeButton = createButton(frame, "Close", 58, "LEFT", frame.reloadButton, "RIGHT", 8, 0, function()
		frame:Hide()
	end)

	self.settingsFrame = frame
	self:RefreshSettingsPanel()
	return frame
end

function XFrames:RefreshSettingsPanel()
	if not self.settingsFrame then
		return
	end

	local unlocked = self:IsFramesUnlocked()
	local ui = self:GetUISettings()
	self.settingsFrame.statusText:SetText(unlocked and "Frames are unlocked" or "Frames are locked")
	setButtonLabel(self.settingsFrame.lockButton, unlocked and "Lock Frames" or "Unlock Frames")
	self.settingsFrame.partyModeText:SetText("Show DPS in player and party frames.")
	self.settingsFrame.meterModeText:SetText("Out-of-combat meter source.")
	setButtonLabel(self.settingsFrame.partyModeButton, self:GetPartySubtitleMode() == "performance" and "Show DPS: On" or "Show DPS: Off")
	setButtonLabel(self.settingsFrame.meterModeButton, self:GetOutOfCombatMeterMode() == "overall" and "OOC Meter: Overall" or "OOC Meter: Segment")
	setButtonLabel(self.settingsFrame.blizzardButton, ui and ui.hideBlizzard ~= false and "Show Blizzard" or "Hide Blizzard")
	setButtonLabel(self.settingsFrame.castBarsButton, ui and ui.hideBlizzardCastBars ~= false and "Show Cast Bars" or "Hide Cast Bars")
	setButtonLabel(self.settingsFrame.portraitsButton, self:GetPortraitStyle() == "class" and "Portraits: Class" or "Portraits: Live")
	setButtonLabel(self.settingsFrame.raidFramesButton, self:IsRaidFramesEnabled() and "Raid Frames: On" or "Raid Frames: Off")
	setButtonLabel(self.settingsFrame.raidLayoutButton, self:GetRaidLayout() == "row" and "Raid Layout: 1x5" or "Raid Layout: 5x1")
end

function XFrames:ToggleSettings()
	local frame = self:CreateSettingsPanel()
	if frame:IsShown() then
		frame:Hide()
	else
		frame:Show()
		self:RefreshSettingsPanel()
	end
end

function XFrames:CreateMinimapButton()
	local ui = self:GetUISettings()
	if not ui or not ui.minimap or ui.minimap.hide or self.minimapButton then
		return self.minimapButton
	end

	local button = CreateFrame("Button", "XFramesMinimapButton", Minimap, "BackdropTemplate")
	button:SetSize(30, 30)
	button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -2, 2)
	button:SetFrameStrata("MEDIUM")
	button:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
		insets = {left = 1, right = 1, top = 1, bottom = 1},
	})
	button:SetBackdropColor(unpack(MINIMAP_BUTTON_BG))
	button:SetBackdropBorderColor(unpack(PANEL_BORDER))
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	button.icon = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	button.icon:SetPoint("CENTER")
	button.icon:SetText("XF")

	button:SetScript("OnClick", function(_, mouseButton)
		if mouseButton == "RightButton" then
			XFrames:ToggleFrameLocks()
			return
		end

		XFrames:ToggleSettings()
	end)

	button:SetScript("OnEnter", function(selfButton)
		GameTooltip:SetOwner(selfButton, "ANCHOR_LEFT")
		GameTooltip:SetText("XFrames")
		GameTooltip:AddLine("Left-click: Settings", 1, 1, 1)
		GameTooltip:AddLine("Right-click: Lock or unlock frames", 1, 1, 1)
		GameTooltip:Show()
	end)

	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	self.minimapButton = button
	return button
end

function XFrames:InitializeUI()
	self:CreateSettingsPanel()
	self:CreateMinimapButton()
	self:ApplyBlizzardFrameVisibility()
	self:ApplyBlizzardCastBarVisibility()
	self:RefreshAllFrameLocks()
end
