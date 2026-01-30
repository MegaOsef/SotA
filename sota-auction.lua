--[[
--	SotA - State of the Art DKP Addon
--	By Mimma <VanillaGaming.org>
--
--	Unit: sota-auction.lua
--	The Auction UI is controlled by this unit, which includes the Bidding
--	framework, timing and overall DKP control.
--]]

local SOTA = SOTAG

local module = SOTA:NewModule("Auctions", "AceEvent-2.0")

--	State machine:
local AUCTION_STATE = {
	NONE = 0,
	STARTING = 10,
	RUNNING = 20,
	PAUSED = 30,
	COMPLETE = 40,
}

local AUCTION_TIME           = 8
local AUCTION_EXTENSION_TIME = 8

local MINIMUM_BID = 10

local SELBID_COLS            = {
	PNAME = 1, -- playerr's name
	BID_AMNT = 2, -- Bid Amount
	BID_TP = 3, -- Bid Type (BIDTYPE value)
}

local BIDSTABLE_COLS         = {
	-- UNIQUE KEY
	PNAME = 1, -- Player's name
	BID_AMNT = 2, -- Bid Amount
	BID_TP = 3, -- Bid Type (BIDTYPE value)

	-- INFORMATIONS
	CLASS = 4,
	GRANK = 5,
	GRANK_IDX = 6,
}
local BIDTYPE                = {
	MS = 1,
	OS = 2,
}

local MSG                    = {
	ON_OPEN                = "Auction open for %s",
	ON_ANNOUNCEMINBID      = "Minimum bid: %i DKP",
	ONPAUSE                = "Auction has been Paused",
	ONRESUME               = "Auction has been Resumed",
	ONCOMPLETE             = "Auction for %s is over",
	ONCANCEL               = "Auction was Cancelled",
	ONDECLAREWINNER        = "%s sold to %s for %i DKP (%s).",
	ONCOMPLETE_WITHWIN     = "%s won %s for %d DKP (%s)",
	ONCOMPLETE_WITHOUTWIN  = "No bids received for %s",
	ONCANCELBID_WITHOUTWIN = "Bid of %s for %i DKP (%s) has been removed. There is no winner.",
	ONCANCELBID_WITHWIN    = "Bid of %s for %i DKP (%s) has been removed. Current winner is %s for %i DKP (%s).",
}

local function BidTypeToText(bidtype)
	if bidtype == BIDTYPE.MS then
		return "MS"
	elseif bidtype == BIDTYPE.OS then
		return "OS"
	else
		bidtype = bidtype or "nil"
		SOTA:Print("Error: BidTypeToText(" .. bidtype .. "), unknown bidtype")
	end
end

local function BidTypeStrToValue(bidtypestr)
	if bidtypestr == "MS" then
		return BIDTYPE.MS
	end
	if bidtypestr == "OS" then
		return BIDTYPE.OS
	end

	SOTA:Print("Error: BidTypeStrToValue(" .. bidtypestr .. "), unknown bidtype")
	return nil
end

-- Max # of bids shown in the AuctionUI
local MAX_BIDS					= 10
-- List of valid bids: { Name, DKP, BidType(MS=1,OS=2), Class, RankName, RankIndex }

-- Working variables:

function module:OnEnable()
	-- Instanciate variables.
	self.auctionState = AUCTION_STATE.NONE
	self.secondsCounter = 0
	self.auctionedItemLink = ""
	self.incomingBidsTable = {};

	self:SetAuctionState(AUCTION_STATE.NONE, 0);

	self:ScheduleRepeatingEvent("SOTA_CheckAuctionState", self.CheckAuctionState, 1, self) -- TODO Put it back to 1sec ? 0.9 is for the lag.

	self:RegisterEvent("CHAT_MSG_RAID")
	self:RegisterEvent("CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID")
	self:RegisterEvent("SOTA_STARTAUCTION")

	self:AuctionUIInit()
end

--[[
getters and setters
--]]
function module:GetSecondsCounter()
	return self.secondsCounter
end
function module:SetSecondsCounter(value)
	SOTA:Debug("SetSecondsCounter("..value..")")
	self.secondsCounter = value
end
function module:GetAuctionState()
	return self.auctionState;
end
function module:SetAuctionState(auctionState, seconds)
	if not seconds then
		seconds = 0;
	end
	SOTA:Debug("module:SetAuctionState " .. auctionState .. " " .. seconds)
	self.auctionState = auctionState;
	self:SetSecondsCounter(seconds);
end

function module:FindItemPriority(itemId)
	local prioTableCounter = table.getn(SOTA.db.realm.ItemPriorities)
	for n = 1, prioTableCounter, 1 do
		local p = SOTA.db.realm.ItemPriorities[n]
		if p.item_id == itemId then
			return p
		end
	end
	return nil
end

--[[
--	Start the auction, and set state to STATE_STARTING
--	Parameters:
--	itemLink: a Blizzard itemlink to auction.
--	Since 0.0.1
--]]
function module:SOTA_STARTAUCTION(itemLink)
	local rank = SOTA:GetRaidRank(UnitName("player"));
	if rank < 1 then
		SOTA:Print("You need to be Raid Assistant or Raid Leader to start auctions.");
		return;
	end

	self.auctionedItemLink = itemLink;
	
	-- Extract ItemId from itemLink string:
	local _, _, itemId = string.find(itemLink, "item:(%d+):")
	if not itemId then
		SOTA:Print("Item was not found: ".. itemLink);
		return;
	end
	itemId = tonumber(itemId) -- String to number.

	local itemName, _, itemQuality, _, _, _, _, _, itemTexture = GetItemInfo(itemId);	
	
	local frame = getglobal("AuctionUIFrameItem");
	if frame then
		local rgb = SOTA:GetQualityColor(itemQuality);	
		local itemNameFrame = getglobal(frame:GetName().."ItemName");
		itemNameFrame:SetText(itemName);
		itemNameFrame:SetTextColor( (rgb[1]/255), (rgb[2]/255), (rgb[3]/255), 1);
		
		local itemTextureFrame = getglobal(frame:GetName().."ItemTexture");
		if itemTextureFrame then
			itemTextureFrame:SetTexture(itemTexture);
		end

		local itemPrioFrame = getglobal(frame:GetName() .. "ItemPriority");
		local itemNotesFrame = getglobal(frame:GetName() .. "ItemNotes");
		itemPrioFrame:SetText("")
		itemNotesFrame:SetText("")

		local prioFound = self:FindItemPriority(itemId)
		if prioFound then
			if prioFound.priority then
				itemPrioFrame:SetText(string.format("Priority: %s", prioFound.priority))
			end
			if prioFound.notes then
				itemNotesFrame:SetText(string.format("Notes: %s", prioFound.notes))
			end
		end
	end
	
	self.incomingBidsTable = { };
	self:RefreshGUIBidsList();
	self:OpenAuctionUI();
	
	self:SetAuctionState(AUCTION_STATE.STARTING, AUCTION_TIME);
end


--[[
--	There's a message in the Raid channel - investigate that!
--]]
function module:CHAT_MSG_RAID(message, sender)
	if (not message) or (message == "") then
		return;
	end
	
	-- Parse RavenDKP bid messages: [RavenDKP] |c<color>spec dkp|r
	local a,_,bidtype,dkp = string.find(message, "%[RavenDKP%] |c%x%x%x%x%x%x%x%x(%a+) (%d+)|r")
	if bidtype and dkp then
		local bidMessage = string.lower(bidtype) .. " " .. dkp;
		SOTA:Debug("Master: Processing RavenDKP bid from ".. sender ..": ".. bidMessage);
		self:HandlePlayerBid(sender, bidMessage);
	end
end


--[[
--	The big SOTA state machine.
--	Since 0.0.1
--]]
function module:CheckAuctionState()
	local state = self:GetAuctionState();
	
	SOTA:Debug(string.format("SOTA_CheckAuctionState called, state = %d, secs = %d", state, self:GetSecondsCounter()));

	if state == AUCTION_STATE.NONE or state == AUCTION_STATE.PAUSED then
		return;
	end

	local secs = self:GetSecondsCounter()
	if state == AUCTION_STATE.STARTING then
		-- Broadcast auction starting messages.
		SOTA:Broadcast(SOTA.CHANNEL.WARN, string.format(MSG.ON_OPEN, self.auctionedItemLink))
		SOTA:Broadcast(SOTA.CHANNEL.RAID, string.format(MSG.ON_ANNOUNCEMINBID, MINIMUM_BID))
		self:SetAuctionState(AUCTION_STATE.RUNNING, secs)
	end
		
	if state == AUCTION_STATE.RUNNING then
		if secs < 1 then
			-- Time is up - complete the auction:
			self:FinishAuction();	
		end
		
		self:SetSecondsCounter(secs - 1)
	end
	
	--if state == AUCTION_STATE.COMPLETE then
	--	--	 We're idle
	--	self:SetAuctionState(AUCTION_STATE.NONE)
	--end

	self:RefreshButtonStates();
end


--[[
--	Handle incoming bid request.
--	Syntax: /sota bid|ms|os <dkp>|min|max
--	Since 0.0.1
--]]
function module:HandlePlayerBid(sender, message)
	local playerGuildInfos = SOTA:GetGuildPlayerInfo(sender);
	if not playerGuildInfos then
		SOTA:Whisper(sender, "You need to be in the guild to do bidding!");
		return;
	end

	local unitId = SOTA:GetUnitIDFromGroup(sender);
	if not unitId then
		-- The sender of the message was not in the raid; must be a normal whisper.
		return;
	end

	local availableDkp = 1 * (playerGuildInfos[RT_COL.DKP_AMNT]);
	
	local cmd, arg
	local spacepos = string.find(message, "%s");
	if spacepos then
		_, _, cmd, arg = string.find(string.lower(message), "(%S+)%s+(.+)");
	else
		return;
	end	

	-- Default is MS - if OS bidding is enabled, check bidtype:
	local bidtype = BIDTYPE.MS;
	if cmd == "os" then
		bidtype = BIDTYPE.OS;
	end

	local minimumBid = self:GetMinimumBid(bidtype);
	if not minimumBid then
		SOTA:Whisper(sender, "You cannot OS bid if an MS bid is already made.");
		return;
	end
	
	
	local dkp = tonumber(arg)	
	if not dkp then
		if arg == "min" then
			dkp = minimumBid;
		elseif arg == "max" then
			dkp = availableDkp;
		else
			-- This was not following a legal format; skip message
			return;
		end
	end	

	if not (self:GetAuctionState() == AUCTION_STATE.RUNNING) then
		SOTA:Whisper(sender, "There is currently no auction running - bid was ignored.");
		return;
	end	

	dkp = 1 * dkp

	local userWentAllIn = false;
	local highestBid = self:GetHighestBid(bidtype);

	local hiRankIndex = 0;
	local hiBid = self:GetStartingDKP();
	if highestBid then
		hiBid = highestBid[BIDSTABLE_COLS.BID_AMNT];
		hiRankIndex = highestBid[BIDSTABLE_COLS.GRANK_IDX];
	end;


	local bidderClass = playerGuildInfos[RT_COL.CLASS];		-- Info for the player placing the bid.
	local bidderRank  = playerGuildInfos[RT_COL.GRANK];		-- This rank is by NAME
	local bidderRIdx  = playerGuildInfos[RT_COL.GRANK_IDX];	-- This rank is by NUMBER!

	-- Check user at least did bid more than last bidder:
	if not(dkp > hiBid) then
		SOTA:Whisper(sender, string.format("Current highest bid is %s DKP - your bid of %s DKP was ignored.", hiBid, dkp));
		return;
	end;

	if(dkp > hiBid) then
		-- He did, but he also bid less than the minimum DKP:
		if (availableDkp < dkp) then
			-- If he doesnt have enough DKP, then let him go all out:
			if(availableDkp < minimumBid) and (availableDkp > hiBid) then
				dkp = availableDkp;
				userWentAllIn = true;
			else
				SOTA:Whisper(sender, string.format("You only have %d DKP - bid was ignored.", availableDkp));
				return;
			end;
		end
	end;

	if not(userWentAllIn) and (dkp < minimumBid) then
		SOTA:Whisper(sender, string.format("You must bid at least %s DKP - bid was ignored.", minimumBid));
		return;
	end


	-- Restarts auction timer.
	self:SetSecondsCounter(AUCTION_EXTENSION_TIME)

	self:RegisterBid(sender, dkp, bidtype, bidderClass, bidderRank, bidderRIdx);
	
		
	-- Checks to perform now:
	-- * Do user have enough DKP?	(Done)
	-- * Do user bid <minimum dkp>? (Done)
	--		* exception: if he goes all out he is allowed to go below minimum dkp
	-- * Is user already the highest bidder? (should we let users screw up? I personally think so!)

	-- OS/MS:
	--	- Check if MS>OS is enabled
	--	- MS bid: Check for highest MS bid (not OS bid)
	--	- OS bid: check of any MS bid was made previous, and skip if so!


	-- TODO:
	-- Hide incoming whispers for local player (how?)		
end


function module:DebugPrintIncomingBidsTable()
	--Debug output:
	for n=1, table.getn(self.incomingBidsTable), 1 do
		local cbid = self.incomingBidsTable[n];
		local name = cbid[BIDSTABLE_COLS.PNAME];
		local dkp  = cbid[BIDSTABLE_COLS.BID_AMNT];
		local type = BidTypeToText(cbid[BIDSTABLE_COLS.BID_TP])
		local clss = cbid[BIDSTABLE_COLS.CLASS];
		local rank = cbid[BIDSTABLE_COLS.GRANK];
		local indx = cbid[BIDSTABLE_COLS.GRANK_IDX];
		if(indx == nil) then
			indx = -1;
		end;
		SOTA:Debug(string.format("#%d %s: bid=%d DKP, type=%s, class=%s, rank=%s(%d)", n, name, dkp, type, clss, rank, indx));
	end
end

function module:RegisterBid(playername, bid, bidtype, playerclass, rankname, rankindex)

	self.incomingBidsTable = SOTA:RenumberTable(self.incomingBidsTable);
	
	self.incomingBidsTable[table.getn(self.incomingBidsTable) + 1] = { playername, bid, bidtype, playerclass, rankname, rankindex };

	-- Sort by DKP, then BidType (so MS bids are before OS bids)
	SOTA:SortTableDescending(self.incomingBidsTable, BIDSTABLE_COLS.BID_AMNT);
	SOTA:SortTableAscending(self.incomingBidsTable, BIDSTABLE_COLS.BID_TP);

	self:DebugPrintIncomingBidsTable()
 
	self:RefreshGUIBidsList();
end


function module:UnregisterBid(playername, bid, bidtype)
	playername = SOTA:UCFirst(playername);
	bid = 1 * bid;

	local bidInfo;
	for n=1,table.getn(self.incomingBidsTable), 1 do
		bidInfo = self.incomingBidsTable[n];
		if bidInfo[BIDSTABLE_COLS.PNAME] == playername and
			1 * (bidInfo[BIDSTABLE_COLS.BID_AMNT]) == bid and
			bidInfo[BIDSTABLE_COLS.BID_TP] == bidtype
		then
			table.remove(self.incomingBidsTable, n);

			self.incomingBidsTable = SOTA:RenumberTable(self.incomingBidsTable);
			self:DebugPrintIncomingBidsTable()
			
			self:RefreshGUIBidsList();
			self:SelectBid();
			return;
		end
	end
end

function module:GetBidInfo(playername, bid, bidtype)
	playername = SOTA:UCFirst(playername);
	bid = 1 * bid;

	local bidInfo;
	for n=1,table.getn(self.incomingBidsTable), 1 do
		bidInfo = self.incomingBidsTable[n];
		if bidInfo[BIDSTABLE_COLS.PNAME] == playername and
			1 * (bidInfo[BIDSTABLE_COLS.BID_AMNT]) == bid and
			bidInfo[BIDSTABLE_COLS.BID_TP] == bidtype then

			return bidInfo;
		end
	end

	return nil;
end


function module:DeclareWinner(playername, bid, bidtype)
	if playername and bid and bidtype then
		playername = SOTA:UCFirst(playername);
		bid = 1 * bid;
	
		AuctionUIFrame:Hide();
		
		SOTA:Broadcast(SOTA.CHANNEL.RAID,
			string.format(MSG.ONDECLAREWINNER, self.auctionedItemLink, playername, bid, BidTypeToText(bidtype)))
		
		SOTA:SubtractPlayerDKP(playername, bid)
	end
end


--
--	UI functions
--
function module:OpenAuctionUI()
	self:ClearSelectedPlayer();
	AuctionUIFrame:Show();
end


function module:AuctionUIInit()
	--	Initialize top <n> bids
	for n=1, MAX_BIDS, 1 do
		local entry = CreateFrame("Button", "$parentEntry"..n, AuctionUIFrameTableList, "SOTA_BidTemplate");
		entry:SetID(n);
		if n == 1 then
			entry:SetPoint("TOPLEFT", 4, -4);
		else
			entry:SetPoint("TOP", "$parentEntry"..(n-1), "BOTTOM");
		end
	end
end;

function module:FormatBidsListItemInfos(grank, class)
	return string.format("%s, %s", grank, class)
end

--[[
--	Show top <n> in bid window
--]]
function module:RefreshGUIBidsList()
	local bidder, bid, bidtype, playerclass, infos;
	for n=1, MAX_BIDS, 1 do
		if table.getn(self.incomingBidsTable) < n then
			bidder = "";
			bidtype = "";
			bid = "";
			playerclass = "";
			infos = "";
		else
			local cbid = self.incomingBidsTable[n];
			bidder = cbid[BIDSTABLE_COLS.PNAME];
			bidtype = BidTypeToText(cbid[BIDSTABLE_COLS.BID_TP])
			bid = string.format("%d", cbid[BIDSTABLE_COLS.BID_AMNT]);
			playerclass = cbid[BIDSTABLE_COLS.CLASS];
			infos = string.format("%s, %s", cbid[BIDSTABLE_COLS.GRANK], cbid[BIDSTABLE_COLS.CLASS])
		end

		local color = SOTA:GetClassColorCodes(playerclass);

		local frame = getglobal("AuctionUIFrameTableListEntry"..n);
		getglobal(frame:GetName().."Bidder"):SetText(bidder);
		getglobal(frame:GetName().."Bidder"):SetTextColor((color[1]/255), (color[2]/255), (color[3]/255), 255);
		--getglobal(frame:GetName().."Bid"):SetTextColor((bidcolor[1]/255), (bidcolor[2]/255), (bidcolor[3]/255), 255);
		getglobal(frame:GetName().."Bidtype"):SetText(bidtype);
		getglobal(frame:GetName().."Bid"):SetText(bid);
		getglobal(frame:GetName().."Infos"):SetText(infos);

		self:RefreshButtonStates();
		frame:Show();
	end
end


function module:GetSelectedBid()
	local selectedBid = nil;
	
	local frame = getglobal("AuctionUIFrameSelected");
	local bidder = getglobal(frame:GetName().."Bidder"):GetText();
	local bid = getglobal(frame:GetName().."Bid"):GetText();
	local bidtype = getglobal(frame:GetName().."Bidtype"):GetText();

	if bidder and bid and bidtype then
		selectedBid = { bidder, bid, bidtype };
	end

	return selectedBid;
end


--[[
--	Refresh button states
--]]
function module:RefreshButtonStates()
	local isAuctionRunning = (self:GetAuctionState() == AUCTION_STATE.RUNNING);
	local isAuctionPaused = (self:GetAuctionState() == AUCTION_STATE.PAUSED);

	local isBidderSelected = true;
	local selectedBid = self:GetSelectedBid();
	if not selectedBid then
		isBidderSelected = false;
	end	

	if isBidderSelected then
		if isAuctionRunning or isAuctionPaused then
			getglobal("AcceptBidButton"):Disable();
		else
			getglobal("AcceptBidButton"):Enable();
		end		
		getglobal("CancelBidButton"):Enable();
	else
		getglobal("AcceptBidButton"):Disable();
		getglobal("CancelBidButton"):Disable();
	end
	
	if isAuctionRunning or isAuctionPaused then
		getglobal("CancelAuctionButton"):Enable();
		getglobal("RestartAuctionButton"):Enable();
		getglobal("FinishAuctionButton"):Enable();
		if isAuctionPaused then
			getglobal("PauseAuctionButton"):Enable();
			getglobal("PauseAuctionButton"):SetText("Resume Auction");
		else
			getglobal("PauseAuctionButton"):Enable();
			getglobal("PauseAuctionButton"):SetText("Pause Auction");
		end
	else
		getglobal("CancelAuctionButton"):Enable();
		getglobal("RestartAuctionButton"):Enable();
		getglobal("FinishAuctionButton"):Disable();
		getglobal("PauseAuctionButton"):Disable();
		getglobal("PauseAuctionButton"):SetText("Pause Auction");
	end	
end


--[[
--	Accept a player bid
--	Since 0.0.3
--]]
function module:AcceptSelectedPlayerBid()
	local selectedBid = self:GetSelectedBid();
	if not selectedBid then
		return;
	end

	self:DeclareWinner(
		selectedBid[SELBID_COLS.PNAME],
		selectedBid[SELBID_COLS.BID_AMNT],
		BidTypeStrToValue(selectedBid[SELBID_COLS.BID_TP])
	)
end


--[[
--	Cancel a player bid
--	Since 0.0.3
--]]
function module:CancelSelectedBid()
	local currentState = self:GetAuctionState()
	if currentState ~= AUCTION_STATE.COMPLETE then
		SOTA:Print("Error: You can cancel a bid only when an auction is finished.")
		return;
	end

	local selectedBid = self:GetSelectedBid();
	if not selectedBid then
		return;
	end
	
	local previousBid = self:GetHighestBid();
	
	self:UnregisterBid(
		selectedBid[SELBID_COLS.PNAME],
		selectedBid[SELBID_COLS.BID_AMNT],
		BidTypeStrToValue(selectedBid[SELBID_COLS.BID_TP])
	);
	
	local highestBid = self:GetHighestBid();

	if highestBid then
		SOTA:Broadcast(SOTA.CHANNEL.RAID, string.format(MSG.ONCANCELBID_WITHWIN,
			selectedBid[SELBID_COLS.PNAME], selectedBid[SELBID_COLS.BID_AMNT], selectedBid[SELBID_COLS.BID_TP],
			highestBid[BIDSTABLE_COLS.PNAME], highestBid[BIDSTABLE_COLS.BID_AMNT],
			BidTypeToText(highestBid[BIDSTABLE_COLS.BID_TP])
		))
	else
		SOTA:Broadcast(SOTA.CHANNEL.RAID, string.format(MSG.ONCANCELBID_WITHOUTWIN,
			selectedBid[SELBID_COLS.PNAME], selectedBid[SELBID_COLS.BID_AMNT], selectedBid[SELBID_COLS.BID_TP]
		))
	end
end


--[[
--	Pause the Auction
--	Since 0.0.3
--]]
function module:PauseAuction()
	local state = self:GetAuctionState();	
	local secs = self:GetSecondsCounter()
	
	if state == AUCTION_STATE.RUNNING then
		self:SetAuctionState(AUCTION_STATE.PAUSED, 0);
		SOTA:Broadcast(SOTA.CHANNEL.RAID, MSG.ONPAUSE)
	end
	
	if state == AUCTION_STATE.PAUSED then
		self:SetAuctionState(AUCTION_STATE.RUNNING, AUCTION_EXTENSION_TIME);
		SOTA:Broadcast(SOTA.CHANNEL.RAID, MSG.ONRESUME)
	end

	self:RefreshButtonStates();
end


--[[
--	Finish the Auction
--	Since 0.0.3
--]]
function module:FinishAuction()
	local state = self:GetAuctionState();
	if state == AUCTION_STATE.RUNNING or state == AUCTION_STATE.PAUSED then
		SOTA:Broadcast(SOTA.CHANNEL.WARN, string.format(MSG.ONCOMPLETE, self.auctionedItemLink))

		self:SetAuctionState(AUCTION_STATE.COMPLETE);
		
		-- Check if a player was selected; if not, select highest bid:
		if table.getn(self.incomingBidsTable) > 0 then
			local selectedBid = self:GetSelectedBid();
			if not selectedBid then
				-- Force selection of the highest bid 
				self:SelectBid(
					self.incomingBidsTable[1][BIDSTABLE_COLS.PNAME],
					self.incomingBidsTable[1][BIDSTABLE_COLS.BID_AMNT],
					self.incomingBidsTable[1][BIDSTABLE_COLS.BID_TP]
				);
			end
			
			-- Auto-accept highest bid and announce winner
			local highestBid = self.incomingBidsTable[1];
			local winner = highestBid[BIDSTABLE_COLS.PNAME];
			local bidAmount = highestBid[BIDSTABLE_COLS.BID_AMNT];
			local bidType = highestBid[BIDSTABLE_COLS.BID_TP];
			local bidTypeText = BidTypeToText(bidType)
			
			SOTA:Broadcast(SOTA.CHANNEL.RAID, string.format(MSG.ONCOMPLETE_WITHWIN, winner, self.auctionedItemLink, bidAmount, bidTypeText));
		else
			SOTA:Broadcast(SOTA.CHANNEL.RAID, string.format(MSG.ONCOMPLETE_WITHOUTWIN, self.auctionedItemLink));
		end
	end
	
	self:RefreshButtonStates();
end


--[[
--	Cancel the Auction
--	Since 0.0.3
--]]
function module:CancelAuction()
	local state = self:GetAuctionState();

	local highestBid = self:GetHighestBid()
	local hasBid = (highestBid ~= nil)
	if state == AUCTION_STATE.RUNNING
		or state == AUCTION_STATE.PAUSED
		or (state == AUCTION_STATE.COMPLETE and hasBid) then
		self.incomingBidsTable = { }
		self:SetAuctionState(AUCTION_STATE.NONE);
		SOTA:Broadcast(SOTA.CHANNEL.WARN, MSG.ONCANCEL)
	end
	
	AuctionUIFrame:Hide();
end


--[[
--	Restart the Auction
--	Since 0.0.3
--]]
function module:RestartAuction()
	self:SetAuctionState(AUCTION_STATE.NONE)
	self:TriggerEvent("SOTA_STARTAUCTION", self.auctionedItemLink);
end


--[[
--	Show the selected (clicked) bidder information in AuctionUI.
--	Since 0.0.2
--]]
function module:SelectBid(playername, bid, bidtype)
	local bidInfo = nil
	if playername and bid and bidtype then
		bidInfo = self:GetBidInfo(playername, bid, bidtype)
	end
	
	local bidder, bidtype, bidtext, playerclass, infos;
	if not bidInfo then
		bidder = "";
		bidtext = "";
		bidtype = "";
		playerclass = "";
		infos = "";
	else
		bidder = bidInfo[BIDSTABLE_COLS.PNAME];
		bidtype = BidTypeToText(bidInfo[BIDSTABLE_COLS.BID_TP])
		bidtext = string.format("%d", bidInfo[BIDSTABLE_COLS.BID_AMNT]);
		playerclass = bidInfo[BIDSTABLE_COLS.CLASS];
		infos = self:FormatBidsListItemInfos(bidInfo[BIDSTABLE_COLS.GRANK], bidInfo[BIDSTABLE_COLS.CLASS])
	end
	
	local color = SOTA:GetClassColorCodes(playerclass);

	local frame = getglobal("AuctionUIFrameSelected");
	getglobal(frame:GetName().."Bidder"):SetText(bidder);
	getglobal(frame:GetName().."Bidder"):SetTextColor((color[1]/255), (color[2]/255), (color[3]/255), 255);
	getglobal(frame:GetName().."Bidtype"):SetText(bidtype);
	getglobal(frame:GetName().."Bid"):SetText(bidtext);
	getglobal(frame:GetName().."Infos"):SetText(infos);

	self:RefreshButtonStates();
end

function module:ClearSelectedPlayer()
	local frame = getglobal("AuctionUIFrameSelected");
	getglobal(frame:GetName().."Bidder"):SetText("");
	getglobal(frame:GetName().."Bid"):SetText("");
	getglobal(frame:GetName().."Bidtype"):SetText("");
	getglobal(frame:GetName().."Infos"):SetText("");
end


function module:GetHighestBid(bidtype)
	if bidtype and bidtype == BIDTYPE.MS then
		-- Find highest MS bid:
		for n=1, table.getn(self.incomingBidsTable), 1 do
			if self.incomingBidsTable[n][BIDSTABLE_COLS.BID_TP] == BIDTYPE.MS then
				return self.incomingBidsTable[n];
			end
		end
		return nil
	else
		--	Find highest bid regardless of type.
		--	Note: This might be an MS bid - OS bidders will have to ignore this!
		if table.getn(self.incomingBidsTable) > 0 then
			return self.incomingBidsTable[1];
		end
	end

	return nil;
end


function module:GetStartingDKP()
	return 0;
end


--[[
--	Get current minimum bid.
--	Bidtype is set if specific bid type is wanted. If nil (default), then all bid types are accepted.
--	bidtype 1 = MS
--	bidtype 2 = OS
--]]
function module:GetMinimumBid(bidtype)
	local minimumBid = MINIMUM_BID
	local highestBid = self:GetHighestBid(bidtype);

	if not highestBid then
		-- This is first bid = the minimum
		return minimumBid;
	end
	
	--	OS bidders cannot bid if a MS bid is already placed!
	if bidtype == BIDTYPE.OS
		and highestBid[BIDSTABLE_COLS.BID_TP] == BIDTYPE.MS then
		return nil
	end
	
	minimumBid = 1 * (highestBid[2]);

	minimumBid = minimumBid + 10; -- People have to bid 10 dkp more.

	return floor(minimumBid);
end;

function SOTA_GetMinimumBid(bidtype) -- Exposes globally
	return module:GetMinimumBid(bidtype)
end


-- UI Events
function SOTA_OnCancelBidClick(object)
	module:CancelSelectedBid();
end

function SOTA_OnPauseAuctionClick(object)
	module:PauseAuction();
end

function SOTA_OnFinishAuctionClick(object)
	module:FinishAuction();
end

function SOTA_OnRestartAuctionClick(object)
	module:RestartAuction();
end

function SOTA_OnAcceptBidClick(object)
	module:AcceptSelectedPlayerBid();
end

function SOTA_OnCancelAuctionClick(object)
	module:CancelAuction();
end

function SOTA_OnBidClick(object)
	-- local msgID = object:GetID();
	
	local bidder = getglobal(object:GetName().."Bidder"):GetText();
	if not bidder or bidder == "" then
		return;
	end	
	local bid = 1 * (getglobal(object:GetName().."Bid"):GetText());
	local bidtype= getglobal(object:GetName().."Bidtype"):GetText();

	module:SelectBid(bidder, bid, BidTypeStrToValue(bidtype))
end