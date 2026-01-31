local SOTA = SOTAG

local module = SOTA:NewModule("BossKillTracker", "AceEvent-2.0")

function module:OnEnable()
	self:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
end

function module:CHAT_MSG_COMBAT_HOSTILE_DEATH(msg)
	-- Example boss kill message: "Onyxia dies." — handle when that's contained in a longer message
	local lowerMsg = string.lower(msg)
	local findStr = " dies."
	local s, e = string.find(lowerMsg, findStr, 1, true)

	if s then
		local bossName = string.sub(msg, 1, s - 1)
		if bossName ~= "" then
			local bossDkp = SOTA:FindBossDkp(bossName)
			if bossDkp then
				self:TriggerEvent("SOTA_BOSS_KILLED", tostring(bossDkp.BossName), tonumber(bossDkp.DkpValue))
				return
			end
		end
	end
end
