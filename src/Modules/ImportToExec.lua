local SOTA = SOTAG

local module = SOTA:NewModule("ImportToExec", "AceEvent-3.0")

function module:OnEnable()
    self.importRequested = false
    self.importStr = ""

    self:RegisterMessage("SOTA_IMPORTTOEXEC_REQUEST")
    self:RegisterMessage("SOTA_GUILDROSTER_UPDATED")
end

function module:CheckEntry(entry)
    if not entry then
        return false
    end

    if not entry.player or entry.player == "" then
        SOTA:Print("Error: Invalid entry, missing player name")
        return false
    end

    if not entry.dkpChange or type(entry.dkpChange) ~= "number" then
        SOTA:Print("Error: Invalid entry, missing or invalid dkpChange")
        return false
    end

    if not entry.type or entry.type == "" then
        SOTA:Print("Error: Invalid entry, missing type")
        return false
    end

    local playerInfo = SOTA:GetGuildPlayerInfo(entry.player)
    if not playerInfo then
        SOTA:Print(string.format("Error: Player %s not found in guild roster", entry.player))
        return false
    end

    if entry.dkpChange < 0 and (playerInfo[RT_COL.DKP_AMNT] + entry.dkpChange) < 0 then
        SOTA:Print(string.format("Error: Player %s would have negative DKP after transaction", entry.player))
        return false
    end

    if (entry.dkpChange + playerInfo[RT_COL.DKP_AMNT]) > SOTA.MAX_DKP then
        SOTA:Print(string.format("Error: Player %s would exceed maximum DKP after transaction", entry.player))
        return false
    end

    return true
end

function module:SOTA_GUILDROSTER_UPDATED(_)
    if self.importRequested == false then
        return
    end
    self.importRequested = false

    SOTA:Print("-- Import job started --")

    if self.importStr == "" then
        SOTA:Print("Error: No data to import")
        SOTA:Print("-- Import job ended with error --")
        return
    end


    local toExec, err = SOTA.json.decode(self.importStr)
    if not toExec then
        SOTA:Print("Error decoding JSON:", err)
        self.importStr = ""
        SOTA:Print("-- Import job ended with error --")
        return
    end

    local count = table.getn(toExec)
    if count == 0 then
        SOTA:Print("Error: No transactions to execute")
        self.importStr = ""
        SOTA:Print("-- Import job ended with error --")
        return
    end
    SOTA:Print("Number of transactions to execute:", count)

    for n = 1, count, 1 do
        -- Checks
        local entry = toExec[n]
        if not self:CheckEntry(entry) then
            SOTA:Print(string.format("Error in entry %d: invalid entry", n))
            self.importStr = ""
            SOTA:Print("-- Import job ended with error --")
            return
        end
    end

    local ravenLogs = SOTA:GetModule("RavenLogsForApp", true)
    for n = 1, count, 1 do
        -- Execs
        local entry = toExec[n]
        SOTA:ApplyPlayerDKP(entry.player, entry.dkpChange)
        if ravenLogs then
            local logId = ravenLogs:LogTransaction(entry.type)
            ravenLogs:LogDkpChange(logId, entry.player, entry.dkpChange)
        end

        SOTA:Print(string.format("Executed entry %d/%d: Player=%s, DKP Change=%d, Type=%s",
            n, count, entry.player, entry.dkpChange, entry.type))
    end

    SOTA:Print("-- Import job ended successfully --")
    -- Get ready for the next import
    self.importStr = ""
end

function module:SOTA_IMPORTTOEXEC_REQUEST(_)
    SOTA:OpenTextModal(function(text)
        module.importRequested = true
        module.importStr = text
        SOTA:RequestUpdateGuildRoster()
        SOTA:Print("Job added, waiting for guild roster update...")
    end)
end
