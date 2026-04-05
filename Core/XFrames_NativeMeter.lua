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
local GetSpecialization = GetSpecialization
local GetSpecializationRole = GetSpecializationRole
local ipairs = ipairs
local pcall = pcall
local rawequal = rawequal
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

local function getSourceRate(source)
	if type(source) ~= "table" then
		return nil
	end

	return source.amountPerSecond or source.rate or source.totalAmount
end

local function getSourceRank(source)
	if type(source) ~= "table" then
		return nil
	end

	local rank = tonumber(source.rank or source.order or source.position or source.displayOrder or source.displayIndex)
	if not rank or rank < 1 then
		return nil
	end

	return rank
end

local function canCompareValue(value)
	if value == nil then
		return false
	end

	if canaccessvalue then
		return canaccessvalue(value)
	end

	if issecretvalue then
		return not issecretvalue(value)
	end

	return true
end

local function getSafeSourceField(source, ...)
	if type(source) ~= "table" then
		return nil
	end

	for index = 1, select("#", ...) do
		local key = select(index, ...)
		local value = source[key]
		if value ~= nil and canCompareValue(value) then
			return value
		end
	end

	return nil
end

local function getComparableNumber(value)
	if not canCompareValue(value) then
		return nil
	end

	return tonumber(value)
end

local function getSourceIdentity(source)
	if type(source) ~= "table" then
		return nil
	end

	return getSafeSourceField(source, "sourceGUID", "guid", "unitGUID", "id", "unitToken")
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

	local player = self:GetModule("Player")
	if player and type(player.Refresh) == "function" then
		player:Refresh()
	end

	self:RefreshSettingsPanel()
end

function XFrames:GetPerformanceMetricForUnit(unit)
	if not unit or not UnitExists(unit) then
		return nil, nil
	end

	local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
	if (not role or role == "NONE") and unit == "player" and GetSpecializationRole and GetSpecialization then
		role = GetSpecializationRole(GetSpecialization())
	end
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

function XFrames:IsNativeMeterAvailable()
	if not (C_DamageMeter and C_DamageMeter.IsDamageMeterAvailable) then
		return nil
	end

	local now = GetTime and GetTime() or 0
	local cache = self.nativeMeterCache
	if not cache or now >= (cache.expiresAt or 0) then
		cache = {
			expiresAt = now + METER_CACHE_TTL,
			available = C_DamageMeter.IsDamageMeterAvailable(),
		}
		self.nativeMeterCache = cache
	end

	return cache.available
end

function XFrames:GetNativeMeterContext(meterType)
	local enumMeterType = meterType
	if Enum and Enum.DamageMeterType then
		if meterType == DAMAGE_METER_TYPE_DPS and Enum.DamageMeterType.Dps then
			enumMeterType = Enum.DamageMeterType.Dps
		elseif meterType == DAMAGE_METER_TYPE_HPS and Enum.DamageMeterType.Hps then
			enumMeterType = Enum.DamageMeterType.Hps
		end
	end

	local currentSessionType = DAMAGE_METER_SESSION_CURRENT
	local totalSessionType = DAMAGE_METER_SESSION_TOTAL
	if Enum and Enum.DamageMeterSessionType then
		currentSessionType = Enum.DamageMeterSessionType.Current or currentSessionType
		totalSessionType = Enum.DamageMeterSessionType.Overall or totalSessionType
	end

	return enumMeterType, currentSessionType, totalSessionType
end

function XFrames:GetNativeMeterView(sessionType, meterType)
	if not self:IsNativeMeterAvailable() or not (C_DamageMeter and C_DamageMeter.GetCombatSessionFromType) then
		return nil
	end

	local cache = self.nativeMeterCache or {}
	cache.views = cache.views or {}
	self.nativeMeterCache = cache

	local enumMeterType = meterType
	local currentSessionType, totalSessionType
	enumMeterType, currentSessionType, totalSessionType = self:GetNativeMeterContext(meterType)
	if sessionType == DAMAGE_METER_SESSION_CURRENT then
		sessionType = currentSessionType
	elseif sessionType == DAMAGE_METER_SESSION_TOTAL then
		sessionType = totalSessionType
	end

	local cacheKey = tostring(sessionType) .. ":" .. tostring(enumMeterType)
	if cache.views[cacheKey] ~= nil then
		return cache.views[cacheKey] or nil
	end

	local ok, view = pcall(C_DamageMeter.GetCombatSessionFromType, sessionType, enumMeterType)
	cache.views[cacheKey] = ok and view or false
	return cache.views[cacheKey] or nil
end

function XFrames:GetNativeMeterSourceForUnit(unit, meterType)
	if not unit or not meterType or not UnitExists(unit) or not self:IsNativeMeterAvailable() then
		return nil
	end

	local enumMeterType, currentSessionType, totalSessionType = self:GetNativeMeterContext(meterType)

	if InCombatLockdown and InCombatLockdown() and C_DamageMeter.GetCurrentCombatSessionSource then
		local ok, source = pcall(C_DamageMeter.GetCurrentCombatSessionSource, enumMeterType, unit)
		if ok and type(source) == "table" then
			return source
		end
	end

	local unitGUID = UnitGUID(unit)
	local unitCreatureID = getCreatureIDFromGUID(unitGUID)
	if not unitGUID or not C_DamageMeter.GetCombatSessionSourceFromType then
		return nil
	end

	local sessionType = self:GetMeterSessionType()
	if sessionType == DAMAGE_METER_SESSION_CURRENT then
		sessionType = currentSessionType
	else
		sessionType = totalSessionType
	end

	local ok, source = pcall(C_DamageMeter.GetCombatSessionSourceFromType, sessionType, enumMeterType, unitGUID, unitCreatureID)
	if ok and type(source) == "table" then
		return source
	end

	if sessionType ~= currentSessionType then
		ok, source = pcall(C_DamageMeter.GetCombatSessionSourceFromType, currentSessionType, enumMeterType, unitGUID, unitCreatureID)
		if ok and type(source) == "table" then
			return source
		end
	end

	return nil
end

function XFrames:GetPerformanceRankForUnit(unit)
	local meterType = self:GetPerformanceMetricForUnit(unit)
	if not meterType then
		return nil
	end

	local source = self:GetNativeMeterSourceForUnit(unit, meterType)
	if not source then
		return nil
	end

	local directRank = getSourceRank(source)
	if directRank then
		return directRank
	end

	local sessionType = self:GetMeterSessionType()
	local view = self:GetNativeMeterView(sessionType, meterType)
	if not view and sessionType ~= DAMAGE_METER_SESSION_CURRENT then
		view = self:GetNativeMeterView(DAMAGE_METER_SESSION_CURRENT, meterType)
	end
	if not view or type(view) ~= "table" or type(view.combatSources) ~= "table" then
		return nil
	end

	local unitGUID = UnitGUID(unit)
	local unitName = UnitName(unit)
	local unitCreatureID = getCreatureIDFromGUID(unitGUID)
	local sourceIdentity = getSourceIdentity(source)
	local sourceRate = getComparableNumber(getSourceRate(source))
	local sourceClass = getSafeSourceField(source, "classFilename", "class")
	local sourceClassification = getSafeSourceField(source, "classification")
	local sourceRecapID = getComparableNumber(getSafeSourceField(source, "deathRecapID"))
	local sourceIsLocalPlayer = source.isLocalPlayer == true

	for index, candidate in ipairs(view.combatSources) do
		if type(candidate) == "table" then
			if unit == "player" and candidate.isLocalPlayer then
				return index
			end

				if rawequal(candidate, source) then
					return index
				end

				local candidateIdentity = getSourceIdentity(candidate)
				if sourceIdentity and canCompareValue(candidateIdentity) and candidateIdentity == sourceIdentity then
					return index
				end

				local candidateGUID = getSafeSourceField(candidate, "sourceGUID", "guid", "unitGUID", "unitToken")
				if unitGUID and canCompareValue(candidateGUID) and candidateGUID == unitGUID then
					return index
				end

			local candidateCreatureID = candidate.sourceCreatureID or candidate.creatureID or candidate.npcID
			if unitCreatureID and canCompareValue(candidateCreatureID) and tonumber(candidateCreatureID) == unitCreatureID then
				return index
			end

			local candidateName = candidate.name or candidate.unitName or candidate.sourceName
			if unitName and canCompareValue(candidateName) and candidateName == unitName then
				return index
			end

			local candidateRate = getComparableNumber(getSourceRate(candidate))
			local candidateClass = canCompareValue(candidate.classFilename) and candidate.classFilename or nil
			if sourceRate and candidateRate and sourceRate == candidateRate then
				if sourceIsLocalPlayer and candidate.isLocalPlayer then
					return index
				end

				if sourceClass and candidateClass and sourceClass == candidateClass then
					return index
				end
			end

			local candidateClassification = getSafeSourceField(candidate, "classification")
			local candidateRecapID = getComparableNumber(getSafeSourceField(candidate, "deathRecapID"))
			if sourceClass and candidateClass and sourceClass == candidateClass then
				if sourceIsLocalPlayer == (candidate.isLocalPlayer == true) then
					if sourceClassification and candidateClassification and sourceClassification == candidateClassification then
						return index
					end

					if sourceRecapID and candidateRecapID and sourceRecapID == candidateRecapID then
						return index
					end
				end
			end
		end
	end

	return nil
end

function XFrames:GetPerformanceRankText(unit)
	local rank = self:GetPerformanceRankForUnit(unit)
	if not rank then
		return ""
	end

	return string.format("#%d", rank)
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
