local SOTA = SOTAG

--[[
--	Returns:
--	0: If player was not found or not assistant/leader
--	1: If player is assistant
--	2: If player is leader
--]]
function SOTA:GetRaidRank(playername)
    if (self:IsInRaid(true)) then
        for n = 1, GetNumRaidMembers(), 1 do
            local name, rank = GetRaidRosterInfo(n);
            if name == playername then
                return rank;
            end
        end
    end
    return 0;
end

function SOTA:IsInRaid(silentMode)
    local result = (GetNumRaidMembers() > 0)
    if not silentMode and not result then
        self:Print("You must be in a raid!");
    end
    return result
end

function SOTA:CanReadNotes()
    local result = true
    if SOTA.db.realm.UseGuildNotes == SOTA_GUILDNOTE.USEPUBLIC then
        -- Guild notes can always be read; there is no WOW setting for that.
        result = true;
    else
        result = CanViewOfficerNote();
    end
    return result
end

function SOTA:CanWriteNotes()
    local result = false
    if SOTA.db.realm.UseGuildNotes == SOTA_GUILDNOTE.USEPUBLIC then
        result = CanEditPublicNote();
    else
        result = CanViewOfficerNote() and CanEditOfficerNote();
    end
    return result
end

function SOTA:IsPromoted()
	if not self:IsInRaid(true) then
		return false;
	end

	local playername = UnitName("player");

	local members = GetNumRaidMembers();
	for n = 1, members, 1 do
		local name, rank = GetRaidRosterInfo(n);
		--SOTA:Print(string.format("Player %s (%s) rank is %d", name, playername, rank))

		if (name == playername and rank > 0) then
			return true;
		end
	end
	return false;
end