local SOTA = SOTAG

local module = SOTA:NewModule("BossKillTracker", "AceEvent-3.0")

function module:OnEnable()
	self:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
end

function module:CHAT_MSG_COMBAT_HOSTILE_DEATH(_, msg)
	-- Example boss kill message: "Onyxia dies." — handle when that's contained in a longer message
	local lowerMsg = string.lower(msg)
	local findStr = " dies."
	local s, e = string.find(lowerMsg, findStr, 1, true)

	if s then
		local bossTriggerName = string.sub(msg, 1, s - 1)
		if bossTriggerName ~= "" then
			local bossDkpListItem = SOTA:FindBossDkpFromTriggerName(bossTriggerName)
			SOTA:Debug("BossKillTracker: Detected kill:", bossTriggerName, "SOTA Boss Name/DKP:",
			bossDkpListItem and bossDkpListItem.bossName or "unknown",
				bossDkpListItem and bossDkpListItem.dkpValue or "N/A")
			if bossDkpListItem then
				self:SendMessage("SOTA_BOSS_KILLED", tostring(bossDkpListItem.bossName), tonumber(bossDkpListItem.dkpValue))
				return
			end
		end
	end
end
