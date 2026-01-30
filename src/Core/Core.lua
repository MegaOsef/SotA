SOTAG                      = AceLibrary("AceAddon-2.0"):new(
	"AceEvent-2.0",
	"AceConsole-2.0",
	"AceDB-2.0",
	"AceModuleCore-2.0",
	"AceDebug-2.0"
)

local SOTA                 = SOTAG

local SOTA_DEBUG_ENABLED   = false;

-- true if a DKP job is already running
local JobIsRunning         = false

local RaidRosterLazyUpdate = false;

SOTA_GUILDNOTE             = {
	USEOFFICER = 0,
	USEPUBLIC = 1,
}



function SOTA:OnInitialize()
	--	List of {jobname,name,dkp} tables
	self.jobQueue         = {}

	-- Guild Roster: table of guild players:	{ Name, DKP, Class, Rank(text), Online, Zone, Rank(value) }
	-- Use RT_COL for cols id.
	self.guildRosterTable = {}

	-- Raid Roster: table of raid players:		Same as GuildRosterTable.
	-- Use RT_COL for cols id.
	self.raidRosterTable  = {}

	self.CHANNEL          = {
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
	self:SetDebugging(SOTA_DEBUG_ENABLED)
	self:Print(string.format("Loot Distribution Addon version %s by %s", GetAddOnMetadata("SOTA", "Version"),
		GetAddOnMetadata("SOTA", "Author")));

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
	self:RegisterEvent("RAID_ROSTER_UPDATE", "RefreshRaidRoster");

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
		self:TriggerEvent("SOTA_REQUEST_AUCTION", msg);
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
		return self:PrintPlayerDkp(arg);
	end

	--	Command: class
	--	Syntax: "class [<classname>]"
	if cmd == "class" then
		return self:PrintClassDkp(arg);
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

	self:Print("Unknown command: " .. msg);
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
