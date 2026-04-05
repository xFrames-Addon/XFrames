local _, ns = ...

local XFrames = ns.XFrames

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local ReloadUI = ReloadUI
local UIParent = UIParent

local PANEL_BG = {0.08, 0.09, 0.11, 0.96}
local PANEL_BORDER = {0.24, 0.27, 0.31, 0.95}
local MINIMAP_BUTTON_BG = {0.12, 0.14, 0.18, 0.95}

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

local function createButton(parent, label, width, anchorPoint, relativeTo, relativePoint, x, y, onClick)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, 24)
	button:SetPoint(anchorPoint, relativeTo, relativePoint, x, y)
	button:SetText(label)
	button:SetScript("OnClick", onClick)
	return button
end

function XFrames:GetUISettings()
	return self.db and self.db.profile and self.db.profile.ui
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
	if not frame or not frame.xfMovable then
		return
	end

	local unlocked = self:IsFramesUnlocked()
	frame:EnableMouse(unlocked)

	if frame.xfDragOverlay then
		frame.xfDragOverlay:SetShown(unlocked)
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

	ui.unlocked = not not unlocked
	self:Info(string.format("Frames %s", ui.unlocked and "unlocked" or "locked"))
	self:RefreshAllFrameLocks()
end

function XFrames:ToggleFrameLocks()
	self:SetFramesUnlocked(not self:IsFramesUnlocked())
end

function XFrames:CreateSettingsPanel()
	if self.settingsFrame then
		return self.settingsFrame
	end

	local frame = createPanel(UIParent, 280, 154, "CENTER", UIParent, "CENTER", 0, 0)
	frame:SetFrameStrata("DIALOG")
	frame:Hide()

	frame.titleText = createText(frame, "GameFontNormalLarge", 13, "TOPLEFT", frame, "TOPLEFT", 12, -12, "LEFT")
	frame.titleText:SetText("XFrames")

	frame.statusText = createText(frame, "GameFontHighlight", 11, "TOPLEFT", frame.titleText, "BOTTOMLEFT", 0, -12, "LEFT")
	frame.helpText = createText(frame, "GameFontHighlightSmall", 10, "TOPLEFT", frame.statusText, "BOTTOMLEFT", 0, -8, "LEFT")
	frame.helpText:SetText("Unlock to drag frames with the left mouse button.")

	frame.lockButton = createButton(frame, "Unlock Frames", 118, "BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12, function()
		XFrames:ToggleFrameLocks()
	end)
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
	self.settingsFrame.statusText:SetText(unlocked and "Frames are unlocked" or "Frames are locked")
	self.settingsFrame.lockButton:SetText(unlocked and "Lock Frames" or "Unlock Frames")
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
	self:RefreshAllFrameLocks()
end
