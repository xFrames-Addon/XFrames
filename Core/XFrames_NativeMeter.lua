local _, ns = ...

local XFrames = ns.XFrames

local DAMAGE_METER_SESSION_TOTAL = 0
local DAMAGE_METER_SESSION_CURRENT = 1
local DAMAGE_METER_TYPE_DPS = 1
local DAMAGE_METER_TYPE_HPS = 3
local METER_CACHE_TTL = 0.5

local function debugMeterTrace(self, unit, stage, detail)
	if not self or not self.IsDebugEnabled or not self:IsDebugEnabled() then
		return
	end

	self.nativeMeterDebugSeen = self.nativeMeterDebugSeen or {}
	local key = table.concat({ tostring(unit or "nil"), tostring(stage or "stage"), tostring(detail or "") }, "|")
	if self.nativeMeterDebugSeen[key] then
		return
	end

	self.nativeMeterDebugSeen[key] = true
	self:Debug(string.format("meter %s %s%s", tostring(unit or "nil"), tostring(stage or "stage"), detail and detail ~= "" and (": " .. tostring(detail)) or ""))
end

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
	self.nativeMeterDebugSeen = nil
end

function XFrames:GetPartySubtitleMode()
	return self.db and self.db.profile and self.db.profile.party and self.db.profile.party.subtitleMode or "status"
end

function XFrames:GetOutOfCombatMeterMode()
	return self.db and self.db.profile and self.db.profile.party and self.db.profile.party.outOfCombatMeterMode or "segment"
end

function XFrames:SetOutOfCombatMeterMode(mode)
	if mode ~= "segment" and mode ~= "overall" then
		self:Warn(string.format("Unknown out-of-combat meter mode: %s", tostring(mode)))
		return
	end

	if not (self.db and self.db.profile and self.db.profile.party) then
		return
	end

	self.db.profile.party.outOfCombatMeterMode = mode
	self:Info(string.format("Out-of-combat meter mode set to %s", mode))
	self:InvalidateMeterCache()

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

function XFrames:GetLatestCompletedMeterSessionID()
	if not self:IsNativeMeterAvailable() or not (C_DamageMeter and C_DamageMeter.GetAvailableCombatSessions) then
		return nil
	end

	local cache = self.nativeMeterCache or {}
	cache.latestCompletedSession = cache.latestCompletedSession or {}
	self.nativeMeterCache = cache

	if cache.latestCompletedSession.id ~= nil then
		return cache.latestCompletedSession.id or nil
	end

	local ok, sessions = pcall(C_DamageMeter.GetAvailableCombatSessions)
	if not ok or type(sessions) ~= "table" then
		cache.latestCompletedSession.id = false
		return nil
	end

	local latestSessionID
	for _, sessionInfo in ipairs(sessions) do
		local sessionID = sessionInfo and sessionInfo.sessionID
		if type(sessionID) == "number" and (not latestSessionID or sessionID > latestSessionID) then
			latestSessionID = sessionID
		end
	end

	cache.latestCompletedSession.id = latestSessionID or false
	return latestSessionID
end

function XFrames:GetCompletedMeterView(meterType)
	if not self:IsNativeMeterAvailable() then
		return nil
	end

	local sessionID = self:GetLatestCompletedMeterSessionID()
	if not sessionID or not (C_DamageMeter and C_DamageMeter.GetCombatSessionFromID) then
		return nil
	end

	local cache = self.nativeMeterCache or {}
	cache.completedViews = cache.completedViews or {}
	self.nativeMeterCache = cache

	local enumMeterType = meterType
	if Enum and Enum.DamageMeterType then
		if meterType == DAMAGE_METER_TYPE_DPS and Enum.DamageMeterType.Dps then
			enumMeterType = Enum.DamageMeterType.Dps
		elseif meterType == DAMAGE_METER_TYPE_HPS and Enum.DamageMeterType.Hps then
			enumMeterType = Enum.DamageMeterType.Hps
		end
	end

	local cacheKey = tostring(sessionID) .. ":" .. tostring(enumMeterType)
	if cache.completedViews[cacheKey] ~= nil then
		return cache.completedViews[cacheKey] or nil
	end

	local ok, view = pcall(C_DamageMeter.GetCombatSessionFromID, sessionID, enumMeterType)
	cache.completedViews[cacheKey] = ok and view or false
	return cache.completedViews[cacheKey] or nil
end

function XFrames:GetNativeMeterSourceForUnit(unit, meterType)
	if not unit or not meterType or not UnitExists(unit) or not self:IsNativeMeterAvailable() then
		return nil
	end

	local enumMeterType, currentSessionType, totalSessionType = self:GetNativeMeterContext(meterType)
	local unitGUID = UnitGUID(unit)
	local unitCreatureID = getCreatureIDFromGUID(unitGUID)

	if InCombatLockdown and InCombatLockdown() and C_DamageMeter.GetCurrentCombatSessionSource then
		local ok, source = pcall(C_DamageMeter.GetCurrentCombatSessionSource, enumMeterType, unit)
		if ok and type(source) == "table" then
			return source
		end
	end

	if not unitGUID or not C_DamageMeter.GetCombatSessionSourceFromType then
		return nil
	end

	if not (InCombatLockdown and InCombatLockdown()) and self:GetOutOfCombatMeterMode() == "segment" and C_DamageMeter.GetCombatSessionSourceFromID then
		local sessionID = self:GetLatestCompletedMeterSessionID()
		if sessionID then
			local ok, source = pcall(C_DamageMeter.GetCombatSessionSourceFromID, sessionID, enumMeterType, unitGUID)
			if ok and type(source) == "table" then
				return source
			end
			if unitCreatureID then
				ok, source = pcall(C_DamageMeter.GetCombatSessionSourceFromID, sessionID, enumMeterType, unitGUID, unitCreatureID)
				if ok and type(source) == "table" then
					return source
				end
			end
		end
	end

	local sessionType = currentSessionType
	local ok, source = pcall(C_DamageMeter.GetCombatSessionSourceFromType, sessionType, enumMeterType, unitGUID)
	if ok and type(source) == "table" then
		return source
	end
	if unitCreatureID then
		ok, source = pcall(C_DamageMeter.GetCombatSessionSourceFromType, sessionType, enumMeterType, unitGUID, unitCreatureID)
		if ok and type(source) == "table" then
			return source
		end
	end

	if totalSessionType and totalSessionType ~= currentSessionType then
		ok, source = pcall(C_DamageMeter.GetCombatSessionSourceFromType, totalSessionType, enumMeterType, unitGUID)
		if ok and type(source) == "table" then
			return source
		end
		if unitCreatureID then
			ok, source = pcall(C_DamageMeter.GetCombatSessionSourceFromType, totalSessionType, enumMeterType, unitGUID, unitCreatureID)
			if ok and type(source) == "table" then
				return source
			end
		end
	end

	local view
	if InCombatLockdown and InCombatLockdown() then
		view = self:GetNativeMeterView(DAMAGE_METER_SESSION_CURRENT, meterType)
	elseif self:GetOutOfCombatMeterMode() == "overall" then
		view = self:GetNativeMeterView(DAMAGE_METER_SESSION_TOTAL, meterType)
	else
		view = self:GetCompletedMeterView(meterType)
	end
	if type(view) == "table" and type(view.combatSources) == "table" then
		if unit == "player" then
			for _, candidate in ipairs(view.combatSources) do
				if type(candidate) == "table" and candidate.isLocalPlayer then
					return candidate
				end
			end
		end
	end

	return nil
end

function XFrames:GetPerformanceRankForUnit(unit)
	local meterType = self:GetPerformanceMetricForUnit(unit)
	if not meterType then
		return nil
	end

	if InCombatLockdown and InCombatLockdown() then
		return nil
	end

	local mode = self:GetOutOfCombatMeterMode()
	local view
	if mode == "overall" then
		view = self:GetNativeMeterView(DAMAGE_METER_SESSION_TOTAL, meterType)
	else
		view = self:GetCompletedMeterView(meterType)
	end
	if not view or type(view) ~= "table" or type(view.combatSources) ~= "table" then
		return nil
	end

	local enumMeterType = self:GetNativeMeterContext(meterType)
	local unitGUID = UnitGUID(unit)
	local unitCreatureID = getCreatureIDFromGUID(unitGUID)
	local source
	if unitGUID and C_DamageMeter then
		if mode == "overall" and C_DamageMeter.GetCombatSessionSourceFromType then
			local _, _, totalSessionType = self:GetNativeMeterContext(meterType)
			local ok, resolvedSource = pcall(C_DamageMeter.GetCombatSessionSourceFromType, totalSessionType, enumMeterType, unitGUID, unitCreatureID)
			if ok and type(resolvedSource) == "table" then
				source = resolvedSource
			end
		elseif mode ~= "overall" and C_DamageMeter.GetCombatSessionSourceFromID then
			local sessionID = self:GetLatestCompletedMeterSessionID()
			if sessionID then
				local ok, resolvedSource = pcall(C_DamageMeter.GetCombatSessionSourceFromID, sessionID, enumMeterType, unitGUID, unitCreatureID)
				if ok and type(resolvedSource) == "table" then
					source = resolvedSource
				end
			end
		end
	end

	if not source and unit == "player" then
		for _, candidate in ipairs(view.combatSources) do
			if type(candidate) == "table" and candidate.isLocalPlayer then
				source = candidate
				break
			end
		end
	end

	if not source then
		return nil
	end

	local directRank = getSourceRank(source)
	if directRank then
		return directRank
	end

	local unitName = UnitName(unit)
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

	local allowCompact = not (InCombatLockdown and InCombatLockdown()) and canCompareValue(value)
	if allowCompact and type(self.FormatCompactNumber) == "function" then
		local ok, compactValue = pcall(self.FormatCompactNumber, self, value)
		if ok and compactValue and compactValue ~= "" then
			local okText, compactText = pcall(string.format, "%s %s", compactValue, label)
			if okText then
				return compactText
			end
		end
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
	if source then
		local formattedText = self:FormatNativeMeterText(getSourceRate(source), label)
		if formattedText then
			return formattedText
		end
	end

	if type(self.GetMeterTextForUnit) == "function" then
		local ok, fallbackText = pcall(self.GetMeterTextForUnit, self, unit, meterType, label)
		if ok and fallbackText then
			return fallbackText
		end
	end

	return nil
end
function XFrames.events:DAMAGE_METER_CURRENT_SESSION_UPDATED()
	XFrames:InvalidateMeterCache()
end

function XFrames.events:DAMAGE_METER_COMBAT_SESSION_UPDATED()
	XFrames:InvalidateMeterCache()
end

XFrames:RegisterEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
XFrames:RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED")
