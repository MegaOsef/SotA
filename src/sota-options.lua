--[[
--	SotA - State of the Art DKP Addon
--	By Mimma <VanillaGaming.org>
--
--	Unit: sota-options.lua
--	This holds the options (configuration) dialogue of SotA plus
--	underlying functionality to support changing the options.
--]]

local SOTA = SOTAG

local SOTA_MAX_MESSAGES			= 15
local ConfigurationDialogOpen	= false;

--	Settings (persisted)
-- Pane 1:
local SOTA_CONFIG_Messages			= { }	-- Contains configurable raid messages (if any)


--function SOTA_EchoEvent(msgKey, item, dkp, bidder, rank, param1, param2, param3)
--	local msgInfo = SOTA_getConfigurableMessage(msgKey, item, dkp, bidder, rank, param1, param2, param3);
--	publicEcho(msgInfo);
--end;


function SOTA_GetEventText(eventName)
	local messages = SOTA_GetConfigurableTextMessages();

	for n = 1, table.getn(messages), 1 do
		if(messages[n][1] == eventName) then
			return messages[n];
		end;
	end

	return nil;
end;

function SOTA_SetConfigurableMessage(event, channel, message)
	--echo("Saving new message: Event: "..event..", Channel: "..channel..", Message: "..message);
	local messages = SOTA_GetConfigurableTextMessages();

	for n=1,table.getn(messages),1 do
		if(messages[n][1] == event) then
			messages[n] = { event, channel, message };
			SOTA_SetConfigurableTextMessages(messages);
			return;
		end;
	end;
end;


function SOTA_OpenConfigurationUI()
	ConfigurationDialogOpen = true;

	SOTA_OpenBiddingConfig();
end

function SOTA_CloseConfigurationUI()
	SOTA_CloseAllConfig();

	ConfigurationDialogOpen = false;
end

function SOTA_CloseAllConfig()
	FrameConfigBidding:Hide();
end;

function SOTA_SaveRules_OnClick()
	SOTA_CONFIG_BIDRULES = SOTA_GetBidRules();
end;

function SOTA_ToggleConfigurationUI()
	if ConfigurationDialogOpen then
		SOTA_CloseConfigurationUI();
	else
		SOTA_OpenConfigurationUI();
	end;
end;

function SOTA_OpenBiddingConfig()
	SOTA_CloseAllConfig();
	FrameConfigBidding:Show();
end

function SOTA_OpenMessageConfig()
	SOTA_CloseAllConfig();
	FrameConfigMessage:Show();
end

function SOTA_OpenBidRulesConfig()
	SOTA_SetBidRules();
	SOTA_CloseAllConfig();
	FrameConfigBidRules:Show();
end;

function SOTA_OpenSyncCfgConfig()
	SOTA_CloseAllConfig();
	SOTA_RequestUpdateConfigVersion();
	FrameConfigSyncCfg:Show();
end;

function SOTA_OnOptionAuctionExtensionChanged(object)
	SOTA_CONFIG_AuctionExtension = tonumber( getglobal(object:GetName()):GetValue() );
	
	local valueString = "".. SOTA_CONFIG_AuctionExtension;
	if SOTA_CONFIG_AuctionExtension == 0 then
		valueString = "(No extension)";
	end
		
	getglobal(object:GetName().."Text"):SetText(string.format("Auction Extension: %s seconds", valueString))
end

function SOTA:ENTERING_WORLD()
	getglobal("FrameConfigBiddingDisableDashboard"):SetChecked(SOTA.db.realm.DisableDashboard);

	SOTA_VerifyEventMessages();
end


--function SOTA_VerifyEventMessages()
--
--	-- Syntax: [index] = { EVENT_NAME, CHANNEL, TEXT }
--	-- Channel value: 0: Off, 1: RW, 2: Raid, 3: Guild, 4: Yell, 5: Say
--	local defaultMessages = { 
--		{ SOTA_MSG_OnOpen			, 1, "Auction open for $i" },
--		{ SOTA_MSG_OnAnnounceBid	, 2, "/w $s bid <your bid>" },
--		{ SOTA_MSG_OnAnnounceMinBid	, 2, "Minimum bid: $m DKP" },
--		{ SOTA_MSG_On10SecondsLeft	, 2, "10 seconds left for $i" },
--		{ SOTA_MSG_On9SecondsLeft	, 2, "9 seconds left" },
--		{ SOTA_MSG_On8SecondsLeft	, 0, "8 seconds left" },
--		{ SOTA_MSG_On7SecondsLeft	, 0, "7 seconds left" },
--		{ SOTA_MSG_On6SecondsLeft	, 0, "6 seconds left" },
--		{ SOTA_MSG_On5SecondsLeft	, 0, "5 seconds left" },
--		{ SOTA_MSG_On4SecondsLeft	, 0, "4 seconds left" },
--		{ SOTA_MSG_On3SecondsLeft	, 2, "3 seconds left" },
--		{ SOTA_MSG_On2SecondsLeft	, 2, "2 seconds left" },
--		{ SOTA_MSG_On1SecondLeft	, 2, "1 second left" },
--		{ SOTA_MSG_OnMainspecBid	, 1, "$b ($r) is bidding $d DKP for $i" },
--		{ SOTA_MSG_OnOffspecBid		, 1, "$b is bidding $d Off-spec for $i" },
--		{ SOTA_MSG_OnMainspecMaxBid	, 1, "$b ($r) went all in ($d DKP) for $i" },
--		{ SOTA_MSG_OnOffspecMaxBid	, 1, "$b went all in ($d) Off-spec for $i" },
--		{ SOTA_MSG_OnComplete		, 2, "$i sold to $b for $d DKP." },
--		{ SOTA_MSG_OnPause			, 2, "Auction has been Paused" },
--		{ SOTA_MSG_OnResume			, 2, "Auction has been Resumed" },
--		{ SOTA_MSG_OnClose			, 1, "Auction for $i is over" },
--		{ SOTA_MSG_OnCancel			, 1, "Auction was Cancelled" },
--		{ SOTA_MSG_OnDKPAdded		, 1, "$d DKP was added to $b" },
--		{ SOTA_MSG_OnDKPAddedRaid	, 1, "$d DKP was added to all players in raid" },
--		{ SOTA_MSG_OnDKPAddedRange	, 1, "$d DKP has been added for $1 players in range." },
--		{ SOTA_MSG_OnDKPSubtract	, 1, "$d DKP was subtracted from $b" },
--		{ SOTA_MSG_OnDKPSubtractRaid, 1, "$d DKP was subtracted from all players in raid" },
--		{ SOTA_MSG_OnDKPPercent		, 1, "$1 % ($d DKP) was subtracted from $b" },
--		{ SOTA_MSG_OnDKPShared		, 1, "$1 DKP was shared ($d DKP per player)" },
--		{ SOTA_MSG_OnDKPSharedRange , 1, "$1 DKP was shared for $2 players in range ($d DKP per player)" },
--		{ SOTA_MSG_OnDKPReplaced	, 1, "$1 was replaced with $2 ($d DKP)" }
--	}
--
--	-- Merge default messages into saved messages; in case we added some new event names.
--	local messages = SOTA_GetConfigurableTextMessages();
--	if not messages or table.getn(messages) == 0 then
--		SOTA_SetConfigurableTextMessages(defaultMessages);
--		return;
--	end;
--
--	--echo("--- Merging messages");
--	for n=1,table.getn(defaultMessages), 1 do
--		local foundMessage = false;
--		for f=1,table.getn(messages), 1 do
--			if(messages[f][1] == defaultMessages[n][1]) then
--				foundMessage = true;
----				echo("Found msg: ".. messages[f][1]);
--				break;
--			end;
--		end;
--
--		if(not foundMessage) then
----			echo("Adding message: ".. defaultMessages[n][1]);
--			messages[table.getn(messages)+1] = defaultMessages[n];
--		end;
--	end
--
--	SOTA_SetConfigurableTextMessages(messages);
--end;


function SOTA_HandleCheckbox(checkbox)
	local checkboxname = checkbox:GetName();

	--	Disable Dashboard:		
	if checkboxname == "FrameConfigBiddingDisableDashboard" then
		if checkbox:GetChecked() then
			SOTA.db.realm.DisableDashboard = 1;
			SOTA_CloseDashboard();
		else
			SOTA.db.realm.DisableDashboard = 0;
		end
		return;
	end

	
	--	Store DKP in Public Notes:		
	if checkboxname == "FrameConfigMiscDkpPublicNotes" then
		if checkbox:GetChecked() then
			SOTA.db.realm.UseGuildNotes = SOTA_GUILDNOTE.USEPUBLIC;
		else
			SOTA.db.realm.UseGuildNotes = SOTA_GUILDNOTE.USEOFFICER;
		end
		return;
	end
end

function SOTA_Conf_ImportBossDkpList_close()
	getglobal("SOTA_ConfigurationImportBossDkpList"):Hide()
end

function SOTA_Conf_ImportBossDkpList_open()
	getglobal("SOTA_ConfigurationImportBossDkpList"):Show()
end

function SOTA_Conf_ImportBossDkpList_import()
	local jsonstr = getglobal("SOTA_ConfigurationImportBossDkpListScrollFrameMessage"):GetText()
	local bossDkpList, err = SOTA.json.decode(jsonstr)
	if not bossDkpList then
		SOTA:Print("Error while trying to parse json:", err)
		return
	end

	SOTA.db.realm.BossDKPList = bossDkpList.bosses
	self:TriggerEvent("SOTA_BOSSDKP_UPDATED")

	getglobal("SOTA_ConfigurationImportBossDkpList"):Hide()
end

function SOTA_Conf_ImportItemPriorities_close()
	getglobal("SOTA_ConfigurationImportItemPriorities"):Hide()
end

function SOTA_Conf_ImportItemPriorities_open()
	getglobal("SOTA_ConfigurationImportItemPriorities"):Show()
end

function SOTA_Conf_ImportItemPriorities_import()
	local jsonstr = getglobal("SOTA_ConfigurationImportItemPrioritiesScrollFrameMessage"):GetText()
	local itemPriorities, err = SOTA.json.decode(jsonstr)
	if not itemPriorities then
		SOTA:Print("Error while trying to parse json:", err)
		return
	end

	SOTA.db.realm.ItemPriorities = itemPriorities.items
	--local loadedCounter = table.getn(SOTA.db.realm.ItemPriorities)
	--SOTA:debug(loadedCounter, "priorities loaded.")
	self:TriggerEvent("SOTA_ITEMPRIOS_UPDATED")

	getglobal("SOTA_ConfigurationImportItemPriorities"):Hide()
end
