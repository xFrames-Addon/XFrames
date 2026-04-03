local _, ns = ...

local XFrames = ns.XFrames
local Raid = {}

function Raid:Initialize()
	self.enabled = XFrames.db.profile.raid.enabled
end

function Raid:Enable()
	if not self.enabled then
		return
	end

	-- Raid frames are intentionally deferred until the core frame patterns are stable.
end

XFrames:RegisterModule("Raid", Raid)
