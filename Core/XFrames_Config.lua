local _, ns = ...

local XFrames = ns.XFrames

local defaults = {
	profile = {
		debug = false,
		diagnostics = {
			autoEnableCVars = false,
			taintLogLevel = "5",
			logLimit = 200,
			logs = {},
		},
		player = {
			enabled = true,
			width = 240,
			height = 96,
			scale = 1,
			castBar = {
				enabled = true,
				width = 240,
				height = 20,
			},
			pet = {
				enabled = true,
				width = 180,
				height = 58,
				scale = 0.9,
				position = {
					point = "CENTER",
					relativePoint = "CENTER",
					x = -520,
					y = -270,
				},
			},
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
			height = 96,
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
				height = 90,
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
				width = 180,
				height = 56,
				scale = 0.9,
				position = {
					point = "CENTER",
					relativePoint = "CENTER",
					x = 565,
					y = -225,
				},
			},
			focustarget = {
				enabled = true,
				width = 172,
				height = 52,
				scale = 0.88,
				position = {
					point = "CENTER",
					relativePoint = "CENTER",
					x = 540,
					y = -125,
				},
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
