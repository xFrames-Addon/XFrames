local _, ns = ...

local XFrames = ns.XFrames

local defaults = {
	profile = {
		debug = false,
		player = {
			enabled = true,
		},
		target = {
			enabled = true,
			targettarget = {
				enabled = true,
			},
		},
		raid = {
			enabled = false,
		},
	},
}

local function copyDefaults(source, target)
	for key, value in pairs(source) do
		if type(value) == "table" then
			if type(target[key]) ~= "table" then
				target[key] = {}
			end
			copyDefaults(value, target[key])
		elseif target[key] == nil then
			target[key] = value
		end
	end
end

function XFrames:InitializeDatabase()
	XFramesDB = XFramesDB or {}
	copyDefaults(defaults, XFramesDB)
	self.db = XFramesDB
end
