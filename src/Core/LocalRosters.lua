local SOTA = SOTAG

RT_COL     = {
    PNAME = 1,
    DKP_AMNT = 2,
    CLASS = 3,
    GRANK = 4,
    ONLINE = 5,
    ZONE = 6,
    GRANK_IDX = 7
}


--
--	Guild Roster Functions
--
function SOTA:RequestUpdateGuildRoster()
    if GetGuildRosterShowOffline() then
        GuildRoster();
    else
        -- Wow does an update of the guild roster in this function.
        SetGuildRosterShowOffline(1);
    end
end

function SOTA:GUILD_ROSTER_UPDATE()
    self:RefreshGuildRoster();

    if self:CanReadNotes() then
        if not JobIsRunning then
            JobIsRunning = true

            local job = self:GetNextJob()
            while job do
                job[1](job)
                job = self:GetNextJob()
            end

            if self:IsInRaid(true) then
                self:RefreshRaidRoster()
            end

            JobIsRunning = false
        end
    end
end

function SOTA:RefreshGuildRoster()
    if not self:CanReadNotes() then
        return;
    end

    local memberCount = GetNumGuildMembers();
    local note
    local NewGuildRosterTable = {}

    for n = 1, memberCount, 1 do
        local name, rank, rankIndex, _, class, zone, publicnote, officernote, online = GetGuildRosterInfo(n)

        if not zone then
            zone = "";
        end

        if SOTA.db.realm.UseGuildNotes == SOTA_GUILDNOTE.USEPUBLIC then
            note = publicnote
        else
            note = officernote
        end

        if not note or note == "" then
            note = "<0>";
        end

        if not online then
            online = 0;
        end

        local _, _, dkp = string.find(note, "<(-?%d*)>")
        if not dkp or not tonumber(dkp) then
            dkp = 0;
        end

        --echo(string.format("Added %s (%s)", name, online));

        NewGuildRosterTable[n] = { name, (1 * dkp), class, rank, online, zone, rankIndex };
    end

    self.guildRosterTable = NewGuildRosterTable;
end

--[[
--	Get information belonging to a specific player in the guild.
--	Returns NIL if player was not found.
--]]
function SOTA:GetGuildPlayerInfo(player)
    player = self:UCFirst(player);

    for n = 1, table.getn(self.guildRosterTable), 1 do
        if self.guildRosterTable[n][RT_COL.PNAME] == player then
            return self.guildRosterTable[n];
        end
    end

    return nil;
end

--
--	Raid Roster Functions
--
function SOTA:GetUnitIDFromGroup(playerName)
    playerName = self:UCFirst(playerName);

    if self:IsInRaid(false) then
        for n = 1, GetNumRaidMembers(), 1 do
            if UnitName("raid" .. n) == playerName then
                return "raid" .. n;
            end
        end
    else
        for n = 1, GetNumPartyMembers(), 1 do
            if UnitName("party" .. n) == playerName then
                return "party" .. n;
            end
        end
    end

    return nil;
end

function SOTA:GetRaidRoster()
    if RaidRosterLazyUpdate then
        self:RefreshRaidRoster();
    end
    return self.raidRosterTable;
end

--[[
--	Re-read the raid status and namely the DKP values.
--	Should be called after each roster update.
--]]
function SOTA:RefreshRaidRoster()
    local playerCount = GetNumRaidMembers()

    if playerCount then
        self.raidRosterTable = {}
        local index = 1
        local memberCount = table.getn(self.guildRosterTable);
        for n = 1, playerCount, 1 do
            local name, _, _, _, class = GetRaidRosterInfo(n);

            for m = 1, memberCount, 1 do
                local info = self.guildRosterTable[m]
                if name == info[RT_COL.PNAME] then
                    self.raidRosterTable[index] = info;
                    index = index + 1
                end
            end
        end
    end

    RaidRosterLazyUpdate = false;

    --	for n=1,table.getn(self.raidRosterTable), 1 do
    --		local rr = self.raidRosterTable[n];
    --		echo("RaidRosterUpdate:");
    --		echo(string.format("Name=%s, DKP=%d, Class=%s, Rank=%s", rr[1], rr[2], rr[3], rr[4]));
    --	end
end
