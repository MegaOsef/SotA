local SOTA = SOTAG

local module = SOTA:NewModule("BossKillTracker", "AceEvent-3.0")

function module:OnEnable()
	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

function module:COMBAT_LOG_EVENT_UNFILTERED( _, _, subevent, _, _, _, _, destName, ...)
	if subevent == "PARTY_KILL" then
		local bossTriggerName = destName
		if bossTriggerName ~= "" then
			local bossDkpListItem = SOTA:FindBossDkpFromTriggerName(bossTriggerName)
			SOTA:Debug("BossKillTracker: Detected kill:", bossTriggerName, "SOTA Boss Name/DKP:",
				bossDkpListItem and bossDkpListItem.bossName or "unknown",
				bossDkpListItem and bossDkpListItem.dkpValue or "N/A")
			if bossDkpListItem then
				self:SendMessage("SOTA_BOSS_KILLED", tostring(bossDkpListItem.bossName),
					tonumber(bossDkpListItem.dkpValue))
				return
			end
		end
	end
end
