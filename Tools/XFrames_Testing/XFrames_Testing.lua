local addonName = ...

local addon = CreateFrame("Frame")

local floor = math.floor
local tonumber = tonumber
local ipairs = ipairs
local format = string.format

local PARTY_MEMBERS = {
	{name = "Tankard", className = "Warrior", classToken = "WARRIOR", role = "TANK", level = 80, healthMax = 1000000, powerMax = 100, powerColor = {r = 0.78, g = 0.24, b = 0.18}},
	{name = "Mendra", className = "Priest", classToken = "PRIEST", role = "HEALER", level = 80, healthMax = 820000, powerMax = 250000, powerColor = {r = 0.20, g = 0.44, b = 0.86}},
	{name = "Shade", className = "Rogue", classToken = "ROGUE", role = "DAMAGER", level = 80, healthMax = 760000, powerMax = 100, powerColor = {r = 0.95, g = 0.78, b = 0.20}},
	{name = "Ember", className = "Mage", classToken = "MAGE", role = "DAMAGER", level = 80, healthMax = 700000, powerMax = 200000, powerColor = {r = 0.20, g = 0.44, b = 0.86}},
}

local RAID_TEMPLATES = {
	{className = "Warrior", classToken = "WARRIOR", role = "TANK", healthMax = 1000000, powerMax = 100, powerColor = {r = 0.78, g = 0.24, b = 0.18}},
	{className = "Paladin", classToken = "PALADIN", role = "HEALER", healthMax = 900000, powerMax = 210000, powerColor = {r = 0.20, g = 0.44, b = 0.86}},
	{className = "Hunter", classToken = "HUNTER", role = "DAMAGER", healthMax = 760000, powerMax = 100, powerColor = {r = 0.95, g = 0.78, b = 0.20}},
	{className = "Priest", classToken = "PRIEST", role = "HEALER", healthMax = 820000, powerMax = 250000, powerColor = {r = 0.20, g = 0.44, b = 0.86}},
	{className = "Mage", classToken = "MAGE", role = "DAMAGER", healthMax = 700000, powerMax = 200000, powerColor = {r = 0.20, g = 0.44, b = 0.86}},
	{className = "Rogue", classToken = "ROGUE", role = "DAMAGER", healthMax = 760000, powerMax = 100, powerColor = {r = 0.95, g = 0.78, b = 0.20}},
	{className = "Shaman", classToken = "SHAMAN", role = "HEALER", healthMax = 800000, powerMax = 220000, powerColor = {r = 0.20, g = 0.44, b = 0.86}},
	{className = "Warlock", classToken = "WARLOCK", role = "DAMAGER", healthMax = 720000, powerMax = 200000, powerColor = {r = 0.20, g = 0.44, b = 0.86}},
	{className = "Monk", classToken = "MONK", role = "TANK", healthMax = 930000, powerMax = 100, powerColor = {r = 0.18, g = 0.70, b = 0.55}},
	{className = "Druid", classToken = "DRUID", role = "HEALER", healthMax = 840000, powerMax = 220000, powerColor = {r = 0.20, g = 0.44, b = 0.86}},
	{className = "Demon Hunter", classToken = "DEMONHUNTER", role = "DAMAGER", healthMax = 780000, powerMax = 100, powerColor = {r = 0.72, g = 0.24, b = 0.96}},
	{className = "Evoker", classToken = "EVOKER", role = "HEALER", healthMax = 810000, powerMax = 100, powerColor = {r = 0.20, g = 0.88, b = 0.66}},
}

local RAID_NAMES = {
	"Adara", "Bren", "Caelen", "Doran", "Elira", "Faela", "Garrik", "Hale", "Ilya", "Joren",
	"Kael", "Liora", "Marek", "Nessa", "Orin", "Pyria", "Quill", "Riven", "Selis", "Tarin",
	"Ulric", "Veya", "Wren", "Xara", "Yorin", "Zerin", "Ari", "Bex", "Cato", "Demi",
	"Eris", "Fenn", "Galen", "Hex", "Isla", "Kora", "Lark", "Mira", "Nyx", "Oren",
}

local state = {
	party = false,
	raid = false,
	raidCount = 20,
}

local function printMessage(message)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(format("|cff33ff99%s|r %s", addonName or "XFrames_Testing", message))
	end
end

local function trim(msg)
	return msg and msg:match("^%s*(.-)%s*$") or ""
end

local function getXFrames()
	return _G.XFrames
end

local function isCombatLocked()
	return InCombatLockdown and InCombatLockdown()
end

local function cloneColor(color)
	return {r = color.r, g = color.g, b = color.b}
end

local function buildPartyPreview()
	local preview = {}

	for index, template in ipairs(PARTY_MEMBERS) do
		local member = {}
		for key, value in pairs(template) do
			member[key] = type(value) == "table" and cloneColor(value) or value
		end

		local healthPct = 92 - ((index - 1) * 9)
		local powerPct = 72 - ((index - 1) * 11)
		member.health = floor(member.healthMax * (healthPct / 100))
		member.power = floor(member.powerMax * (powerPct / 100))
		preview[index] = member
	end

	return preview
end

local function clampRaidCount(count)
	local xframes = getXFrames()
	local maxUnits = xframes and xframes.db and xframes.db.profile and xframes.db.profile.raid and xframes.db.profile.raid.maxUnits or 40
	count = tonumber(count) or state.raidCount or 20
	count = floor(count + 0.5)
	if count < 5 then
		count = 5
	end
	if count > maxUnits then
		count = maxUnits
	end
	return count
end

local function buildRaidPreview(count)
	local preview = {}
	count = clampRaidCount(count)

	for index = 1, count do
		local template = RAID_TEMPLATES[((index - 1) % #RAID_TEMPLATES) + 1]
		local member = {}
		for key, value in pairs(template) do
			member[key] = type(value) == "table" and cloneColor(value) or value
		end

		member.name = format("%s %d", RAID_NAMES[((index - 1) % #RAID_NAMES) + 1], index)

		local isDead = (index % 11 == 0)
		member.isDead = isDead
		if isDead then
			member.health = 0
			member.power = 0
		else
			local healthPct = 98 - ((index * 7) % 38)
			local powerPct = 88 - ((index * 9) % 56)
			member.health = floor(member.healthMax * (healthPct / 100))
			member.power = floor(member.powerMax * (powerPct / 100))
		end

		preview[index] = member
	end

	return preview
end

local function applyPreviewState()
	local xframes = getXFrames()
	if not xframes then
		printMessage("XFrames core is not available.")
		return
	end

	if state.party then
		xframes:SetTestingPreview("party", buildPartyPreview())
	else
		xframes:ClearTestingPreview("party")
	end

	if state.raid then
		xframes:SetTestingPreview("raid", buildRaidPreview(state.raidCount))
	else
		xframes:ClearTestingPreview("raid")
	end
end

local function setPartyPreview(enabled)
	if isCombatLocked() then
		printMessage("Party preview changes are unavailable in combat.")
		return
	end

	state.party = enabled and true or false
	applyPreviewState()
	printMessage(format("Party preview %s.", state.party and "enabled" or "disabled"))
end

local function setRaidPreview(enabled, count)
	if isCombatLocked() then
		printMessage("Raid preview changes are unavailable in combat.")
		return
	end

	if enabled then
		state.raid = true
		state.raidCount = clampRaidCount(count)
	else
		state.raid = false
	end

	applyPreviewState()
	if state.raid then
		printMessage(format("Raid preview enabled (%d frames).", state.raidCount))
	else
		printMessage("Raid preview disabled.")
	end
end

local function clearPreview()
	if isCombatLocked() then
		printMessage("Preview changes are unavailable in combat.")
		return
	end

	state.party = false
	state.raid = false
	applyPreviewState()
	printMessage("All testing previews disabled.")
end

local function printStatus()
	printMessage(format(
		"Party preview: %s. Raid preview: %s%s.",
		state.party and "on" or "off",
		state.raid and "on" or "off",
		state.raid and format(" (%d)", state.raidCount) or ""
	))
end

local function printHelp()
	printMessage("Commands: /xftest status, /xftest party on|off, /xftest raid on [count], /xftest raid off, /xftest clear")
end

SlashCmdList.XFRAMESTESTING = function(msg)
	msg = trim(msg or "")
	local command, arg1, arg2 = msg:match("^(%S+)%s*(%S*)%s*(.-)$")
	command = command and command:lower() or ""
	arg1 = arg1 and arg1:lower() or ""
	arg2 = trim(arg2 or "")

	if command == "" or command == "status" then
		printStatus()
		return
	end

	if command == "help" then
		printHelp()
		return
	end

	if command == "clear" or command == "off" then
		clearPreview()
		return
	end

	if command == "party" then
		if arg1 == "on" then
			setPartyPreview(true)
		elseif arg1 == "off" then
			setPartyPreview(false)
		else
			printMessage("Usage: /xftest party on|off")
		end
		return
	end

	if command == "raid" then
		if arg1 == "on" then
			setRaidPreview(true, arg2 ~= "" and arg2 or nil)
		elseif arg1 == "off" then
			setRaidPreview(false)
		else
			printMessage("Usage: /xftest raid on [count] | off")
		end
		return
	end

	printHelp()
end

SLASH_XFRAMESTESTING1 = "/xftest"

addon:RegisterEvent("ADDON_LOADED")
addon:SetScript("OnEvent", function(_, event, loadedAddon)
	if event ~= "ADDON_LOADED" or loadedAddon ~= addonName then
		return
	end

	printMessage("testing module loaded")
	printHelp()
end)
