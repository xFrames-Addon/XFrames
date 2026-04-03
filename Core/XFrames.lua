local addonName, ns = ...

local XFrames = CreateFrame("Frame")
ns.XFrames = XFrames

XFrames.name = addonName
XFrames.modules = {}
XFrames.events = {}

local function printf(...)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(string.format(...))
	end
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

function XFrames:ForEachModule(method)
	for _, module in pairs(self.modules) do
		if type(module[method]) == "function" then
			module[method](module, self)
		end
	end
end

function XFrames:Initialize()
	if self.initialized then
		return
	end

	self.initialized = true
	self:InitializeDatabase()
	self:ForEachModule("Initialize")
	self:RegisterSlashCommands()
end

function XFrames:RegisterSlashCommands()
	SLASH_XFRAMES1 = "/xframes"
	SlashCmdList.XFRAMES = function(msg)
		msg = msg and msg:lower():match("^%s*(.-)%s*$") or ""

		if msg == "status" or msg == "" then
			printf("|cff33ff99XFrames|r loaded. Modules: %d", self:CountModules())
			return
		end

		if msg == "debug" then
			self.db.profile.debug = not self.db.profile.debug
			printf("|cff33ff99XFrames|r debug is now %s", self.db.profile.debug and "on" or "off")
			return
		end

		printf("|cff33ff99XFrames|r commands: status, debug")
	end
end

function XFrames:CountModules()
	local count = 0
	for _ in pairs(self.modules) do
		count = count + 1
	end

	return count
end

function XFrames.events:ADDON_LOADED(loadedAddon)
	if loadedAddon ~= addonName then
		return
	end

	XFrames:Initialize()
end

function XFrames.events:PLAYER_LOGIN()
	XFrames:ForEachModule("Enable")
end

XFrames:SetScript("OnEvent", function(_, event, ...)
	local handler = XFrames.events[event]
	if handler then
		handler(XFrames.events, ...)
	end
end)

XFrames:RegisterEvent("ADDON_LOADED")
XFrames:RegisterEvent("PLAYER_LOGIN")
