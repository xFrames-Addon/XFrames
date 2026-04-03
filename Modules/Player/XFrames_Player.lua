local _, ns = ...

local XFrames = ns.XFrames
local Player = {}

function Player:Initialize()
	self.enabled = XFrames.db.profile.player.enabled
end

function Player:Enable()
	if not self.enabled then
		return
	end

	-- Player frame implementation starts here in the next phase.
end

XFrames:RegisterModule("Player", Player)
