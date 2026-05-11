local SOTA = SOTAG

local module = SOTA:NewModule("GuildExtract", "AceEvent-3.0")

function module:OnEnable()
    self.extractRequested = false

    self:RegisterMessage("SOTA_GUILDROSTER_UPDATED")
    self:RegisterMessage("SOTA_GUILDEXTRACT_REQUEST")
end

function module:SOTA_GUILDROSTER_UPDATED()
    if self.extractRequested == false then
        return
    end
    self.extractRequested = false

    local numTotal = GetNumGuildMembers();

    local result = "";
    result = result .. "| Name           | Class   | Rank            |  DKP  | Last Online           |";
    result = result .. "\n";
    result = result .. "|----------------|---------|-----------------|-------|-----------------------|";
    for n = 1, numTotal, 1 do
        local name, r, _, _, c, _, _, note, _ = GetGuildRosterInfo(n)

        local playerInfo = SOTA:GetGuildPlayerInfo(name)
        if not playerInfo then
            SOTA:Print("Error extracting guild info for " .. name)
        else
            local lastOnline = self:GetLastOnline(n);
            if playerInfo[RT_COL.DKP_AMNT] > 0 then -- Only extract players with DKP
                result = result ..
                    string.format(
                        "\n| %-14s | %-7s | %-15s | %05d | %-20s |",
                        name,
                        playerInfo[RT_COL.CLASS],
                        playerInfo[RT_COL.GRANK],
                        playerInfo[RT_COL.DKP_AMNT],
                        lastOnline
                    );
            end
        end
    end

    SOTA:OpenTextModalReadOnly(result)
end

function module:SOTA_GUILDEXTRACT_REQUEST()
    SOTA:RequestUpdateGuildRoster()

    self.extractRequested = true
    SOTA:Print("Guild Extract job added, waiting for guild roster update...")
end

function module:GetLastOnline(guildIndex)
    local year, month, day, hour = GetGuildRosterLastOnline(guildIndex);
    local lastOnline;
    if ((year == 0) or (year == nil)) then
        if ((month == 0) or (month == nil)) then
            if ((day == 0) or (day == nil)) then
                if ((hour == 0) or (hour == nil)) then
                    lastOnline = LASTONLINE_MINS;
                else
                    lastOnline = format(GetText("LASTONLINE_HOURS", nil, hour), hour);
                end
            else
                lastOnline = format(GetText("LASTONLINE_DAYS", nil, day), day);
            end
        else
            lastOnline = format(GetText("LASTONLINE_MONTHS", nil, month), month);
        end
    else
        lastOnline = format(GetText("LASTONLINE_YEARS", nil, year), year);
    end
    return lastOnline;
end
