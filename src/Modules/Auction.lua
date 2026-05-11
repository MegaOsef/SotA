--[[
--	SotA - State of the Art DKP Addon
--	By Mimma <VanillaGaming.org>
--
--	Unit: sota-auction.lua
--	The Auction UI is controlled by this unit, which includes the Bidding
--	framework, timing and overall DKP control.
--]]

local SOTA = SOTAG

local module = SOTA:NewModule("Auctions",
	"AceEvent-3.0",
	"AceTimer-3.0"
)

--	State machine:
local AUCTION_STATE = {
	NONE = 0,
	STARTING = 10,
	RUNNING = 20,
	PAUSED = 30,
	COMPLETE = 40,
}

local AUCTION_TIME           = 8
local AUCTION_EXTENSION_TIME = AUCTION_TIME

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
	ONDECLARENOWINNER      = "%s sold to no one as there was no bid.",
	ONCOMPLETE_WITHWIN     = "%s won %s for %d DKP (%s)",
	ONCOMPLETE_WITHOUTWIN  = "No bids received for %s",
	ONCANCELBID_WITHOUTWIN = "Bid of %s for %i DKP (%s) has been removed. There is no winner.",
	ONCANCELBID_WITHWIN    = "Bid of %s for %i DKP (%s) has been removed. Current winner is %s for %i DKP (%s).",
}

local RAIDS_INFO = SOTA.RAIDS_INFO

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
local MAX_BIDS  = 10

function module:OnEnable()
	self.auctionState = AUCTION_STATE.NONE
	self.secondsCounter = 0
	self.auctionedItemLink = ""
	self.selectedRaid = 0
	self.selectedBoss = 0

	-- List of valid bids: { Name, DKP, BidType(MS=1,OS=2), Class, RankName, RankIndex }
	self.incomingBidsTable = {};


	self:SetAuctionState(AUCTION_STATE.NONE, 0);

	self.CheckAuctionStateTimer = self:ScheduleRepeatingTimer(self.CheckAuctionState, 1, self) -- TODO Put it back to 1sec ? 0.9 is for the lag.

	self:RegisterEvent("CHAT_MSG_RAID")
	self:RegisterEvent("CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID")
	self:RegisterMessage("SOTA_REQUEST_AUCTION")

	self:AuctionUIInit()

end


--[[
getters and setters
--]]
function module:GetSecondsCounter()
	return self.secondsCounter
end
function module:SetSecondsCounter(value)
	--SOTA:Debug("SetSecondsCounter("..value..")")
	self.secondsCounter = value
end
function module:GetAuctionState()
	return self.auctionState;
end
function module:SetAuctionState(auctionState, seconds)
	if not seconds then
		seconds = 0;
	end
	SOTA:Debug("SetAuctionState("..auctionState..","..seconds..")")
	self.auctionState = auctionState;
	self:SetSecondsCounter(seconds);
end

function module:SOTA_REQUEST_AUCTION(_, itemLink, raidName, bossName)
	if self:GetAuctionState() == AUCTION_STATE.NONE then
		self:StartAuction(itemLink, raidName, bossName);
	else
		SOTA:Print("An auction is already running.")
	end
end

--[[
--	Start the auction, and set state to STATE_STARTING
--	Parameters:
--	itemLink: a Blizzard itemlink to auction.
--	Since 0.0.1
--]]
function module:StartAuction(itemLink, raidName, bossName)
	local rank = SOTA:GetRaidRank(UnitName("player"));
	if rank < 1 then
		SOTA:Print("You need to be Raid Assistant or Raid Leader to start auctions.");
		return;
	end

	SOTA:Debug("StartAuction: itemLink="..tostring(itemLink)..", raidName="..tostring(raidName)..", bossName="..tostring(bossName))

	self.auctionedItemLink = itemLink;
	
	local itemId = SOTA:GetItemIDFromLink(itemLink)
	if not itemId then
		SOTA:Print("Item was not found: ".. itemLink);
		return;
	end
	local itemName, _, itemQuality, _, _, _, _, _, itemTexture = GetItemInfo(itemId);	
	
	if self.itemFrame then
		local rgb = SOTA:GetQualityColor(itemQuality);	
		self.itemFrame.name:SetText(itemName);
		self.itemFrame.name:SetTextColor( (rgb[1]/255), (rgb[2]/255), (rgb[3]/255), 1);
		if self.itemFrame.texture then
			self.itemFrame.texture:SetTexture(itemTexture);
		end

		self.itemFrame.prio:SetText("")
		self.itemFrame.notes:SetText("")
		local prioFound = SOTA:FindItemPriority(itemId)
		if prioFound then
			if prioFound.priority then
				self.itemFrame.prio:SetText(string.format("Priority: %s", prioFound.priority))
			end
			if prioFound.notes then
				self.itemFrame.notes:SetText(string.format("Notes: %s", prioFound.notes))
			end
		end
	end

	self.incomingBidsTable = { };
	self:RefreshGUIBidsList();

	if raidName ~= nil and bossName ~= nil then -- Automatic auction start.
		local raidId = self:FindRaidByName(raidName);
		if raidId then
			self:SelectRaid(raidId);
			local bossId = self:FindBossByName(bossName)
			if not bossId then
				bossId = self:FindBossByName("Trashs")
			end

			if bossId then
				self:SelectBoss(bossId);
			else
				self:SelectBoss(0);
			end
		else
			self:SelectRaid(0);
			self:SelectBoss(0);
		end
	elseif raidName ~= nil and bossName == nil then -- Manual auction start.
		local raidId = self:FindRaidByName(raidName);
		if raidId then
			self:SelectRaid(raidId);
		else
			self:SelectRaid(0);
		end
		self:SelectBoss(0);
	end -- Else is auction restart: selected raid and boss are kept.

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
	
	if SOTA:IsMasterLoot() then
		-- Parse RavenDKP bid messages: [RavenDKP] |c<color>spec dkp|r
		local a,_,bidtype,dkp = string.find(message, "%[RavenDKP%] |c%x%x%x%x%x%x%x%x(%a+) (%d+)|r")
		if bidtype and dkp then
			local bidMessage = string.lower(bidtype) .. " " .. dkp;
			SOTA:Debug("Received bid message from "..sender..": "..bidMessage)
			self:HandlePlayerBid(sender, bidMessage);
		end
	end
end


--[[
--	The big SOTA state machine.
--	Since 0.0.1
--]]
function module:CheckAuctionState()
	local state = self:GetAuctionState();
	if state == AUCTION_STATE.NONE or state == AUCTION_STATE.PAUSED or state == AUCTION_STATE.COMPLETE then
		return;
	end
	
	SOTA:Debug(string.format("CheckAuctionState: state=%d, secs = %d", state, self:GetSecondsCounter()));

	local secs = self:GetSecondsCounter()
	if state == AUCTION_STATE.STARTING then
		-- Broadcast auction starting messages.
		SOTA:Broadcast(SOTA.CHANNEL.WARN, string.format(MSG.ON_OPEN, self.auctionedItemLink))
		SOTA:Broadcast(SOTA.CHANNEL.RAID, string.format(MSG.ON_ANNOUNCEMINBID, MINIMUM_BID))
		self:SetAuctionState(AUCTION_STATE.RUNNING, secs)
		state = self:GetAuctionState()
	end
		
	if state == AUCTION_STATE.RUNNING then
		if secs < 1 then
			-- Time is up - complete the auction:
			self:FinishAuction();
		end
		
		self:SetSecondsCounter(secs - 1)
	end
	
	self:RefreshButtonsState();
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
	local ravenLogs = SOTA:GetModule("RavenLogsForApp", true)
	if playername and bid and bidtype then
		playername = SOTA:UCFirst(playername);
		bid = 1 * bid;
		
		SOTA:Broadcast(SOTA.CHANNEL.RAID,
			string.format(MSG.ONDECLAREWINNER, self.auctionedItemLink, playername, bid, BidTypeToText(bidtype)))

		local auctionId = nil
        if ravenLogs then
			auctionId = ravenLogs:LogAuction(
				SOTA:GetItemIDFromLink(self.auctionedItemLink),
				RAIDS_INFO[self.selectedRaid].name,
				RAIDS_INFO[self.selectedRaid].bosses[self.selectedBoss],
				playername, bid, BidTypeToText(bidtype));
        end

		SOTA:SubtractPlayerDKP(playername, bid, SOTA.LOGTYPE.AUCTION, auctionId)
	else
		SOTA:Broadcast(SOTA.CHANNEL.RAID, string.format(MSG.ONDECLARENOWINNER, self.auctionedItemLink))
        if ravenLogs then
			ravenLogs:LogAuction(
				SOTA:GetItemIDFromLink(self.auctionedItemLink),
				RAIDS_INFO[self.selectedRaid].name,
				RAIDS_INFO[self.selectedRaid].bosses[self.selectedBoss]);
		end
	end
end


--
--	UI functions
--
function module:OpenAuctionUI()
	self:ClearSelectedPlayer();
	self.auctionFrame:Show();
end


function module:AuctionUIInit()
	--	Initialize top <n> bids
	for n=1, MAX_BIDS, 1 do
		local entry = CreateFrame("Button", "$parentEntry"..n, AuctionUIFrameTableList, "SOTA_BidTemplate");
		entry:SetID(n);
		if n == 1 then
			entry:SetPoint("TOPLEFT", 4, -20);
		else
			entry:SetPoint("TOP", "$parentEntry"..(n-1), "BOTTOM");
		end
	end

	-- Save frames in self, it's faster than getglobal().
	self.auctionFrame = AuctionUIFrame
	self.itemFrame = getglobal("AuctionUIFrameItem")
	self.itemFrame.name = getglobal(self.itemFrame:GetName().."ItemName");
	self.itemFrame.texture = getglobal(self.itemFrame:GetName().."ItemTexture");
	self.itemFrame.prio = getglobal(self.itemFrame:GetName().."ItemPriority");
	self.itemFrame.notes = getglobal(self.itemFrame:GetName().."ItemNotes");

	self.bidsFrames = {}
	for n=1, MAX_BIDS, 1 do
		self.bidsFrames[n]            = getglobal("AuctionUIFrameTableListEntry" .. n);
		self.bidsFrames[n].star       = getglobal(self.bidsFrames[n]:GetName() .. "Star");
		self.bidsFrames[n].bidder     = getglobal(self.bidsFrames[n]:GetName() .. "Bidder");
		self.bidsFrames[n].bidtype    = getglobal(self.bidsFrames[n]:GetName() .. "Bidtype");
		self.bidsFrames[n].bid        = getglobal(self.bidsFrames[n]:GetName() .. "Bid");
		self.bidsFrames[n].remaining  = getglobal(self.bidsFrames[n]:GetName() .. "Remaining");
		self.bidsFrames[n].role       = getglobal(self.bidsFrames[n]:GetName() .. "Role");
		self.bidsFrames[n].bg         = getglobal(self.bidsFrames[n]:GetName() .. "BG");
		self.bidsFrames[n]:Show();

		-- Close button per row (visible on hover)
		local closeBtn = CreateFrame("Button", self.bidsFrames[n]:GetName().."Close", self.bidsFrames[n], "UIPanelCloseButton")
		closeBtn:SetWidth(16)
		closeBtn:SetHeight(16)
		closeBtn:SetPoint("RIGHT", self.bidsFrames[n], "RIGHT", -2, 0)
		closeBtn:Hide()
		closeBtn:SetScript("OnClick", function()
			SOTA_OnRowRemoveBidClick(this)
		end)
		closeBtn:SetScript("OnEnter", function()
			this:Show()
		end)
		closeBtn:SetScript("OnLeave", function()
			this:Hide()
		end)
		self.bidsFrames[n].closeBtn = closeBtn
	end
	self.btns = {}
	self.btns.declareWinner       = getglobal("DeclareWinnerButton")
	self.btns.cancelAuction       = getglobal("CancelAuctionButton")
	self.btns.restartAuction      = getglobal("RestartAuctionButton")
	self.btns.finishAuction       = getglobal("FinishAuctionButton")
	self.btns.pauseAuction        = getglobal("PauseAuctionButton")

	-- Raid dropdown (custom styled widget)
	self.raidDropdown = SOTA:CreateDropdown("SOTARaidDropdown", self.auctionFrame, 212, "Select Raid")
	self.raidDropdown:GetFrame():SetPoint("TOPLEFT", self.auctionFrame, "TOPLEFT", 16, -152)
	local raidOptions = {}
	for n=1, table.getn(RAIDS_INFO), 1 do
		raidOptions[n] = { text = RAIDS_INFO[n].name, value = n }
	end
	self.raidDropdown:SetOptions(raidOptions)
	self.raidDropdown:SetOnChange(function(value, text)
		module:SelectRaid(value)
	end)

	-- Boss dropdown (custom styled widget, initially disabled)
	self.bossDropdown = SOTA:CreateDropdown("SOTABossDropdown", self.auctionFrame, 212, "Select Boss")
	self.bossDropdown:GetFrame():SetPoint("TOPLEFT", self.raidDropdown:GetFrame(), "TOPRIGHT", 6, 0)
	self.bossDropdown:SetEnabled(false)
	self.bossDropdown:SetOnChange(function(value, text)
		module:SelectBoss(value)
	end)
end;

--[[
--	Get player's remaining DKP after their bid.
--	Returns remaining DKP as a number, or nil if player info is not available.
--]]
function module:GetRemainingDKP(playername, bidamount)
	local playerInfo = SOTA:GetGuildPlayerInfo(playername)
	if playerInfo then
		return 1 * (playerInfo[RT_COL.DKP_AMNT]) - bidamount
	end
	return nil
end

--[[
--	Show top <n> in bid window
--]]
function module:RefreshGUIBidsList()
	local selectedBid = self:GetSelectedBid()
	local selectedName = selectedBid and selectedBid[SELBID_COLS.PNAME] or ""
	local selectedAmount = selectedBid and selectedBid[SELBID_COLS.BID_AMNT] or ""
	local selectedBidtype = selectedBid and selectedBid[SELBID_COLS.BID_TP] or ""

	local bidder, bid, bidtypeVal, bidtype, playerclass, remaining;
	for n=1, MAX_BIDS, 1 do
		if table.getn(self.incomingBidsTable) < n then
			bidder = "";
			bidtype = "";
			bid = "";
			bidtypeVal = nil;
			playerclass = "";
			remaining = "";
			if self.bidsFrames[n].closeBtn then
				self.bidsFrames[n].closeBtn:Hide()
				self.bidsFrames[n].closeBtn.hasBid = false
			end
		else
			local cbid = self.incomingBidsTable[n];
			bidder = cbid[BIDSTABLE_COLS.PNAME];
			bidtypeVal = cbid[BIDSTABLE_COLS.BID_TP];
			bidtype = BidTypeToText(bidtypeVal)
			bid = string.format("%d", cbid[BIDSTABLE_COLS.BID_AMNT]);
			playerclass = cbid[BIDSTABLE_COLS.CLASS];
			local rem = self:GetRemainingDKP(bidder, cbid[BIDSTABLE_COLS.BID_AMNT])
			if rem then
				remaining = string.format("%d", rem)
			else
				remaining = ""
			end
			if self.bidsFrames[n].closeBtn then
				self.bidsFrames[n].closeBtn.hasBid = true
			end
		end

		local color = SOTA:GetClassColorCodes(playerclass);

		-- Star indicator for selected bid
		local isSelected = (bidder ~= "" and bidder == selectedName and bid == selectedAmount and bidtype == selectedBidtype)
		if isSelected then
			self.bidsFrames[n].star:Show()
		else
			self.bidsFrames[n].star:Hide()
		end

		self.bidsFrames[n].bidder:SetText(bidder);
		self.bidsFrames[n].bidder:SetTextColor((color[1] / 255), (color[2] / 255), (color[3] / 255), 255);
		self.bidsFrames[n].bidtype:SetText(bidtype);
		self.bidsFrames[n].bid:SetText(bid);
		self.bidsFrames[n].remaining:SetText(remaining);

		-- Priority from guild roster roles config
		local roleText = ""
		if bidder ~= "" then
			local config = SOTA:GetPlayerGuildRosterRole(bidder)
			if config then
				roleText = config.priority
				self.bidsFrames[n].role:SetTextColor(1, 0.82, 0)
			else
				roleText = "Unknown"
				self.bidsFrames[n].role:SetTextColor(0.6, 0.6, 0.6)
			end
		end
		self.bidsFrames[n].role:SetText(roleText);

		-- MS/OS background color differentiation
		if bidtypeVal == BIDTYPE.OS then
			self.bidsFrames[n].bg:SetVertexColor(0.3, 0, 0.4, 0.5)
		else
			self.bidsFrames[n].bg:SetVertexColor(0, 0, 0.5, 0.5)
		end
	end

	self:RefreshButtonsState();
end


function module:GetSelectedBid()
	return self.selectedBidData
end


--[[
--	Refresh button states
--]]
function module:RefreshButtonsState()
	local isAuctionRunning = (self:GetAuctionState() == AUCTION_STATE.RUNNING);
	local isAuctionPaused = (self:GetAuctionState() == AUCTION_STATE.PAUSED);

	local isBidderSelected = true;
	local selectedBid = self:GetSelectedBid();
	if not selectedBid then
		isBidderSelected = false;
	end	

	if isBidderSelected then
		self.btns.declareWinner:SetText("Declare Winner")
	else
		self.btns.declareWinner:SetText("Declare no Winner")
	end
	
	if isAuctionRunning or isAuctionPaused then
		self.btns.cancelAuction:Disable();
		self.btns.restartAuction:Disable();
		self.btns.finishAuction:Enable();
		self.btns.declareWinner:Disable()
		if isAuctionPaused then
			self.btns.pauseAuction:Enable();
			self.btns.pauseAuction:SetText("Resume Auction");
		else
			self.btns.pauseAuction:Enable();
			self.btns.pauseAuction:SetText("Pause Auction");
		end
	else
		self.btns.declareWinner:Enable()
		self.btns.cancelAuction:Enable();
		self.btns.restartAuction:Enable();
		self.btns.finishAuction:Disable();
		self.btns.pauseAuction:Disable();
		self.btns.pauseAuction:SetText("Pause Auction");
	end	
end


--[[
--	Accept a player bid
--	Since 0.0.3
--]]
function module:DeclareAuctionWinner()
	if self.selectedRaid == 0 then
		SOTA:Print("Error: You must select a raid before declaring a winner.");
		return;
	end
	if self.selectedBoss == 0 then
		SOTA:Print("Error: You must select a boss before declaring a winner.");
		return;
	end

	local selectedBid = self:GetSelectedBid();
	local winnerName = selectedBid and selectedBid[SELBID_COLS.PNAME] or nil
	local itemLink = self.auctionedItemLink

	if not selectedBid then
		self:DeclareWinner()
	else
		self:DeclareWinner(
			selectedBid[SELBID_COLS.PNAME],
			selectedBid[SELBID_COLS.BID_AMNT],
			BidTypeStrToValue(selectedBid[SELBID_COLS.BID_TP])
		)
	end

	self:EndAuctionTransaction()

	if winnerName and SOTA.db.realm.AutoAssignLoot == 1 then
		self:TryAssignLoot(itemLink, winnerName)
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
	elseif state == AUCTION_STATE.PAUSED then
		self:SetAuctionState(AUCTION_STATE.RUNNING, AUCTION_EXTENSION_TIME);
		SOTA:Broadcast(SOTA.CHANNEL.RAID, MSG.ONRESUME)
	end

	self:RefreshButtonsState();
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
	
	self:RefreshButtonsState();
end


--[[
--	Cancel the Auction
--	Since 0.0.3
--]]
function module:CancelAuction()
	SOTA:Broadcast(SOTA.CHANNEL.WARN, MSG.ONCANCEL)
	self:EndAuctionTransaction()
end


--[[
--	Restart the Auction
--	Since 0.0.3
--]]
function module:RestartAuction()
	self:StartAuction(self.auctionedItemLink)
end

function module:EndAuctionTransaction()
	self.incomingBidsTable = {}
	self:SetAuctionState(AUCTION_STATE.NONE);
	self.auctionFrame:Hide();
end


function module:SelectBid(playername, bid, bidtype)
	if playername and bid and bidtype then
		local bidInfo = self:GetBidInfo(playername, bid, bidtype)
		if bidInfo then
			self.selectedBidData = {
				bidInfo[BIDSTABLE_COLS.PNAME],
				string.format("%d", bidInfo[BIDSTABLE_COLS.BID_AMNT]),
				BidTypeToText(bidInfo[BIDSTABLE_COLS.BID_TP])
			}
		else
			self.selectedBidData = nil
		end
	else
		self.selectedBidData = nil
	end

	self:RefreshGUIBidsList()
	self:RefreshButtonsState()
end

function module:ClearSelectedPlayer()
	self.selectedBidData = nil
	self:RefreshGUIBidsList()
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

function module:FindRaidByName(raidName)
	if not raidName then
		return nil, nil;
	end

	for n=1, table.getn(RAIDS_INFO), 1 do
		if RAIDS_INFO[n].name == raidName then
			return n, RAIDS_INFO[n]
		end
	end
	return nil, nil
end

function module:FindBossByName(bossName)
	for n=1, table.getn(RAIDS_INFO[self.selectedRaid].bosses), 1 do
		if RAIDS_INFO[self.selectedRaid].bosses[n] == bossName then
			return n, RAIDS_INFO[self.selectedRaid].bosses[n]
		end
	end
	return nil, nil;
end

function module:SelectRaid(raidId)
	self.selectedRaid = raidId;
	self.selectedBoss = 0;

	if self.raidDropdown then
		self.raidDropdown:SetSelectedValue(raidId)
	end

	-- Reset and rebuild boss dropdown
	if self.bossDropdown then
		self.bossDropdown:SetSelectedValue(0)
		if raidId >= 1 and raidId <= table.getn(RAIDS_INFO) then
			local bosses = RAIDS_INFO[raidId].bosses
			local bossOptions = {}
			for n=1, table.getn(bosses), 1 do
				bossOptions[n] = { text = bosses[n], value = n }
			end
			self.bossDropdown:SetOptions(bossOptions)
			self.bossDropdown:SetEnabled(true)
		else
			self.bossDropdown:SetOptions({})
			self.bossDropdown:SetEnabled(false)
		end
	end
end

function module:SelectBoss(bossId)
	self.selectedBoss = bossId;

	if self.bossDropdown then
		self.bossDropdown:SetSelectedValue(bossId)
	end
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


-- Confirmation popup for auto-assigning loot to auction winner
StaticPopupDialogs["SOTA_CONFIRM_ASSIGNLOOT"] = {
	text = "Assign loot to %s?\n%s",
	button1 = "Yes",
	button2 = "No",
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnAccept = function()
		module:AssignLootToWinner()
	end,
}

function module:FindLootCandidate(winnerName)
	for i = 1, 40 do
		local candidate = GetMasterLootCandidate(i)
		if candidate and candidate == winnerName then
			return i
		end
	end
	return nil
end

function module:TryAssignLoot(itemLink, winnerName)
	SOTA:Debug("TryAssignLoot: itemLink=" .. tostring(itemLink) .. ", winnerName=" .. tostring(winnerName))

	if not SOTA:IsMasterLoot() then
		SOTA:Debug("TryAssignLoot: not master looter, skipping")
		return
	end

	local numLoot = GetNumLootItems()
	if numLoot == 0 then
		SOTA:Debug("TryAssignLoot: no loot window open, skipping")
		return
	end

	SOTA:Debug("TryAssignLoot: scanning " .. numLoot .. " loot slots")
	for i = 1, numLoot do
		local slotLink = GetLootSlotLink(i)
		SOTA:Debug("TryAssignLoot: slot " .. i .. " link=" .. tostring(slotLink))
		if slotLink and slotLink == itemLink then
			SOTA:Debug("TryAssignLoot: found matching item in slot " .. i)
			local candidateIndex = self:FindLootCandidate(winnerName)
			if candidateIndex then
				SOTA:Debug("TryAssignLoot: winner found as candidate #" .. candidateIndex .. ", showing confirmation")
				self.assignLootSlot = i
				self.assignLootWinner = winnerName
				StaticPopup_Show("SOTA_CONFIRM_ASSIGNLOOT", winnerName, itemLink)
			else
				SOTA:Debug("TryAssignLoot: winner not a valid loot candidate for slot " .. i)
				SOTA:Print(winnerName .. " is not eligible to receive this item (e.g. chest loot).")
			end
			return
		end
	end
	SOTA:Debug("TryAssignLoot: item not found in loot window")
	SOTA:Print("Could not find " .. tostring(itemLink) .. " in the loot window. Assign it manually.")
end

function module:AssignLootToWinner()
	SOTA:Debug("AssignLootToWinner: slot=" .. tostring(self.assignLootSlot) .. ", winner=" .. tostring(self.assignLootWinner))

	if not self.assignLootSlot or not self.assignLootWinner then
		SOTA:Debug("AssignLootToWinner: missing slot or winner, aborting")
		return
	end

	local candidateIndex = self:FindLootCandidate(self.assignLootWinner)
	if candidateIndex then
		if SOTA.db.realm.DryRunAssignLoot == 1 then
			SOTA:Print("DRY RUN: Would assign loot slot " .. self.assignLootSlot .. " to " .. self.assignLootWinner .. " (candidate #" .. candidateIndex .. ")")
		else
			SOTA:Debug("AssignLootToWinner: giving loot slot " .. self.assignLootSlot .. " to candidate #" .. candidateIndex)
			GiveMasterLoot(self.assignLootSlot, candidateIndex)
		end
	else
		SOTA:Debug("AssignLootToWinner: winner no longer a valid candidate")
		SOTA:Print(self.assignLootWinner .. " is no longer a valid loot candidate. The loot window may have changed.")
	end

	self.assignLootSlot = nil
	self.assignLootWinner = nil
end

-- Confirmation popup for removing a bid from a row close button
StaticPopupDialogs["SOTA_CONFIRM_REMOVEBID"] = {
	text = "Remove bid of %s for %s?",
	button1 = "Yes",
	button2 = "No",
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnAccept = function()
		module:RemoveBidByInfo(module.removeBidPending)
	end,
}

function module:RemoveBidByInfo(bidInfo)
	if not bidInfo then
		return
	end

	local name = bidInfo[BIDSTABLE_COLS.PNAME]
	local bid = bidInfo[BIDSTABLE_COLS.BID_AMNT]
	local bidtype = bidInfo[BIDSTABLE_COLS.BID_TP]

	self:UnregisterBid(name, bid, bidtype)

	local highestBid = self:GetHighestBid()

	if highestBid then
		SOTA:Broadcast(SOTA.CHANNEL.RAID, string.format(MSG.ONCANCELBID_WITHWIN,
			name, bid, BidTypeToText(bidtype),
			highestBid[BIDSTABLE_COLS.PNAME], highestBid[BIDSTABLE_COLS.BID_AMNT],
			BidTypeToText(highestBid[BIDSTABLE_COLS.BID_TP])
		))
	else
		SOTA:Broadcast(SOTA.CHANNEL.RAID, string.format(MSG.ONCANCELBID_WITHOUTWIN,
			name, bid, BidTypeToText(bidtype)
		))
	end

	self:ClearSelectedPlayer()
	self:RefreshButtonsState()
end

-- Show/hide close button on bid row hover
function SOTA_OnBidRowEnter(row)
	if row.closeBtn and row.closeBtn.hasBid then
		row.closeBtn:Show()
	end
end

function SOTA_OnBidRowLeave(row)
	if row.closeBtn then
		row.closeBtn:Hide()
	end
end

-- Close button click on a bid row
function SOTA_OnRowRemoveBidClick(closeBtn)
	local row = closeBtn:GetParent()
	local bidder = getglobal(row:GetName().."Bidder"):GetText()
	if not bidder or bidder == "" then
		return
	end

	local currentState = module:GetAuctionState()
	if currentState ~= AUCTION_STATE.COMPLETE then
		SOTA:Print("Error: You can cancel a bid only when an auction is finished.")
		return
	end

	local bid = 1 * (getglobal(row:GetName().."Bid"):GetText())
	local bidtypeStr = getglobal(row:GetName().."Bidtype"):GetText()
	local bidtype = BidTypeStrToValue(bidtypeStr)

	local bidInfo = module:GetBidInfo(bidder, bid, bidtype)
	if not bidInfo then
		return
	end

	module.removeBidPending = bidInfo
	StaticPopup_Show("SOTA_CONFIRM_REMOVEBID", bidder, string.format("%d DKP (%s)", bid, bidtypeStr))
end

-- UI Events
function SOTA_OnPauseAuctionClick(object)
	module:PauseAuction();
end

function SOTA_OnFinishAuctionClick(object)
	module:FinishAuction();
end

function SOTA_OnRestartAuctionClick(object)
	module:RestartAuction();
end

function SOTA_OnDeclareWinnerClick(object)
	module:DeclareAuctionWinner();
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

