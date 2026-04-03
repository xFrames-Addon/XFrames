local _, ns = ...

local XFrames = ns.XFrames
local Target = {}

function Target:Initialize()
	self.enabled = XFrames.db.profile.target.enabled
	self.targetTargetEnabled = XFrames.db.profile.target.targettarget.enabled
end

function Target:Enable()
	if not self.enabled then
		return
	end

	-- Target and target-of-target implementation starts here in the next phase.
end

XFrames:RegisterModule("Target", Target)
