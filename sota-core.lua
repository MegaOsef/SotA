SOTAG = AceLibrary("AceAddon-2.0"):new(
	"AceEvent-2.0",
	"AceConsole-2.0",
	"AceDB-2.0",
	"AceModuleCore-2.0",
	"AceDebug-2.0"
)

local SOTA = SOTAG

--[[
--	SotA - State of the Art DKP Addon
--	By Mimma <VanillaGaming.org>
--
--	Unit: sota-core.lua
--	This unit contains the core functionality such as DKP handling,
--	utility functions and frame text output.
--	The sota-core.xml file contains templates used across all UI's.
--]]

local SOTA_MESSAGE_PREFIX				= "SOTAv1"
local SOTA_ID							= "SOTA"
local SOTA_TITLE						= "SotA"
local SOTA_TITAN_TITLE				= "SotA - DKP Distribution"

local SOTA_DEBUG_ENABLED		= false;

-- Max # of lines for class dkp displayed locally when using "/sota class":
local MAX_CLASS_DKP_DISPLAYED	= 10;

-- Max # of lines for class dkp	sent by whisper:
local MAX_CLASS_DKP_WHISPERED	= 5;

-- true if a DKP job is already running
local JobIsRunning				= false

local RaidRosterLazyUpdate		= false;

local MSG                    = {
	ON_DKPADDED = "%i DKP was added to %s",
	ON_DKPADDED_RAID = "%i DKP was added to all players in raid",
	ON_DKPREPLACED = "%s was replaced with %s (%i DKP)",
	ON_DKP_SUBTRACT = "%i DKP was subtracted from %s",
	ON_DKP_SUBTRACT_RAID = "%i DKP was subtracted from all players in raid",
}

SOTA_GUILDNOTE               = {
	USEOFFICER = 0,
	USEPUBLIC = 1,
}
local DKPSTRING_LENGTH  = 5;

RT_COL                 = {
	PNAME = 1,
	DKP_AMNT = 2,
	CLASS = 3,
	GRANK = 4,
	ONLINE = 5,
	ZONE = 6,
	GRANK_IDX = 7
}

function SOTA:Broadcast(channel, msg)
	if msg and channel and msg ~= "" then
		SendChatMessage(string.format("[%s] %s", SOTA_TITLE, msg), channel);
	end
end

function SOTA:Whisper(receiver, msg)
	if receiver == UnitName("player") then
		self:Print(msg);
	else
		SendChatMessage(msg, "WHISPER", nil, receiver);
	end
end


--[[
--	Returns:
--	0: If player was not found or not assistant/leader
--	1: If player is assistant
--	2: If player is leader
--]]
function SOTA:GetRaidRank(playername)	
	if(self:IsInRaid(true)) then	
		for n=1, GetNumRaidMembers(), 1 do
			local name, rank = GetRaidRosterInfo(n);
			if name == playername then
				return rank;
			end
		end
	end	
	return 0;
end

function SOTA:IsInRaid(silentMode)
	local result = ( GetNumRaidMembers() > 0 )
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


function SOTA:GetUnitIDFromGroup(playerName)
	playerName = self:UCFirst(playerName);

	if self:IsInRaid(false) then
		for n=1, GetNumRaidMembers(), 1 do
			if UnitName("raid"..n) == playerName then
				return "raid"..n;
			end
		end
	else
		for n=1, GetNumPartyMembers(), 1 do
			if UnitName("party"..n) == playerName then
				return "party"..n;
			end
		end				
	end
	
	return nil;
end



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
	self:Debug("GUILD_ROSTER_UPDATE",
	"self:CanReadNotes():", self:CanReadNotes(),
	"self:CanDoDKP():", self:CanDoDKP(),
	"JobIsRunning:", JobIsRunning)
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
	local NewGuildRosterTable = { }
	
	for n=1,memberCount,1 do
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


--
--	Raid Roster Functions
--

--[[
--	Get information belonging to a specific player in the guild.
--	Returns NIL if player was not found.
--]]
function SOTA:GetGuildPlayerInfo(player)
	player = self:UCFirst(player);

	for n=1, table.getn(self.guildRosterTable), 1 do
		if self.guildRosterTable[n][RT_COL.PNAME] == player then
			return self.guildRosterTable[n];
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
		self.raidRosterTable = { }
		local index = 1
		local memberCount = table.getn(self.guildRosterTable);
		for n=1,playerCount,1 do
			local name, _, _, _, class = GetRaidRosterInfo(n);

			for m=1,memberCount,1 do
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


--
--	DKP handling
--

function SOTA:Call_CheckPlayerDKP(playername, sender)
	if playername then
		playername = self:UCFirst(playername);
	else
		playername = UnitName("player");
	end		

	local dkp = self:GetDKP(playername);
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


function SOTA:Call_CheckClassDKP(playerclass, sender)
	if playerclass then
		playerclass = self:UCFirst(playerclass);
	else
		playerclass = UnitClass("player");
	end		

	local classtable = { }
	for n=1, table.getn(self.guildRosterTable), 1 do
		if self.guildRosterTable[n][RT_COL.CLASS] == playerclass then
			classtable[ table.getn(classtable) + 1] = self.guildRosterTable[n];
		end
	end

	self:SortTableDescending(classtable, RT_COL.DKP_AMNT);
	
	if sender then
		self:Whisper(sender, string.format("Top %d DKP for %ss:", MAX_CLASS_DKP_WHISPERED, playerclass));
		for n=1, table.getn(classtable), 1 do
			if n <= MAX_CLASS_DKP_WHISPERED then
				self:Whisper(sender, string.format("%d - %s: %d DKP", n, classtable[n][RT_COL.PNAME], 1*(classtable[n][RT_COL.DKP_AMNT])));
			end
		end
	else
		self:Print(string.format("Top %d DKP for %ss:", MAX_CLASS_DKP_DISPLAYED, playerclass));
		for n=1, table.getn(classtable), 1 do
			if n <= MAX_CLASS_DKP_DISPLAYED then
				self:Print(string.format("%d - %s: %d DKP", n, classtable[n][RT_COL.PNAME], 1*(classtable[n][RT_COL.DKP_AMNT])));
			end
		end
	end
end


--[[
--	Get DKP belonging to a specific player.
--	Returns NIL if player was not found. Players with no DKP will return 0.
--]]
function SOTA:GetDKP(playername)
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
function SOTA:Call_AddPlayerDKP(playername, dkp)
	if self:CanDoDKP() then
		RaidState = RAID_STATE_ENABLED;
		self:AddJob( function(job) self:AddPlayerDKP(job[2], job[3]) end, playername, dkp )
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
function SOTA:Call_SubtractPlayerDKP(playername, dkp)
	if self:CanDoDKP() and tonumber(dkp) then
		RaidState = RAID_STATE_ENABLED;
		self:AddJob( function(job) self:SubtractPlayerDKP(job[2], job[3]) end, playername, dkp )
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
function SOTA:Call_AddRaidDKP(dkp)
	if self:IsInRaid(true) then
		RaidState = RAID_STATE_ENABLED;
		self:AddJob( function(job) self:AddRaidDKP(job[2]) end, dkp, "_" )
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
		local tidChanges = { }

		local raidRoster = self:GetRaidRoster();
		for n=1, table.getn(raidRoster), 1 do
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
function SOTA:Call_SubtractRaidDKP(dkp)
	if self:IsInRaid(true) then
		RaidState = RAID_STATE_ENABLED;
		self:AddJob( function(job) self:SubtractRaidDKP(job[2]) end, dkp, "_" )
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
		local tidChanges = { }
		
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
		for n=1, table.getn(raidRoster), 1 do
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
function SOTA:Call_Decaytest(percent)
	self:AddJob( function(job) self:Decaytest(job[2]) end, percent, "_" )
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
		self:Print("Guild Decay test cancelled: Percent is not a valid number: ".. percent);
		return false;
	end
	
	percent = abs(1 * percent);

	local tidIndex = 1;
	local tidChanges = { };

	local reducedDkp = 0;
	local playerCount = 0;

	--	Iterate over all guilded players - online or not
	local name, publicNote, officerNote
	local memberCount = GetNumGuildMembers();
	for n=1,memberCount,1 do
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
			note = note..self:CreateDkpString(dkp);
		end
	end
	
	self:Print("Testing Guild DKP decay using a "..percent.."% decay value.");
	self:Print("Decay will remove a total of "..reducedDkp.." DKP from ".. playerCount .." players.")
	
	return true;
end


--[[
--	Perform Guild Decay of <n>% DKP
--	This function requires Show Offline Members to be enabled.
--]]
function SOTA:Call_DecayDKP(percent)
	self:AddJob( function(job) self:DecayDKP(job[2]) end, percent, "_" )
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
			self:Print("Guild Decay cancelled: Percent is not a valid number: ".. percent);
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
	local tidChanges = { };

	local reducedDkp = 0;
	local playerCount = 0;

	--	Iterate over all guilded players - online or not
	local name, publicNote, officerNote
	local memberCount = GetNumGuildMembers();
	for n=1,memberCount,1 do
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
			note = note..self:CreateDkpString(dkp);
		end
		
		if SOTA.db.realm.UseGuildNotes == SOTA_GUILDNOTE.USEPUBLIC then
			GuildRosterSetPublicNote(n, note);
		else
			GuildRosterSetOfficerNote(n, note);
		end
		
		self:UpdateLocalDKP(name, dkp);
	end
	
	if not silentmode then
		SOTA:Broadcast(SOTA.CHANNEL.GUILD, "Guild DKP decay by "..percent.."% was performed by ".. UnitName("player") ..".")
		SOTA:Broadcast(SOTA.CHANNEL.GUILD, "Guild DKP removed a total of "..reducedDkp.." DKP from ".. playerCount .." players.")
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
	for n=1,memberCount,1 do
		name, _, _, _, _, _, publicNote, officerNote = GetGuildRosterInfo(n);
		if name == playername then
			local note = officerNote;
			if SOTA.db.realm.UseGuildNotes == SOTA_GUILDNOTE.USEPUBLIC then
				note = publicNote;
			end
		
			local _, _, dkp = string.find(note, "<(-?%d*)>");

			if dkp and tonumber(dkp)  then
				dkp = (1 * dkp) + dkpValue;
				note = string.gsub(note, "<(-?%d*)>", self:CreateDkpString(dkp), 1);
			else
				dkp = dkpValue;
				note = note..self:CreateDkpString(dkp);
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

	local raidRoster = self:GetRaidRoster();	--{ Name, DKP, Class, Rank, Online }
	for n=1, table.getn(raidRoster),1 do
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
		local dkpStr = "".. abs(dkp)
		while string.len(dkpStr) < dkpLen do
			dkpStr = "0"..dkpStr;
		end
		if dkp < 0 then
			dkpStr = "-"..dkpStr;
		end				
		result = "<"..dkpStr..">";
	else
		result = "<"..dkp..">";
	end
	
	return result;
end

function SOTA:OnInitialize()
	--	List of {jobname,name,dkp} tables
	self.jobQueue          = {}

	-- Guild Roster: table of guild players:	{ Name, DKP, Class, Rank(text), Online, Zone, Rank(value) }
	-- Use RT_COL for cols id.
	self.guildRosterTable = {}

	-- Raid Roster: table of raid players:		Same as GuildRosterTable.
	-- Use RT_COL for cols id.
	self.raidRosterTable   = {}

	self.CHANNEL           = {
		WARN = "RAID_WARNING",
		RAID = "RAID",
		PARTY = "PARTY",
		YELL = "YELL",
		SAY = "SAY",
		GUILD = "GUILD",
		WHISPER = "WHISPER",
	}
end


function SOTA:OnEnable()
	self:SetDebugging(false)
	self:Print(string.format("Loot Distribution Addon version %s by %s", GetAddOnMetadata("SOTA", "Version"), GetAddOnMetadata("SOTA", "Author")));

	SOTA:RegisterDB("SOTADB")
	SOTA:RegisterDefaults("realm",
		{
			DisableDashboard = 0,
			UseGuildNotes = SOTA_GUILDNOTE.USEOFFICER,
			HistoryDkp = {},
			ItemPriorities = {},
		}
	)

	self:RegisterChatCommand({ "/SOTA" }, function(input) self:HandleSOTACommand(input) end)
    
	self:RegisterEvent("ENTERING_WORLD");
	self:RegisterEvent("GUILD_ROSTER_UPDATE");
	--self:RegisterEvent("RAID_ROSTER_UPDATE");
	--self:RegisterEvent("CHAT_MSG_ADDON");

    
	self:RefreshRaidRoster();
	
	self:RequestUpdateGuildRoster()
	
	self:ScheduleRepeatingEvent("SOTA_RequestUpdateGuildRoster", self.RequestUpdateGuildRoster, 5, self)
end

--[[
--	/SOTA - main command entry handler
--]]
function SOTA:HandleSOTACommand(msg)
	local playername = UnitName("player");
	local sign;

	--	Command: <item>
	--	Syntax: "<itemlink>"
	local _, _, itemId = string.find(msg, "item:(%d+):")
	if itemId then
		self:TriggerEvent("SOTA_STARTAUCTION", msg);
		return
	end

		
	-- Split command into cmd (mandatory) and arg (optional)
	msg = string.lower(msg);
	local cmd, arg;
	local playerclass, playerrole;
	
	local spacepos = string.find(msg, "%s");
	if spacepos then
		_, _, cmd, arg = string.find(msg, "(%S+)%s+(.+)");
	else
		cmd = msg;
	end


	--	Command: help
	--	Syntax: "config"	
	if cmd == "help" or cmd == "?" or cmd == "" then
		self:DisplayHelp();
		return;	
	end


	--	Command: config
	--	Syntax: "config"	
	if cmd == "cfg" or cmd == "config" then
		SOTA_OpenConfigurationUI();
		return;	
	end



	--	Command: version
	--	Syntax: "version"
	if cmd == "version" then
			self:Print(string.format("%s is using SOTA version %s", UnitName("player"), GetAddOnMetadata("SOTA", "Version")));
		return;
	end
	
	
	--	Command: log
	--	Syntax: "log"
	if cmd == "log" then
		if arg and tonumber(arg) then
			SOTA_selectedTransactionID = arg;
			SOTA_RefreshTransactionDetails();
			SOTA_OpenTransactionDetails();
		else	
			SOTA_OpenTransauctionUI();
		end
		return;
	end

	--	Command: clearhistory
	--	Syntax: "clear", "clearhistory"
	if (cmd == "clear") or (cmd == "clearhistory") then
		return SOTA_ClearLocalHistory(arg);
	end

	--	Command: dkp
	--	Syntax: "dkp [<playername>]"
	if cmd == "dkp" then
		return self:Call_CheckPlayerDKP(arg);
	end

	--	Command: class
	--	Syntax: "class [<classname>]"
	if cmd == "class" then
		return self:Call_CheckClassDKP(arg);
	end

	if cmd == "raid" then
		sign = string.sub(arg, 1, 1);
		--	Command: raid
		--	Syntax: "raid -<%d>"
		if sign == "-" then
			arg = string.sub(arg, 2);
			return self:Call_SubtractRaidDKP(arg);
		--	Command: raid
		--	Syntax: "raid +<%d>"
		elseif sign == "+" then
			arg = string.sub(arg, 2);
			return self:Call_AddRaidDKP(arg);
		else
			self:Print("DKP must be written as +999 or -999");
			return;
		end
	end


	--	Command: decay
	--	Syntax: "decay <%d>[%]"
	if cmd == "decay" then
		return self:Call_DecayDKP(arg);		
	end


	--	Command: decaytest
	--	Syntax: "decaytest <%d>[%]"
	if cmd == "decaytest" then
		return self:Call_Decaytest(arg);		
	end


	--	Ok, the <cmd> is not a known command; we assume it is a "/SOTA [+-]<dkp>" command.
	-- TODO: Add some regex check: something like "[+-]%d+[%]"
	sign = string.sub(cmd, 1, 1);


	--	Command: +
	--	Syntax: "+<%d> <playername>"
	if sign == "+" then
		local cmd = string.sub(cmd, 2);
		return self:Call_AddPlayerDKP(arg, cmd);
	end
	

	if sign == "-" then
		cmd = string.sub(cmd, 2);		
		--	Command: -
		--	Syntax: "-<%d> <playername>"
		return self:Call_SubtractPlayerDKP(arg, cmd);
	end
	
	self:Print("Unknown command: ".. msg);
end



function SOTA:DisplayHelp()
	SOTA:Print(string.format("SOTA version %s options:", GetAddOnMetadata("SOTA", "Version")));
	SOTA:Print("Syntax: /sota [option], where options are:");
	--	DKP request options:
	SOTA:Print("DKP Requests:");
	SOTA:Print("  DKP <p>    Show how much DKP the player <p> currently have. Default is current player.");
	SOTA:Print("  Class <c>    Show top 10 DKP for the class <c>. Default is the current player's class.");
	SOTA:Print("");
	--	Player DKP:
	SOTA:Print("Player DKP:");
	SOTA:Print("  +<dkp> <p>    Add <dkp> to the player <p>.");
	SOTA:Print("  -<dkp> <p>    Subtract <dkp> from the player <p>.");
	SOTA:Print(
	"  -<pct>%s <p>   Subtract <pct> %s DKP from the player <p>. A minimum subtracted amount can be configured in the DKP options.",
		"%", "%");
	SOTA:Print("");
	--	Raid DKP:
	SOTA:Print("Raid DKP:");
	SOTA:Print("  raid +<dkp>    Add <dkp> to all players in raid.");
	SOTA:Print("  raid -<dkp>    Subtract <dkp> from all players in raid.");
	SOTA:Print("  decay <pct>%s    Remove <pct> percent DKP from every player in the guild.", "%");
	SOTA:Print("");
	--	Misc:
	SOTA:Print("Miscellaneous:");
	SOTA:Print("  Config    Open the SotA configuration screen.");
	SOTA:Print("  Log    Open the SotA transaction log screen.");
	--SOTA:Print("  Master    Request SotA master status.");
	SOTA:Print("  <item>    Start an auction for <item>.");
	SOTA:Print("  Version    Display the SotA client version.");
	SOTA:Print("  Help    (default) This help!");
	SOTA:Print("");
	return false;
end


function SOTA:IsPromoted()
	if not self:IsInRaid(true) then
		return false;
	end 

	local playername = UnitName("player");

	local members = GetNumRaidMembers();
	for n=1, members, 1 do
		local name, rank = GetRaidRosterInfo(n);
		--SOTA:Print(string.format("Player %s (%s) rank is %d", name, playername, rank))
		
		if(name == playername and rank > 0) then
			return true;
		end
	end
	return false;
end