local _, ns = ...

local XFrames = ns.XFrames

local defaults = {
	profile = {
		debug = false,
		ui = {
			unlocked = false,
			hideBlizzard = true,
			hideBlizzardCastBars = true,
			portraitStyle = "portrait",
			settingsPosition = {
				point = "CENTER",
				relativePoint = "CENTER",
				x = 0,
				y = 0,
			},
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
			buffs = {
				enabled = true,
				size = 22,
				max = 8,
				spacing = 4,
				xOffset = 6,
				yOffset = 8,
			},
			debuffs = {
				enabled = true,
				size = 22,
				max = 8,
				spacing = 4,
				xOffset = 6,
				yOffset = -8,
			},
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
			boss = {
				enabled = true,
				width = 156,
				height = 48,
				scale = 0.9,
				spacing = 6,
				maxUnits = 5,
				position = {
					point = "TOPRIGHT",
					relativePoint = "TOPRIGHT",
					x = -28,
					y = -220,
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
			outOfCombatMeterMode = "segment",
			position = {
				point = "CENTER",
				relativePoint = "CENTER",
				x = -610,
				y = -70,
			},
		},
		raid = {
			enabled = false,
			width = 96,
			height = 40,
			scale = 1,
			columns = 5,
			maxUnits = 40,
			spacingX = 8,
			spacingY = 6,
			position = {
				point = "CENTER",
				relativePoint = "CENTER",
				x = 210,
				y = 120,
			},
			tanks = {
				enabled = false,
				width = 96,
				height = 40,
				scale = 1,
				spacing = 6,
				maxUnits = 4,
				position = {
					point = "TOPLEFT",
					relativePoint = "TOPLEFT",
					x = 28,
					y = -220,
				},
				targets = {
					enabled = false,
					width = 96,
					height = 40,
					xOffset = 8,
				},
			},
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

	if self.db.profile.raid then
		self.db.profile.raid.width = 96
		self.db.profile.raid.height = 40
		if self.db.profile.raid.maxUnits == nil or self.db.profile.raid.maxUnits == 20 then
			self.db.profile.raid.maxUnits = 40
		end
		self.db.profile.raid.spacingX = 8
		self.db.profile.raid.spacingY = 6
		self.db.profile.raid.tanks = self.db.profile.raid.tanks or {}
		self.db.profile.raid.tanks.width = self.db.profile.raid.width
		self.db.profile.raid.tanks.height = self.db.profile.raid.height
		self.db.profile.raid.tanks.scale = 1
		self.db.profile.raid.tanks.spacing = self.db.profile.raid.tanks.spacing or 6
		self.db.profile.raid.tanks.maxUnits = self.db.profile.raid.tanks.maxUnits or 4
		self.db.profile.raid.tanks.enabled = self.db.profile.raid.tanks.enabled == true
		self.db.profile.raid.tanks.position = self.db.profile.raid.tanks.position or {
			point = "TOPLEFT",
			relativePoint = "TOPLEFT",
			x = 28,
			y = -220,
		}
		self.db.profile.raid.tanks.targets = self.db.profile.raid.tanks.targets or {}
		self.db.profile.raid.tanks.targets.width = self.db.profile.raid.width
		self.db.profile.raid.tanks.targets.height = self.db.profile.raid.height
		self.db.profile.raid.tanks.targets.xOffset = self.db.profile.raid.tanks.targets.xOffset or 8
		self.db.profile.raid.tanks.targets.enabled = self.db.profile.raid.tanks.targets.enabled == true
		if not (IsInRaid and IsInRaid()) then
			self.db.profile.raid.enabled = false
		end
	end
end
