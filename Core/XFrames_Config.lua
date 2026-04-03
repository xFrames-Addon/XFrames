local _, ns = ...

local XFrames = ns.XFrames

local defaults = {
	profile = {
		debug = false,
		diagnostics = {
			autoEnableCVars = true,
			taintLogLevel = "5",
			logLimit = 200,
			logs = {},
		},
		player = {
			enabled = true,
			width = 240,
			height = 84,
			scale = 1,
			position = {
				point = "CENTER",
				relativePoint = "CENTER",
				x = -360,
				y = -220,
			},
		},
		target = {
			enabled = true,
			width = 240,
			height = 84,
			scale = 1,
			position = {
				point = "CENTER",
				relativePoint = "CENTER",
				x = 360,
				y = -220,
			},
			focus = {
				enabled = true,
				width = 220,
				height = 78,
				scale = 0.95,
				position = {
					point = "CENTER",
					relativePoint = "CENTER",
					x = 360,
					y = -120,
				},
			},
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
	self.db.profile.diagnostics.logs = self.db.profile.diagnostics.logs or {}
end
