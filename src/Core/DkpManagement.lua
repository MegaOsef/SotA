local SOTA                    = SOTAG

-- Max # of lines for class dkp displayed locally when using "/sota class":
local MAX_CLASS_DKP_DISPLAYED = 10;

-- Max # of lines for class dkp	sent by whisper:
local MAX_CLASS_DKP_WHISPERED = 5;

local MSG                     = {
    ON_DKPADDED = "%i DKP was added to %s",
    ON_DKPADDED_RAID = "%i DKP was added to all players in raid",
    ON_DKPREPLACED = "%s was replaced with %s (%i DKP)",
    ON_DKP_SUBTRACT = "%i DKP was subtracted from %s",
    ON_DKP_SUBTRACT_RAID = "%i DKP was subtracted from all players in raid",
}

local DKPSTRING_LENGTH        = 5;


function SOTA:PrintPlayerDkp(playername, sender)
    if playername then
        playername = self:UCFirst(playername);
    else
        playername = UnitName("player");
    end

    local dkp = self:GetPlayerDkp(playername);
    if dkp then
        dkp = 1 * dkp;
        if sender then
            self:Whisper(sender, string.format("%s have %d DKP.", playername, dkp));
        else
            self:Print(string.format("%s have %d DKP.", playername, dkp));
        end
    else
        if sender then
            self:Whisper(sender, string.format("There are no DKP information for %s.", playername));
        else
            self:Print(string.format("There are no DKP information for %s.", playername));
        end
    end
end

function SOTA:PrintClassDkp(playerclass, sender)
    if playerclass then
        playerclass = self:UCFirst(playerclass);
    else
        playerclass = UnitClass("player");
    end

    local classtable = {}
    for n = 1, table.getn(self.guildRosterTable), 1 do
        if self.guildRosterTable[n][RT_COL.CLASS] == playerclass then
            classtable[table.getn(classtable) + 1] = self.guildRosterTable[n];
        end
    end

    self:SortTableDescending(classtable, RT_COL.DKP_AMNT);

    if sender then
        self:Whisper(sender, string.format("Top %d DKP for %ss:", MAX_CLASS_DKP_WHISPERED, playerclass));
        for n = 1, table.getn(classtable), 1 do
            if n <= MAX_CLASS_DKP_WHISPERED then
                self:Whisper(sender,
                    string.format("%d - %s: %d DKP", n, classtable[n][RT_COL.PNAME], 1 * (classtable[n][RT_COL.DKP_AMNT])));
            end
        end
    else
        self:Print(string.format("Top %d DKP for %ss:", MAX_CLASS_DKP_DISPLAYED, playerclass));
        for n = 1, table.getn(classtable), 1 do
            if n <= MAX_CLASS_DKP_DISPLAYED then
                self:Print(string.format("%d - %s: %d DKP", n, classtable[n][RT_COL.PNAME],
                    1 * (classtable[n][RT_COL.DKP_AMNT])));
            end
        end
    end
end

--[[
--	Get DKP belonging to a specific player.
--	Returns NIL if player was not found. Players with no DKP will return 0.
--]]
function SOTA:GetPlayerDkp(playername)
    local dkp = nil;
    local playerInfo = self:GetGuildPlayerInfo(playername);
    if playerInfo then
        dkp = 1 * (playerInfo[RT_COL.DKP_AMNT]);
    end

    return dkp;
end

function SOTA:CanDoDKP(silentmode)
    if not self:IsInRaid() then
        return false;
    end

    if not self:CanWriteNotes() then
        if not silentmode then
            SOTA:Print("You do not have access to change notes!");
        end
        return false;
    end

    if not self:IsPromoted() then
        if not silentmode then
            SOTA:Print("You are not promoted!");
        end
        return false;
    end

    return true;
end

--[[
--	Add <dkp> DKP to <playername>
--]]
function SOTA:Async_AddPlayerDKP(playername, dkp)
    if self:CanDoDKP() then
        self:AddJob(function(job) self:AddPlayerDKP(job[2], job[3]) end, playername, dkp)
        self:RequestUpdateGuildRoster();
    end
end

function SOTA:AddPlayerDKP(playername, dkpValue, silentmode)
    dkpValue = 1 * dkpValue;
    if self:ApplyPlayerDKP(playername, dkpValue) then
        playername = self:UCFirst(playername);
        if not silentmode then
            self:Broadcast(self.CHANNEL.WARN, string.format(MSG.ON_DKPADDED, dkpValue, playername))
        end
        self:TriggerEvent("SOTA_LOG_SINGLE_TRANSACTION", "+Player", playername, dkpValue);
    end
end

--[[
--	Subtract <dkp> DKP from <playername>
--]]
function SOTA:Async_SubtractPlayerDKP(playername, dkp)
    if self:CanDoDKP() and tonumber(dkp) then
        self:AddJob(function(job) self:SubtractPlayerDKP(job[2], job[3]) end, playername, dkp)
        self:RequestUpdateGuildRoster();
    end
end

function SOTA:SubtractPlayerDKP(playername, dkpValue, silentmode)
    dkpValue = -1 * dkpValue;
    if self:ApplyPlayerDKP(playername, dkpValue) then
        playername = self:UCFirst(playername);
        if not silentmode then
            self:Broadcast(self.CHANNEL.WARN, string.format(MSG.ON_DKP_SUBTRACT, abs(dkpValue), playername))
        end
        self:TriggerEvent("SOTA_LOG_SINGLE_TRANSACTION", "-Player", playername, dkpValue);
    end
end

--[[
--	Add <n> DKP to all players in raid
--]]
function SOTA:Async_AddRaidDKP(dkp)
    if self:IsInRaid(true) then
        self:AddJob(function(job) self:AddRaidDKP(job[2]) end, dkp, "_")
        self:RequestUpdateGuildRoster();
    end
end

function SOTA:AddRaidDKP(dkp, silentmode, callMethod)
    if self:IsInRaid(true) then
        dkp = 1 * dkp;

        if not callMethod then
            callMethod = "+Raid";
        end

        local tidIndex = 1
        local tidChanges = {}

        local raidRoster = self:GetRaidRoster();
        for n = 1, table.getn(raidRoster), 1 do
            self:ApplyPlayerDKP(raidRoster[n][RT_COL.PNAME], dkp);

            tidChanges[tidIndex] = { raidRoster[n][RT_COL.PNAME], dkp };
            tidIndex = tidIndex + 1;
        end

        if not silentmode then
            self:Broadcast(self.CHANNEL.WARN, string.format(MSG.ON_DKPADDED_RAID, dkp))
        end

        local module = self:GetModule("LogsUI", true)
        if module then
            module:LogMultipleTransactions(callMethod, tidChanges)
        end
        return true;
    end
    return false;
end

--[[
--	Subtract <n> DKP from each raid
--]]
function SOTA:Async_SubtractRaidDKP(dkp)
    if self:IsInRaid(true) then
        self:AddJob(function(job) self:SubtractRaidDKP(job[2]) end, dkp, "_")
        self:RequestUpdateGuildRoster();
    end
end

function SOTA:SubtractRaidDKP(dkp, silentmode, callMethod)
    if self:IsInRaid(true) then
        dkp = -1 * dkp;

        if not callMethod then
            callMethod = "-Raid";
        end

        local tidIndex = 1
        local tidChanges = {}

        local raidRoster = self:GetRaidRoster();
        --for n=1, table.getn(raidRoster), 1 do
        --	SOTA:Debug(
        --		self.raidRosterTable[n][1],
        --		self.raidRosterTable[n][2],
        --		self.raidRosterTable[n][3],
        --		self.raidRosterTable[n][4],
        --		self.raidRosterTable[n][5]
        --	)
        --end
        for n = 1, table.getn(raidRoster), 1 do
            self:ApplyPlayerDKP(raidRoster[n][RT_COL.PNAME], dkp);

            tidChanges[tidIndex] = { raidRoster[n][RT_COL.PNAME], dkp };
            tidIndex = tidIndex + 1;
        end

        if not silentmode then
            self:Broadcast(self.CHANNEL.WARN, string.format(MSG.ON_DKP_SUBTRACT_RAID, dkp))
        end

        local module = self:GetModule("LogsUI", true)
        if module then
            module:LogMultipleTransactions(callMethod, tidChanges)
        end
        return true;
    end
    return false;
end

--[[
--	Perform a DKP decay without really removing DKP. Result is echoed out locally.
--	Added in 1.1.0
--]]
function SOTA:Async_Decaytest(percent)
    self:AddJob(function(job) self:Decaytest(job[2]) end, percent, "_")
    self:RequestUpdateGuildRoster();
end

function SOTA:Decaytest(percent, silentmode)
    --	Note: arg may contain a percent sign; remove this first:
    if not tonumber(percent) then
        local pctSign = string.sub(percent, string.len(percent), string.len(percent));
        if pctSign == "%" then
            percent = string.sub(percent, 1, string.len(percent) - 1);
        end
    end

    if not tonumber(percent) then
        self:Print("Guild Decay test cancelled: Percent is not a valid number: " .. percent);
        return false;
    end

    percent = abs(1 * percent);

    local tidIndex = 1;
    local tidChanges = {};

    local reducedDkp = 0;
    local playerCount = 0;

    --	Iterate over all guilded players - online or not
    local name, publicNote, officerNote
    local memberCount = GetNumGuildMembers();
    for n = 1, memberCount, 1 do
        name, _, _, _, _, _, publicNote, officerNote = GetGuildRosterInfo(n);
        local note = officerNote;
        if SOTA.db.realm.UseGuildNotes == SOTA_GUILDNOTE.USEPUBLIC then
            note = publicNote;
        end

        local _, _, dkp = string.find(note, "<(-?%d*)>");
        if dkp and tonumber(dkp) then
            local minus = floor(dkp * percent / 100)
            tidChanges[tidIndex] = { name, (-1 * minus) }
            tidIndex = tidIndex + 1

            dkp = dkp - minus;
            reducedDkp = reducedDkp + minus;
            playerCount = playerCount + 1;
            note = string.gsub(note, "<(-?%d*)>", self:CreateDkpString(dkp), 1);
        else
            dkp = 0;
            note = note .. self:CreateDkpString(dkp);
        end
    end

    self:Print("Testing Guild DKP decay using a " .. percent .. "% decay value.");
    self:Print("Decay will remove a total of " .. reducedDkp .. " DKP from " .. playerCount .. " players.")

    return true;
end

--[[
--	Perform Guild Decay of <n>% DKP
--	This function requires Show Offline Members to be enabled.
--]]
function SOTA:Async_DecayDKP(percent)
    self:AddJob(function(job) self:DecayDKP(job[2]) end, percent, "_")
    self:RequestUpdateGuildRoster();
end

function SOTA:DecayDKP(percent, silentmode)
    --	Note: arg may contain a percent sign; remove this first:
    if not tonumber(percent) then
        local pctSign = string.sub(percent, string.len(percent), string.len(percent));
        if pctSign == "%" then
            percent = string.sub(percent, 1, string.len(percent) - 1);
        end
    end

    if not tonumber(percent) then
        if not silentmode then
            self:Print("Guild Decay cancelled: Percent is not a valid number: " .. percent);
        end
        return false;
    end

    percent = abs(1 * percent);

    --	This ensure the guild roster also contains Offline members.
    --	Otherwise offline members will not get decayed!
    if not GetGuildRosterShowOffline() == 1 then
        if not silentmode then
            self:Print("Guild Decay cancelled: You need to enable Offline Guild Members in the guild roster first.")
        end
        return false;
    end

    local tidIndex = 1;
    local tidChanges = {};

    local reducedDkp = 0;
    local playerCount = 0;

    --	Iterate over all guilded players - online or not
    local name, publicNote, officerNote
    local memberCount = GetNumGuildMembers();
    for n = 1, memberCount, 1 do
        name, _, _, _, _, _, publicNote, officerNote = GetGuildRosterInfo(n);
        local note = officerNote;
        if SOTA.db.realm.UseGuildNotes == SOTA_GUILDNOTE.USEPUBLIC then
            note = publicNote;
        end

        local _, _, dkp = string.find(note, "<(-?%d*)>");
        if dkp and tonumber(dkp) then
            local minus = floor(dkp * percent / 100)
            tidChanges[tidIndex] = { name, (-1 * minus) }
            tidIndex = tidIndex + 1

            dkp = dkp - minus;
            reducedDkp = reducedDkp + minus;
            playerCount = playerCount + 1;
            note = string.gsub(note, "<(-?%d*)>", self:CreateDkpString(dkp), 1);
        else
            dkp = 0;
            note = note .. self:CreateDkpString(dkp);
        end

        if SOTA.db.realm.UseGuildNotes == SOTA_GUILDNOTE.USEPUBLIC then
            GuildRosterSetPublicNote(n, note);
        else
            GuildRosterSetOfficerNote(n, note);
        end

        self:UpdateLocalDKP(name, dkp);
    end

    if not silentmode then
        SOTA:Broadcast(SOTA.CHANNEL.GUILD,
            "Guild DKP decay by " .. percent .. "% was performed by " .. UnitName("player") .. ".")
        SOTA:Broadcast(SOTA.CHANNEL.GUILD,
            "Guild DKP removed a total of " .. reducedDkp .. " DKP from " .. playerCount .. " players.")
    end

    local module = self:GetModule("LogsUI", true)
    if module then
        module:LogMultipleTransactions("-Decay", tidChanges)
    end

    return true;
end

--[[
--	Generic function to add(or remove) DKP from a player.
--]]
function SOTA:ApplyPlayerDKP(playername, dkpValue, silentmode)
    SOTA:Debug("ApplyPlayerDKP--playername:", playername, "dkpvalue:", dkpValue, "silentmode:", silentmode)
    dkpValue = 1 * dkpValue;

    playername = self:UCFirst(playername);

    local memberCount = GetNumGuildMembers()
    for n = 1, memberCount, 1 do
        name, _, _, _, _, _, publicNote, officerNote = GetGuildRosterInfo(n);
        if name == playername then
            local note = officerNote;
            if SOTA.db.realm.UseGuildNotes == SOTA_GUILDNOTE.USEPUBLIC then
                note = publicNote;
            end

            local _, _, dkp = string.find(note, "<(-?%d*)>");

            if dkp and tonumber(dkp) then
                dkp = (1 * dkp) + dkpValue;
                note = string.gsub(note, "<(-?%d*)>", self:CreateDkpString(dkp), 1);
            else
                dkp = dkpValue;
                note = note .. self:CreateDkpString(dkp);
            end

            if SOTA.db.realm.UseGuildNotes == SOTA_GUILDNOTE.USEPUBLIC then
                GuildRosterSetPublicNote(n, note);
            else
                GuildRosterSetOfficerNote(n, note);
            end

            self:UpdateLocalDKP(name, dkp);
            return true;
        end
    end

    if not silentmode then
        self:Print(string.format("%s was not found in the guild; DKP was not updated.", playername));
    end
    return false;
end

--[[
--	Update local stored DKP
--	Input: receiver, dkpadded
]]
function SOTA:UpdateLocalDKP(receiver, dkpAdded)
    local raidRoster = self:GetRaidRoster(); --{ Name, DKP, Class, Rank, Online }
    for n = 1, table.getn(raidRoster), 1 do
        local player = raidRoster[n];
        local name = player[RT_COL.PNAME]
        local dkp = player[RT_COL.DKP_AMNT]
        if receiver == name then
            if dkp then
                dkp = dkp + dkpAdded;
            else
                dkp = dkpAdded;
            end

            raidRoster[n][RT_COL.DKP_AMNT] = dkp
            return;
        end
    end
end

function SOTA:CreateDkpString(dkp)
    local result;

    if not dkp or dkp == "" or not tonumber(dkp) then
        dkp = 0;
    end
    dkp = tonumber(dkp);

    local dkpLen = tonumber(DKPSTRING_LENGTH);
    if dkpLen > 0 then
        local dkpStr = "" .. abs(dkp)
        while string.len(dkpStr) < dkpLen do
            dkpStr = "0" .. dkpStr;
        end
        if dkp < 0 then
            dkpStr = "-" .. dkpStr;
        end
        result = "<" .. dkpStr .. ">";
    else
        result = "<" .. dkp .. ">";
    end

    return result;
end
