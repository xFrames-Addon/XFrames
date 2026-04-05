local _, ns = ...

local XFrames = ns.XFrames

local DAMAGE_METER_SESSION_TOTAL = 0
local DAMAGE_METER_SESSION_CURRENT = 1
local DAMAGE_METER_TYPE_DPS = 1
local DAMAGE_METER_TYPE_HPS = 3
local METER_CACHE_TTL = 0.5

local GetTime = GetTime
local InCombatLockdown = InCombatLockdown
local UnitExists = UnitExists
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitGUID = UnitGUID
local UnitName = UnitName
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local string = string
local tonumber = tonumber
local type = type

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

local function getSourceGUID(source)
	if type(source) ~= "table" then
		return nil
	end

	return source.sourceGUID or source.guid or source.unitToken
end

local function getSourceName(source)
	if type(source) ~= "table" then
		return nil
	end

	return source.name or source.unitName or source.sourceName
end

local function getSourceCreatureID(source)
	if type(source) ~= "table" then
		return nil
	end

	return tonumber(source.sourceCreatureID or source.creatureID or source.npcID)
end

local function getSourceRate(source)
	if type(source) ~= "table" then
		return nil
	end

	return source.amountPerSecond or source.rate
end

function XFrames:InvalidateMeterCache()
	self.nativeMeterCache = nil
end

function XFrames:GetPartySubtitleMode()
	return self.db and self.db.profile and self.db.profile.party and self.db.profile.party.subtitleMode or "status"
end

function XFrames:SetPartySubtitleMode(mode)
	if mode ~= "status" and mode ~= "performance" then
		self:Warn(string.format("Unknown party subtitle mode: %s", tostring(mode)))
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

function XFrames:GetMeterSessionType()
	if InCombatLockdown and InCombatLockdown() then
		return DAMAGE_METER_SESSION_CURRENT
	end

	return DAMAGE_METER_SESSION_TOTAL
end

function XFrames:GetNativeMeterView(sessionType, meterType)
	if not (C_DamageMeter and C_DamageMeter.IsDamageMeterAvailable and C_DamageMeter.GetCombatSessionFromType) then
		return nil
	end

	local now = GetTime and GetTime() or 0
	local cache = self.nativeMeterCache
	if not cache or now >= (cache.expiresAt or 0) then
		cache = {
			expiresAt = now + METER_CACHE_TTL,
			views = {},
			available = C_DamageMeter.IsDamageMeterAvailable(),
		}
		self.nativeMeterCache = cache
	end

	if not cache.available then
		return nil
	end

	local cacheKey = tostring(sessionType) .. ":" .. tostring(meterType)
	if cache.views[cacheKey] ~= nil then
		return cache.views[cacheKey] or nil
	end

	local ok, view = pcall(C_DamageMeter.GetCombatSessionFromType, sessionType, meterType)
	cache.views[cacheKey] = ok and view or false
	return cache.views[cacheKey] or nil
end

function XFrames:GetNativeMeterSourceForUnit(unit, meterType)
	if not unit or not meterType or not UnitExists(unit) then
		return nil
	end

	local sessionType = self:GetMeterSessionType()
	local view = self:GetNativeMeterView(sessionType, meterType)
	if not view and sessionType ~= DAMAGE_METER_SESSION_CURRENT then
		view = self:GetNativeMeterView(DAMAGE_METER_SESSION_CURRENT, meterType)
	end
	if not view or type(view) ~= "table" then
		return nil
	end

	local sources = view.combatSources
	if type(sources) ~= "table" then
		return nil
	end

	local unitGUID = UnitGUID(unit)
	local unitName = UnitName(unit)
	local unitCreatureID = getCreatureIDFromGUID(unitGUID)
	local creatureMatch
	local nameMatch

	for _, source in pairs(sources) do
		if type(source) == "table" then
			local sourceGUID = getSourceGUID(source)
			if unitGUID and sourceGUID and sourceGUID == unitGUID then
				return source
			end

			local sourceCreatureID = getSourceCreatureID(source)
			if not creatureMatch and unitCreatureID and sourceCreatureID and sourceCreatureID == unitCreatureID then
				creatureMatch = source
			end

			local sourceName = getSourceName(source)
			if not nameMatch and unitName and sourceName and sourceName == unitName then
				nameMatch = source
			end
		end
	end

	return creatureMatch or nameMatch
end

function XFrames:FormatNativeMeterText(value, label)
	if value == nil or not label then
		return nil
	end

	local ok, displayText = pcall(string.format, "%.0f %s", value, label)
	if ok then
		return displayText
	end

	ok, displayText = pcall(string.format, "%s %s", value, label)
	if ok then
		return displayText
	end

	return nil
end

function XFrames:GetPerformanceTextForUnit(unit)
	local meterType, label = self:GetPerformanceMetricForUnit(unit)
	if not meterType or not label then
		return nil
	end

	local source = self:GetNativeMeterSourceForUnit(unit, meterType)
	if not source then
		return nil
	end

	return self:FormatNativeMeterText(getSourceRate(source), label)
end

function XFrames.events:DAMAGE_METER_CURRENT_SESSION_UPDATED()
	XFrames:InvalidateMeterCache()
end

function XFrames.events:DAMAGE_METER_COMBAT_SESSION_UPDATED()
	XFrames:InvalidateMeterCache()
end

XFrames:RegisterEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
XFrames:RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED")
