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

local function getPlayerRaidRank()
    local playername = UnitName("player");

    local members = GetNumRaidMembers();
    for n = 1, members, 1 do
        local name, rank = GetRaidRosterInfo(n);
        if (name == playername) then
            return rank;
        end
    end
    return -1;
end

function SOTA:IsPromoted()
	if not self:IsInRaid(true) then
		return false;
	end

    if getPlayerRaidRank() > 0 then
        return true;
    end

	return false;
end

function SOTA:IsRaidLeader()
	if not self:IsInRaid(true) then
		return false;
	end

    if getPlayerRaidRank() == 2 then
        return true;
    end

	return false;
end

function SOTA:IsMasterLoot()
    if not self:IsInRaid(true) then
        return false;
    end
    local lootmethod, masterlootIdx= GetLootMethod()
    if lootmethod ~= "master" then -- Not master looter ?
        return false;
    end

    if masterlootIdx == 0 then -- Is player master looter ?
        return true;
    end

    return false;
end
