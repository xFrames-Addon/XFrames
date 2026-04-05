local addonName, ns = ...

local XFrames = CreateFrame("Frame")
ns.XFrames = XFrames

XFrames.name = addonName
XFrames.modules = {}
XFrames.events = {}

local InCombatLockdown = InCombatLockdown
local date = date
local geterrorhandler = geterrorhandler
local ReloadUI = ReloadUI
local pairs = pairs
local select = select
local string = string
local tostring = tostring
local tinsert = table.insert
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitIsPlayer = UnitIsPlayer
local UnitPowerType = UnitPowerType
local UnitSelectionColor = UnitSelectionColor

local DEFAULT_POWER_BAR_COLOR = {r = 0.24, g = 0.28, b = 0.36}
local DEFAULT_UNIT_ACCENT_COLOR = {r = 0.24, g = 0.27, b = 0.31}
local POWER_LABELS = {
	MANA = "Mana",
	RAGE = "Rage",
	FOCUS = "Focus",
	ENERGY = "Energy",
	COMBO_POINTS = "Combo",
	RUNES = "Runes",
	RUNIC_POWER = "Runic",
	SOUL_SHARDS = "Shards",
	LUNAR_POWER = "Astral",
	HOLY_POWER = "Holy",
	MAELSTROM = "Maelstrom",
	CHI = "Chi",
	INSANITY = "Insanity",
	ARCANE_CHARGES = "Arcane",
	FURY = "Fury",
	PAIN = "Pain",
	ESSENCE = "Essence",
}

local function printf(...)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(string.format(...))
	end
end

local function trim(msg)
	return msg and msg:match("^%s*(.-)%s*$") or ""
end

local function safeToString(value)
	if value == nil then
		return "nil"
	end

	return tostring(value)
end

function XFrames:RegisterModule(name, module)
	if not name or not module then
		return
	end

	module.name = name
	self.modules[name] = module
end

function XFrames:GetModule(name)
	return self.modules[name]
end

function XFrames:GetDiagnostics()
	return self.db and self.db.profile and self.db.profile.diagnostics
end

function XFrames:IsDebugEnabled()
	return self.db and self.db.profile and self.db.profile.debug
end

function XFrames:AddLog(level, message)
	local diagnostics = self:GetDiagnostics()
	if not diagnostics then
		return
	end

	local logs = diagnostics.logs
	local entry = {
		time = date("%H:%M:%S"),
		level = level,
		message = safeToString(message),
	}

	tinsert(logs, entry)

	local limit = diagnostics.logLimit or 200
	while #logs > limit do
		table.remove(logs, 1)
	end

	if self:IsDebugEnabled() or level == "ERROR" or level == "WARN" then
		printf("|cff33ff99XFrames|r [%s] %s", level, entry.message)
	end
end

function XFrames:Debug(message)
	self:AddLog("DEBUG", message)
end

function XFrames:Info(message)
	self:AddLog("INFO", message)
end

function XFrames:Warn(message)
	self:AddLog("WARN", message)
end

function XFrames:Error(message)
	self:AddLog("ERROR", message)
end

function XFrames:HandleError(scope, err)
	local message = string.format("%s failed: %s", scope or "XFrames", safeToString(err))
	self:Error(message)

	local handler = geterrorhandler()
	if handler then
		handler(message)
	end
end

function XFrames:SafeCall(scope, fn, ...)
	if type(fn) ~= "function" then
		return false
	end

	local args = {...}
	return xpcall(function()
		return fn(unpack(args))
	end, function(err)
		self:HandleError(scope, err)
	end)
end

function XFrames:ForEachModule(method)
	for _, module in pairs(self.modules) do
		if type(module[method]) == "function" then
			self:SafeCall(string.format("module %s:%s", module.name or "unknown", method), module[method], module, self)
		end
	end
end

function XFrames:Initialize()
	if self.initialized then
		return
	end

	self.initialized = true
	self:InitializeDatabase()
	self:Info("Initializing addon core")
	self:ForEachModule("Initialize")
	self:RegisterSlashCommands()
end

function XFrames:SetDebugEnabled(enabled)
	self.db.profile.debug = not not enabled
	self:Info(string.format("Debug mode %s", self.db.profile.debug and "enabled" or "disabled"))
	if self.db.profile.debug then
		self:ApplyDiagnosticCVars()
	end
end

function XFrames:TrySetCVar(name, value)
	local setter = C_CVar and C_CVar.SetCVar or SetCVar
	if not setter then
		self:Warn(string.format("No CVar setter available for %s", name))
		return false
	end

	if InCombatLockdown and InCombatLockdown() then
		self.pendingDiagnosticCVars = true
		self:Warn(string.format("Deferred setting CVar %s until out of combat", name))
		return false
	end

	local ok = setter(name, value)
	if ok == nil or ok == false then
		self:Warn(string.format("Unable to set CVar %s to %s", name, safeToString(value)))
		return false
	end

	self:Debug(string.format("Set CVar %s=%s", name, safeToString(value)))
	return true
end

function XFrames:ApplyDiagnosticCVars()
	local diagnostics = self:GetDiagnostics()
	if not diagnostics or not diagnostics.autoEnableCVars or not self:IsDebugEnabled() then
		return
	end

	self:TrySetCVar("scriptErrors", "1")
	self:TrySetCVar("taintLog", diagnostics.taintLogLevel or "5")
end

function XFrames:DumpLogs(count)
	local diagnostics = self:GetDiagnostics()
	if not diagnostics then
		return
	end

	local logs = diagnostics.logs or {}
	local total = #logs
	local limit = tonumber(count) or 20
	local startIndex = math.max(1, total - limit + 1)

	if total == 0 then
		printf("|cff33ff99XFrames|r no diagnostic log entries yet")
		return
	end

	for index = startIndex, total do
		local entry = logs[index]
		printf("|cff33ff99XFrames|r [%s] [%s] %s", entry.time or "??:??:??", entry.level or "INFO", entry.message or "")
	end
end

function XFrames:ClearLogs()
	local diagnostics = self:GetDiagnostics()
	if not diagnostics then
		return
	end

	diagnostics.logs = {}
	printf("|cff33ff99XFrames|r diagnostic log cleared")
end

function XFrames:RegisterSlashCommands()
	SLASH_XFRAMES1 = "/xframes"
	SlashCmdList.XFRAMES = function(msg)
		msg = trim(msg):lower()

		local command, arg = msg:match("^(%S+)%s*(.-)$")
		command = command or ""

		if command == "status" or msg == "" then
			printf("|cff33ff99XFrames|r loaded. Modules: %d. Debug: %s. Frames: %s", self:CountModules(), self:IsDebugEnabled() and "on" or "off", self:IsFramesUnlocked() and "unlocked" or "locked")
			return
		end

		if command == "settings" or command == "config" then
			self:ToggleSettings()
			return
		end

		if command == "lock" then
			self:SetFramesUnlocked(false)
			return
		end

		if command == "unlock" then
			self:SetFramesUnlocked(true)
			return
		end

		if command == "toggle" then
			self:ToggleFrameLocks()
			return
		end

		if command == "reload" then
			ReloadUI()
			return
		end

		if command == "debug" then
			arg = trim(arg)
			if arg == "" or arg == "toggle" then
				self:SetDebugEnabled(not self:IsDebugEnabled())
				return
			end
			if arg == "on" then
				self:SetDebugEnabled(true)
				return
			end
			if arg == "off" then
				self:SetDebugEnabled(false)
				return
			end
			if arg == "status" then
				printf("|cff33ff99XFrames|r debug is %s", self:IsDebugEnabled() and "on" or "off")
				return
			end
			if arg:match("^dump") then
				self:DumpLogs(arg:match("^dump%s+(%d+)$"))
				return
			end
			if arg == "clear" then
				self:ClearLogs()
				return
			end
			if arg == "cvars" then
				self:ApplyDiagnosticCVars()
				return
			end
			printf("|cff33ff99XFrames|r debug commands: on, off, toggle, status, dump [count], clear, cvars")
			return
		end

		printf("|cff33ff99XFrames|r commands: status, settings, lock, unlock, toggle, reload, debug")
	end
end

function XFrames:CountModules()
	local count = 0
	for _ in pairs(self.modules) do
		count = count + 1
	end

	return count
end

function XFrames:SetValueText(fontString, value, maxValue)
	if not fontString then
		return
	end

	if value == nil then
		fontString:SetText("")
		return
	end

	if maxValue ~= nil then
		fontString:SetText(string.format("%d / %d", value, maxValue))
		return
	end

	fontString:SetText(string.format("%d", value))
end

function XFrames:SetBarValues(bar, value, maxValue)
	if not bar then
		return
	end

	if maxValue ~= nil then
		bar:SetMinMaxValues(0, maxValue)
	else
		bar:SetMinMaxValues(0, 1)
	end

	bar:SetValue(value or 0)
	self:SetValueText(bar.valueText, value, maxValue)
end

function XFrames:GetUnitPowerPresentation(unit, compact)
	local _, powerToken = UnitPowerType(unit)
	local color = powerToken and PowerBarColor and PowerBarColor[powerToken]
	local label

	if compact then
		label = "PW"
	else
		label = powerToken and POWER_LABELS[powerToken] or "Power"
	end

	return label or "Power", color or DEFAULT_POWER_BAR_COLOR
end

function XFrames:GetUnitAccentColor(unit)
	if not unit or not UnitExists(unit) then
		return DEFAULT_UNIT_ACCENT_COLOR
	end

	if UnitIsPlayer(unit) then
		local _, class = UnitClass(unit)
		local classColor = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
		if classColor then
			return classColor
		end
	end

	local r, g, b = UnitSelectionColor(unit, true)
	if r and g and b then
		return {r = r, g = g, b = b}
	end

	return DEFAULT_UNIT_ACCENT_COLOR
end

function XFrames:CreateAccentFrame(parent, inset, edgeSize)
	if not parent then
		return nil
	end

	local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	frame:SetPoint("TOPLEFT", parent, "TOPLEFT", -(inset or 2), inset or 2)
	frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", inset or 2, -(inset or 2))
	frame:SetFrameLevel(parent:GetFrameLevel() + 3)
	frame:SetBackdrop({
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = edgeSize or 3,
	})
	frame:SetBackdropBorderColor(1, 1, 1, 1)
	frame:SetBackdropColor(0, 0, 0, 0)
	frame:EnableMouse(false)
	return frame
end

function XFrames.events:ADDON_LOADED(loadedAddon)
	if loadedAddon ~= addonName then
		return
	end

	XFrames:Initialize()
end

function XFrames.events:PLAYER_LOGIN()
	XFrames:ApplyDiagnosticCVars()
	XFrames:ForEachModule("Enable")
	XFrames:InitializeUI()
end

function XFrames.events:PLAYER_REGEN_ENABLED()
	if XFrames.pendingDiagnosticCVars then
		XFrames.pendingDiagnosticCVars = nil
		XFrames:ApplyDiagnosticCVars()
	end
end

XFrames:SetScript("OnEvent", function(_, event, ...)
	local handler = XFrames.events[event]
	if handler then
		XFrames:SafeCall(string.format("event %s", event), handler, XFrames.events, ...)
	end
end)

XFrames:RegisterEvent("ADDON_LOADED")
XFrames:RegisterEvent("PLAYER_LOGIN")
XFrames:RegisterEvent("PLAYER_REGEN_ENABLED")
