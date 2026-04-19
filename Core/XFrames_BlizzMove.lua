local _, ns = ...

local XFrames = ns.XFrames

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local hooksecurefunc = hooksecurefunc

local WINDOW_SPECS = {
	{key = "CharacterFrame", name = "CharacterFrame", label = "Character"},
	{key = "SpellBookFrame", name = "SpellBookFrame", label = "Spellbook"},
	{key = "PlayerSpellsFrame", name = "PlayerSpellsFrame", label = "Talents"},
	{key = "CollectionsJournal", name = "CollectionsJournal", label = "Collections"},
	{key = "EncounterJournal", name = "EncounterJournal", label = "Adventure Guide"},
	{key = "QuestLogFrame", name = "QuestLogFrame", label = "Quest Log"},
	{key = "MerchantFrame", name = "MerchantFrame", label = "Merchant"},
	{key = "ContainerFrameCombinedBags", name = "ContainerFrameCombinedBags", label = "Bags"},
	{key = "BankFrame", name = "BankFrame", label = "Bank"},
}

local BAG_FRAME_COUNT = 20
local OPEN_HOOKS = {
	"ToggleCharacter",
	"ToggleBackpack",
	"ToggleAllBags",
	"OpenAllBags",
	"ToggleBag",
	"OpenBag",
	"ToggleSpellBook",
	"ToggleCollectionsJournal",
	"EncounterJournal_Toggle",
	"ToggleQuestLog",
}

local function createHandleText(parent, label)
	local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("CENTER")
	text:SetText(label or "Move")
	text:SetTextColor(1, 0.82, 0.18)
	return text
end

function XFrames:GetBlizzMoveSettings()
	local ui = self:GetUISettings()
	return ui and ui.blizzMove
end

function XFrames:IsBlizzMoveEnabled()
	local settings = self:GetBlizzMoveSettings()
	return settings and settings.enabled ~= false
end

function XFrames:GetBlizzMovePosition(key)
	if not key then
		return nil
	end

	local settings = self:GetBlizzMoveSettings()
	if not settings then
		return nil
	end

	settings.positions = settings.positions or {}
	return settings.positions[key]
end

function XFrames:CaptureBlizzMovePosition(frame, key)
	local settings = self:GetBlizzMoveSettings()
	if not settings or not frame or not key then
		return nil
	end

	settings.positions = settings.positions or {}
	local point, _, relativePoint, x, y = frame:GetPoint(1)
	settings.positions[key] = settings.positions[key] or {
		point = point or "CENTER",
		relativePoint = relativePoint or point or "CENTER",
		x = x or 0,
		y = y or 0,
	}
	return settings.positions[key]
end

function XFrames:ApplyBlizzMovePosition(frame)
	if not frame or not frame.xfPosition or not self:IsBlizzMoveEnabled() then
		return
	end

	if InCombatLockdown and InCombatLockdown() then
		frame.xfPendingPositionApply = true
		self.pendingBlizzMovePosition = true
		return
	end

	frame.xfPendingPositionApply = nil
	self:ApplyStoredPosition(frame, frame.xfPosition)
	if type(frame.SetUserPlaced) == "function" then
		pcall(frame.SetUserPlaced, frame, true)
	end
end

function XFrames:RefreshBlizzMoveHandles()
	local unlocked = self:IsFramesUnlocked()
	local enabled = self:IsBlizzMoveEnabled()
	local visible = unlocked and enabled

	for _, frame in pairs(self.blizzMoveFrames or {}) do
		if frame and frame.xfBlizzMoveHandle then
			frame.xfBlizzMoveHandle:SetShown(visible)
			frame.xfBlizzMoveHandle:EnableMouse(visible)
		end
	end
end

function XFrames:ApplyDeferredBlizzMovePosition()
	for _, frame in pairs(self.blizzMoveFrames or {}) do
		if frame and frame.xfPendingPositionApply then
			self:ApplyBlizzMovePosition(frame)
		end
	end
end

function XFrames:RegisterBlizzMoveFrame(frame, key, label)
	if not frame or frame.xfBlizzMoveRegistered then
		return
	end

	self.blizzMoveFrames = self.blizzMoveFrames or {}

	frame.xfBlizzMoveRegistered = true
	frame.xfBlizzMoveKey = key
	local storedPosition = self:GetBlizzMovePosition(key)
	frame.xfPosition = storedPosition or self:CaptureBlizzMovePosition(frame, key)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)

	local handle = CreateFrame("Button", nil, frame)
	handle:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -6)
	handle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, -6)
	handle:SetHeight(20)
	handle:SetFrameStrata("DIALOG")
	handle:SetFrameLevel(frame:GetFrameLevel() + 20)
	handle:RegisterForDrag("LeftButton")
	handle.text = createHandleText(handle, label)
	handle:Hide()

	handle:SetScript("OnDragStart", function()
		if not XFrames:IsBlizzMoveEnabled() or not XFrames:IsFramesUnlocked() then
			return
		end
		if InCombatLockdown and InCombatLockdown() then
			return
		end

		frame:StartMoving()
	end)

	handle:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		if type(frame.SetUserPlaced) == "function" then
			pcall(frame.SetUserPlaced, frame, true)
		end
		XFrames:SaveFramePosition(frame)
	end)

	frame.xfBlizzMoveHandle = handle
	frame:HookScript("OnShow", function(shownFrame)
		XFrames:ApplyBlizzMovePosition(shownFrame)
		XFrames:RefreshBlizzMoveHandles()
	end)

	self.blizzMoveFrames[key] = frame
	if storedPosition then
		self:ApplyBlizzMovePosition(frame)
	end
	self:RefreshBlizzMoveHandles()
end

function XFrames:SyncBlizzMoveFrames()
	for _, spec in ipairs(WINDOW_SPECS) do
		local frame = _G[spec.name]
		if frame then
			self:RegisterBlizzMoveFrame(frame, spec.key, spec.label)
		end
	end

	for index = 1, BAG_FRAME_COUNT do
		local name = "ContainerFrame" .. index
		local frame = _G[name]
		if frame then
			self:RegisterBlizzMoveFrame(frame, name, "Bag " .. index)
		end
	end

	self:RefreshBlizzMoveHandles()
end

function XFrames:SetBlizzMoveEnabled(enabled)
	local settings = self:GetBlizzMoveSettings()
	if not settings then
		return
	end

	settings.enabled = not not enabled
	self:Info(string.format("Blizzard window moving %s", settings.enabled and "enabled" or "disabled"))
	self:SyncBlizzMoveFrames()
	self:RefreshSettingsPanel()
end

function XFrames:ToggleBlizzMove()
	self:SetBlizzMoveEnabled(not self:IsBlizzMoveEnabled())
end

function XFrames:InitializeBlizzMove()
	if self.blizzMoveInitialized then
		self:SyncBlizzMoveFrames()
		return
	end

	self.blizzMoveInitialized = true
	self.blizzMoveFrames = self.blizzMoveFrames or {}

	for _, functionName in ipairs(OPEN_HOOKS) do
		if _G[functionName] then
			hooksecurefunc(functionName, function()
				XFrames:SyncBlizzMoveFrames()
			end)
		end
	end

	self:SyncBlizzMoveFrames()
end
