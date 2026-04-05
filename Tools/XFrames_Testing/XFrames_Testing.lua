local addonName = ...

local addon = CreateFrame("Frame")

local function printMessage(message)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff33ff99%s|r %s", addonName or "XFrames_Testing", message))
	end
end

local function trim(msg)
	return msg and msg:match("^%s*(.-)%s*$") or ""
end

SlashCmdList.XFRAMESTESTING = function(msg)
	msg = trim(msg):lower()

	if msg == "" or msg == "status" then
		printMessage("loaded. Simulation features are not implemented yet.")
		return
	end

	printMessage("reserved for future party and raid simulation commands.")
end

SLASH_XFRAMESTESTING1 = "/xftest"

addon:RegisterEvent("ADDON_LOADED")
addon:SetScript("OnEvent", function(_, event, loadedAddon)
	if event ~= "ADDON_LOADED" or loadedAddon ~= addonName then
		return
	end

	printMessage("development scaffold loaded")
end)
