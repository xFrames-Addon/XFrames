local _, ns = ...

local XFrames = ns.XFrames

local defaults = {
	profile = {
		debug = false,
		ui = {
			unlocked = false,
			hideBlizzard = true,
			hideBlizzardCastBars = true,
			minimap = {
				hide = false,
			},
		},
		diagnostics = {
			autoEnableCVars = false,
			taintLogLevel = "5",
			logLimit = 200,
			logs = {},
		},
		player = {
			enabled = true,
			width = 266,
			height = 96,
			scale = 1,
			castBar = {
				enabled = true,
				width = 240,
				height = 20,
				position = {
					point = "CENTER",
					relativePoint = "CENTER",
					x = -360,
					y = -286,
				},
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
			width = 266,
			height = 96,
			scale = 1,
			castBar = {
				enabled = true,
				width = 240,
				height = 20,
				position = {
					point = "CENTER",
					relativePoint = "CENTER",
					x = 360,
					y = -286,
				},
			},
			position = {
				point = "CENTER",
				relativePoint = "CENTER",
				x = 360,
				y = -220,
			},
			focus = {
				enabled = true,
				width = 246,
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
					x = 610,
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
					x = 585,
					y = -125,
				},
			},
		},
		party = {
			enabled = true,
			width = 266,
			height = 96,
			spacing = 10,
			scale = 1,
			subtitleMode = "status",
			position = {
				point = "CENTER",
				relativePoint = "CENTER",
				x = -610,
				y = -70,
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

	if self.db.profile.party then
		if self.db.profile.party.width == 232 then
			self.db.profile.party.width = 266
		end
		if self.db.profile.party.height == 58 or self.db.profile.party.height == 62 then
			self.db.profile.party.height = 96
		end
		if self.db.profile.party.scale == 0.92 then
			self.db.profile.party.scale = 1
		end
		if self.db.profile.party.spacing == 8 then
			self.db.profile.party.spacing = 10
		end
	end
end
