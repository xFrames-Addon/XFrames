local addonName, ns = ...

local XFrames = CreateFrame("Frame")
ns.XFrames = XFrames
_G.XFrames = XFrames

XFrames.name = addonName
XFrames.modules = {}
XFrames.events = {}

local InCombatLockdown = InCombatLockdown
local date = date
local geterrorhandler = geterrorhandler
local math = math
local pcall = pcall
local ReloadUI = ReloadUI
local ipairs = ipairs
local pairs = pairs
local select = select
local string = string
local tostring = tostring
local tinsert = table.insert
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitGUID = UnitGUID
local UnitIsPlayer = UnitIsPlayer
local UnitIsVisible = UnitIsVisible
local UnitPhaseReason = UnitPhaseReason
local UnitPowerType = UnitPowerType
local UnitSelectionColor = UnitSelectionColor
local SetPortraitTexture = SetPortraitTexture

local DEFAULT_POWER_BAR_COLOR = {r = 0.24, g = 0.28, b = 0.36}
local DEFAULT_UNIT_ACCENT_COLOR = {r = 0.24, g = 0.27, b = 0.31}
local DAMAGE_METER_TYPE_DPS = 1
local DAMAGE_METER_TYPE_HPS = 3
local CLASS_ICON_TEXTURE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
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

local function roundNumber(value)
	return math.floor((value or 0) + 0.5)
end

local function getCreatureIDFromGUID(guid)
	if type(guid) ~= "string" then
		return nil
	end

	local unitType, _, _, _, _, creatureID = strsplit("-", guid)
	if unitType ~= "Creature" and unitType ~= "Vehicle" and unitType ~= "Pet" then
		return nil
	end

	creatureID = tonumber(creatureID)
	if not creatureID or creatureID <= 0 then
		return nil
	end

	return creatureID
end

function XFrames:RegisterModule(name, module)
	if not name or not module then
		return
	end

	module.name = name
	self.modules[name] = module
end

function XFrames:SetTestingPreview(kind, data)
	if kind ~= "party" and kind ~= "raid" then
		return
	end

	self.testingPreview = self.testingPreview or {}

	if type(data) == "table" and next(data) ~= nil then
		self.testingPreview[kind] = data
	else
		self.testingPreview[kind] = nil
	end

	self:RefreshAllFrameLocks()
end

function XFrames:ClearTestingPreview(kind)
	if kind ~= "party" and kind ~= "raid" then
		return
	end

	if self.testingPreview then
		self.testingPreview[kind] = nil
	end

	self:RefreshAllFrameLocks()
end

function XFrames:IsTestingPreviewActive(kind)
	local preview = self.testingPreview and self.testingPreview[kind]
	return type(preview) == "table" and next(preview) ~= nil
end

function XFrames:GetTestingPreviewData(kind, index)
	local preview = self.testingPreview and self.testingPreview[kind]
	if type(preview) ~= "table" then
		return nil
	end

	return preview[index]
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

		if command == "blizzard" then
			arg = trim(arg)
			if arg == "" or arg == "toggle" then
				self:ToggleBlizzardFrames()
				return
			end
			if arg == "hide" or arg == "off" then
				self:SetBlizzardFramesHidden(true)
				return
			end
			if arg == "show" or arg == "on" then
				self:SetBlizzardFramesHidden(false)
				return
			end
			printf("|cff33ff99XFrames|r blizzard commands: hide, show, toggle")
			return
		end

		if command == "castbars" or command == "casts" then
			arg = trim(arg)
			if arg == "" or arg == "toggle" then
				self:ToggleBlizzardCastBars()
				return
			end
			if arg == "hide" or arg == "off" then
				self:SetBlizzardCastBarsHidden(true)
				return
			end
			if arg == "show" or arg == "on" then
				self:SetBlizzardCastBarsHidden(false)
				return
			end
			printf("|cff33ff99XFrames|r castbars commands: hide, show, toggle")
			return
		end

		if command == "portraits" or command == "portrait" then
			arg = trim(arg)
			if arg == "" or arg == "toggle" then
				self:TogglePortraitStyle()
				return
			end
			if arg == "class" or arg == "icons" then
				self:SetPortraitStyle("class")
				return
			end
			if arg == "portrait" or arg == "live" then
				self:SetPortraitStyle("portrait")
				return
			end
			printf("|cff33ff99XFrames|r portrait commands: portrait, class, toggle")
			return
		end

		if command == "reload" then
			ReloadUI()
			return
		end

		if command == "party" then
			arg = trim(arg)
			if arg == "" or arg == "mode" then
				printf("|cff33ff99XFrames|r party subtitle mode: %s", self:GetPartySubtitleMode())
				return
			end
			if arg == "status" then
				self:SetPartySubtitleMode("status")
				return
			end
			if arg == "performance" or arg == "meter" then
				self:SetPartySubtitleMode("performance")
				return
			end
			printf("|cff33ff99XFrames|r party commands: status, performance, mode")
			return
		end

		if command == "raid" then
			arg = trim(arg)
			if arg == "" or arg == "toggle" then
				self:ToggleRaidFramesEnabled()
				return
			end
			if arg == "on" or arg == "enable" then
				self:SetRaidFramesEnabled(true)
				return
			end
			if arg == "off" or arg == "disable" then
				self:SetRaidFramesEnabled(false)
				return
			end
			if arg == "status" then
				printf("|cff33ff99XFrames|r raid frames: %s", self:IsRaidFramesEnabled() and "on" or "off")
				return
			end
			printf("|cff33ff99XFrames|r raid commands: on, off, toggle, status")
			return
		end

		if command == "tanks" or command == "tankframes" then
			arg = trim(arg)
			if arg == "" or arg == "toggle" then
				self:ToggleTankFramesEnabled()
				return
			end
			if arg == "on" or arg == "enable" then
				self:SetTankFramesEnabled(true)
				return
			end
			if arg == "off" or arg == "disable" then
				self:SetTankFramesEnabled(false)
				return
			end
			if arg == "status" then
				printf("|cff33ff99XFrames|r tank frames: %s", self:IsTankFramesEnabled() and "on" or "off")
				return
			end
			printf("|cff33ff99XFrames|r tank commands: on, off, toggle, status")
			return
		end

		if command == "tanktargets" or command == "tanktarget" then
			arg = trim(arg)
			if arg == "" or arg == "toggle" then
				self:ToggleTankTargetsEnabled()
				return
			end
			if arg == "on" or arg == "enable" then
				self:SetTankTargetsEnabled(true)
				return
			end
			if arg == "off" or arg == "disable" then
				self:SetTankTargetsEnabled(false)
				return
			end
			if arg == "status" then
				printf("|cff33ff99XFrames|r tank targets: %s", self:IsTankTargetsEnabled() and "on" or "off")
				return
			end
			printf("|cff33ff99XFrames|r tank target commands: on, off, toggle, status")
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

		printf("|cff33ff99XFrames|r commands: status, settings, lock, unlock, toggle, blizzard, castbars, portraits, party, raid, tanks, tanktargets, reload, debug")
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

function XFrames:FormatCompactNumber(value)
	value = tonumber(value)
	if not value then
		return ""
	end

	local absoluteValue = math.abs(value)
	if absoluteValue >= 1000000 then
		return (string.format("%.1fm", value / 1000000):gsub("%.0m", "m"))
	end
	if absoluteValue >= 1000 then
		return (string.format("%.1fk", value / 1000):gsub("%.0k", "k"))
	end

	return string.format("%d", roundNumber(value))
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

function XFrames:GetPortraitStyle()
	local ui = self:GetUISettings()
	if ui and ui.portraitStyle == "class" then
		return "class"
	end

	return "portrait"
end

function XFrames:SetPortraitStyle(style)
	style = trim(style):lower()
	if style ~= "portrait" and style ~= "class" then
		self:Warn(string.format("Unknown portrait style: %s", safeToString(style)))
		return
	end

	local ui = self:GetUISettings()
	if not ui then
		return
	end

	ui.portraitStyle = style
	self:Info(string.format("Portrait style set to %s", style))
	self:RefreshAllFrameLocks()
end

function XFrames:TogglePortraitStyle()
	if self:GetPortraitStyle() == "class" then
		self:SetPortraitStyle("portrait")
		return
	end

	self:SetPortraitStyle("class")
end

function XFrames:IsRaidFramesEnabled()
	return self.db and self.db.profile and self.db.profile.raid and self.db.profile.raid.enabled ~= false
end

function XFrames:SetRaidFramesEnabled(enabled)
	if not (self.db and self.db.profile and self.db.profile.raid) then
		return
	end

	self.db.profile.raid.enabled = not not enabled
	local raidModule = self:GetModule("Raid")
	if raidModule then
		raidModule.enabled = self.db.profile.raid.enabled
		if self.db.profile.raid.enabled and type(raidModule.Enable) == "function" and not raidModule.anchorFrame then
			raidModule:Enable()
		elseif type(raidModule.RefreshAll) == "function" then
			raidModule:RefreshAll()
		end
	end
	self:Info(string.format("Raid frames %s", self.db.profile.raid.enabled and "enabled" or "disabled"))
	self:ApplyBlizzardFrameVisibility()
	self:RefreshAllFrameLocks()
end

function XFrames:ToggleRaidFramesEnabled()
	self:SetRaidFramesEnabled(not self:IsRaidFramesEnabled())
end

function XFrames:IsTankFramesEnabled()
	return self.db and self.db.profile and self.db.profile.raid and self.db.profile.raid.tanks and self.db.profile.raid.tanks.enabled == true
end

function XFrames:SetTankFramesEnabled(enabled)
	if not (self.db and self.db.profile and self.db.profile.raid and self.db.profile.raid.tanks) then
		return
	end

	self.db.profile.raid.tanks.enabled = not not enabled
	local module = self:GetModule("RaidTanks")
	if module then
		module.enabled = self.db.profile.raid.tanks.enabled
		if self.db.profile.raid.tanks.enabled and type(module.Enable) == "function" and not module.anchorFrame then
			module:Enable()
		elseif type(module.RefreshAll) == "function" then
			module:RefreshAll()
		end
	end

	self:Info(string.format("Tank frames %s", self.db.profile.raid.tanks.enabled and "enabled" or "disabled"))
	self:RefreshAllFrameLocks()
end

function XFrames:ToggleTankFramesEnabled()
	self:SetTankFramesEnabled(not self:IsTankFramesEnabled())
end

function XFrames:IsTankTargetsEnabled()
	return self.db and self.db.profile and self.db.profile.raid and self.db.profile.raid.tanks and self.db.profile.raid.tanks.targets and self.db.profile.raid.tanks.targets.enabled == true
end

function XFrames:SetTankTargetsEnabled(enabled)
	if not (self.db and self.db.profile and self.db.profile.raid and self.db.profile.raid.tanks and self.db.profile.raid.tanks.targets) then
		return
	end

	self.db.profile.raid.tanks.targets.enabled = not not enabled
	local module = self:GetModule("RaidTanks")
	if module and type(module.RefreshAll) == "function" then
		module:RefreshAll()
	end

	self:Info(string.format("Tank targets %s", self.db.profile.raid.tanks.targets.enabled and "enabled" or "disabled"))
	self:RefreshSettingsPanel()
end

function XFrames:ToggleTankTargetsEnabled()
	self:SetTankTargetsEnabled(not self:IsTankTargetsEnabled())
end

function XFrames:ApplyClassIcon(texture, classToken, fallbackTexture)
	if not texture then
		return false
	end

	local coords = classToken and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classToken]
	if coords then
		texture:SetTexture(CLASS_ICON_TEXTURE)
		texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		return true
	end

	texture:SetTexture(fallbackTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
	texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	return false
end

function XFrames:ApplyUnitPortrait(texture, unit, fallbackTexture)
	if not texture then
		return
	end

	if not unit or not UnitExists(unit) then
		texture:SetTexture(fallbackTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
		texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		return
	end

	if self:GetPortraitStyle() == "class" and UnitIsPlayer(unit) then
		local _, classToken = UnitClass(unit)
		if self:ApplyClassIcon(texture, classToken, fallbackTexture) then
			return
		end
	end

	SetPortraitTexture(texture, unit)
	texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
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

function XFrames:IsUnitOutOfRange(unit)
	if not unit or not UnitExists(unit) then
		return false
	end

	if UnitPhaseReason then
		local ok, reason = pcall(UnitPhaseReason, unit)
		if ok and reason ~= nil then
			return true
		end
	end

	if UnitIsVisible then
		local ok, visible = pcall(UnitIsVisible, unit)
		if ok and visible == false then
			return true
		end
	end

	return false
end

function XFrames:FormatSpecLabel(name)
	if name == nil then
		return ""
	end

	local ok, shortName = pcall(string.match, name, "^[^%s]+")
	if ok and shortName then
		return shortName
	end

	ok, shortName = pcall(string.format, "%s", name)
	if ok then
		return shortName
	end

	return ""
end

function XFrames:GetPartySubtitleMode()
	return self.db and self.db.profile and self.db.profile.party and self.db.profile.party.subtitleMode or "status"
end

function XFrames:SetPartySubtitleMode(mode)
	if mode ~= "status" and mode ~= "performance" then
		self:Warn(string.format("Unknown party subtitle mode: %s", safeToString(mode)))
		return
	end

	if not (self.db and self.db.profile and self.db.profile.party) then
		return
	end

	self.db.profile.party.subtitleMode = mode
	self:Info(string.format("Party subtitle mode set to %s", mode))

	local party = self:GetModule("Party")
	if party and type(party.RefreshPerformanceMode) == "function" then
		party:RefreshPerformanceMode()
	end

	self:RefreshSettingsPanel()
end

function XFrames:GetPerformanceMetricForUnit(unit)
	if not unit or not UnitExists(unit) then
		return nil, nil
	end

	local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
	if role == "HEALER" then
		return DAMAGE_METER_TYPE_HPS, "HPS"
	end
	if role == "TANK" or role == "DAMAGER" then
		return DAMAGE_METER_TYPE_DPS, "DPS"
	end

	return nil, nil
end

function XFrames:GetCurrentDamageMeterValue(unit, meterType)
	if not unit or not meterType or not (C_DamageMeter and C_DamageMeter.GetCurrentCombatSession) then
		return nil
	end

	local guid = UnitGUID(unit)
	if not guid then
		return nil
	end

	local ok, session = pcall(C_DamageMeter.GetCurrentCombatSession, meterType)
	if not ok or type(session) ~= "table" then
		return nil
	end

	local sources = session.combatSources
	if type(sources) ~= "table" then
		return nil
	end

	for _, source in ipairs(sources) do
		if source and source.unitToken == guid then
			return source.totalAmount
		end
	end

	return nil
end

function XFrames:GetLatestDamageMeterSessionID()
	if not (C_DamageMeter and C_DamageMeter.GetAvailableCombatSessions) then
		return nil
	end

	local ok, sessions = pcall(C_DamageMeter.GetAvailableCombatSessions)
	if not ok or type(sessions) ~= "table" then
		return nil
	end

	local latestSessionID
	for _, sessionInfo in ipairs(sessions) do
		local sessionID = sessionInfo and sessionInfo.sessionID
		if type(sessionID) == "number" and (not latestSessionID or sessionID > latestSessionID) then
			latestSessionID = sessionID
		end
	end

	return latestSessionID
end

function XFrames:GetCompletedDamageMeterValue(unit, meterType)
	if not unit or not meterType or not (C_DamageMeter and C_DamageMeter.GetCombatSessionSourceFromID) then
		return nil
	end

	local guid = UnitGUID(unit)
	local creatureID = getCreatureIDFromGUID(guid)
	local sessionID = self:GetLatestDamageMeterSessionID()
	if not guid or not sessionID then
		return nil
	end

	local ok, source = pcall(C_DamageMeter.GetCombatSessionSourceFromID, sessionID, meterType, guid, creatureID)
	if not ok or type(source) ~= "table" then
		return nil
	end

	return source.totalAmount
end

function XFrames:FormatMeterValue(value, allowCompact)
	if value == nil then
		return nil
	end

	if allowCompact then
		local ok, compactValue = pcall(self.FormatCompactNumber, self, value)
		if ok then
			return compactValue
		end
	end

	local ok, rawValue = pcall(string.format, "%d", value)
	if ok then
		return rawValue
	end

	return nil
end

function XFrames:GetMeterTextForUnit(unit, meterType, label)
	if not meterType or not label then
		return nil
	end

	local value = self:GetCurrentDamageMeterValue(unit, meterType)
	local allowCompact = false
	if value == nil then
		value = self:GetCompletedDamageMeterValue(unit, meterType)
		allowCompact = true
	end
	if value == nil then
		return nil
	end

	local formattedValue = self:FormatMeterValue(value, allowCompact)
	if formattedValue == nil then
		return nil
	end

	return string.format("%s %s", formattedValue, label)
end

function XFrames:GetPerformanceTextForUnit(unit)
	local meterType, label = self:GetPerformanceMetricForUnit(unit)
	if not meterType or not label then
		return nil
	end

	return self:GetMeterTextForUnit(unit, meterType, label)
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

function XFrames.events:PLAYER_ENTERING_WORLD()
	if XFrames.initialized then
		XFrames:ApplyBlizzardFrameVisibility()
		XFrames:ApplyBlizzardCastBarVisibility()
	end
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
XFrames:RegisterEvent("PLAYER_ENTERING_WORLD")
XFrames:RegisterEvent("PLAYER_REGEN_ENABLED")
