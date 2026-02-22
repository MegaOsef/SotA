--[[
--	SotA - State of the Art DKP Addon
--	By Mimma <VanillaGaming.org>
--
--	Unit: sota-transactionlog.lua
--	Transactions can be seen in the transaction UI. Simple DKP handling
--	in the UI is also possible, like swapping DKP for two people.
--]]

local SOTA = SOTAG

local module = SOTA:NewModule("LogsUI", "AceEvent-2.0")

local SOTA_COLOUR_INTRO				= "|c80F0F0F0"
local SOTA_COLOUR_CHAT				= "|c8040A0F8"


---- Max # of transaction logs shown in UI (excluding Header)
local MAX_TRANSACTIONS_DISPLAYED	= 18;


local TRANSACTION_STATE            = {
	ROLLEDBACK = 0,
	ACTIVE = 1,
}

--	Setting for transaction details screen:
local TRANSACTION_DETAILS = {
	ROWS    = 18,
	COLUMNS = 4,
}



-- Used for alternating "colours" in DKP History view.
local ALPHA_1 = 1.0;
local ALPHA_2 = 0.7;

function module:OnEnable()
	self.frameTrans = LogsUIFrameTransactionsList
	self.frameTrans.rows = {}

	self.frameDkpChg = LogsUIFrameDkpChangesList
	self.frameDkpChg.rows = {}

	self.btns = {}
	self.btns.prev = getglobal("BtnPrevPage")
	self.btns.next = getglobal("BtnNextPage")

	--  Transaction log: Contains a list of { timestamp, tid, author, description, state, { names, dkp } }
	--	Transaction state: 0=Rolled back, 1=Active (default),
	self.transactionLog           = {}

	self.currentTransactionID     = 0;

	--	Current transactionID, starts out as 0 (=none).
	self.selectedTransactionID    = nil;

	self.currentTransactionPage   = 1; -- Current page shown (1=first page)
	self.currentDetailsPage       = 1; -- Current page for transaction details view
	self.isTransactionUIOpen      = false;
	self.isTransactionDetailsOpen = false;

	self:TransactionLogUIInit()

	self:RegisterEvent("GUILD_ROSTER_UPDATE", "RefreshLogElements")
end


function module:RefreshLogElements()
	if self.isTransactionUIOpen then
		self:RefreshTransactionElements();
	elseif self.isTransactionDetailsOpen then
		self:RefreshTransactionDetails();
	end
end

function module:OpenTransactionsLogUI()
	self.isTransactionUIOpen = true;
	self.isTransactionDetailsOpen = false;

	self.frameTrans:Show();
	self.frameDkpChg:Hide();
	self.btns.prev:Show();
	self.btns.next:Show();
	
	self:RefreshLogElements();

	LogsUIFrame:Show();
end


function module:CloseTransactionUI()
	self.isTransactionUIOpen = false;
	self.isTransactionDetailsOpen = false;
	LogsUIFrame:Hide();
end

function module:ViewTransactionLog()
	self.currentTransactionPage = 1;
	self.isTransactionUIOpen = true;
	self.isTransactionDetailsOpen = false;
	self:RefreshLogElements();
	self:UpdatePageControls();
end;


function module:OpenTransactionDetails()
	self.isTransactionUIOpen = false;
	self.isTransactionDetailsOpen = true;
	self.currentDetailsPage = 1;

	self.frameTrans:Hide()
	self.frameDkpChg:Show()
	self.btns.prev:Show();
	self.btns.next:Show();
	self:UpdatePageControls();
end

function module:CloseTransactionDetails()
	self:OpenTransactionsLogUI();
end

function module:RefreshTransactionElements()
	if not self.isTransactionUIOpen then
		return;
	end

	local id, type, auctionId, bossName, officer
	
	local trLog = SOTA.db.realm.RavenLogsForApp.dkpTransactions
	
	local numTransactions = table.getn(trLog);
	for n=0, MAX_TRANSACTIONS_DISPLAYED, 1 do
		if n == 0 then
			id = "ID";
			type = "Type";
			auctionId = "Auction ID";
			bossName = "Boss name";
			officer = "Officer";
		else
			local index = n + ((self.currentTransactionPage - 1) * MAX_TRANSACTIONS_DISPLAYED);
			id = ""
			type = ""
			auctionId = ""
			bossName = ""
			officer = ""
			if numTransactions >= index then
				local tr = trLog[index];
				id = tr.id
				type = tr.type
				if tr.auctionId then
					auctionId = tr.auctionId
				end
				if tr.bossName then
					bossName = tr.bossName
				end
				officer = tr.officer

				--[[
				timestamp = tr[1];
				tid = tr[2];
				description = tr[4];
				state = tr[5];
				trInfo = tr[6];
				if trInfo and table.getn(trInfo) == 1 then
					name = trInfo[1][1];
					dkp = 1 * (trInfo[1][2]);
				else
					playerCount = table.getn(trInfo);
					dkp = 0;
					for f=1, playerCount, 1 do
						dkp = dkp + 1*(trInfo[f][2]);
					end
					dkp = ceil(dkp / playerCount);
					name = string.format("(%d players)", playerCount);
				end
				]]
			end
		end

		local icon = "";
		if tonumber(dkp) then
			if dkp > 0 then
				icon = "Interface\\ICONS\\Spell_ChargePositive";
			elseif dkp < 0 then
				icon = "Interface\\ICONS\\Spell_ChargeNegative";
			end
		end

		local frame = self.frameTrans.rows[n]
		frame.id:SetText(id)
		frame.type:SetText(type)
		frame.auctionId:SetText(auctionId)
		frame.bossName:SetText(bossName)
		frame.officer:SetText(officer)

		--if (n > 0) and SOTA:CanReadNotes() then
		--	local color = { 128, 128, 128 };
		--	-- state=1: only for active transactions
		--	if state == 1 then
		--		local guildInfo = SOTA:GetGuildPlayerInfo(name);
		--		if guildInfo then
		--			color = SOTA:GetClassColorCodes(guildInfo[RT_COL.CLASS]);
		--		end
		--	end
		--	getglobal(frame:GetName().."Name"):SetTextColor((color[1]/255), (color[2]/255), (color[3]/255), 255);
		--	frame:Enable();
		--else
		--	frame:Disable();
		--end

		frame:Show();
	end

	self:UpdatePageControls();
end


function module:UpdatePageControls()
--	BtnPrevPage:Disable();
--	BtnNextPage:Disable();
--	LogsUIFramePlayerList:Hide();
--	BtnBack:Hide();
--	UndoTransactionButton:Hide();
--	self.frameTrans:Hide();
--
--	if self.isDKPHistoryPageOpen then
--		-- DKP History log page:
--		DKPHistoryButton:Hide();
--		TransactionLogButton:Show();
--
--		-- Refresh navigation Buttons
--		local hrLog = self:GetIndividuelDKPHistory();
--		local numTransactions = table.getn(hrLog);
--		local numPages = ceil(numTransactions / MAX_TRANSACTIONS_DISPLAYED);
--
--		if self.currentTransactionPage > 1 then
--			BtnPrevPage:Enable();
--		end
--	
--		if numPages > self.currentTransactionPage then
--			BtnNextPage:Enable();
--		end
--
--		LogsUIFrameTitle:SetText("DKP History Log");
--		LogsUIFrameDKPHistory:Show();
--	else
--		-- Transaction log/details page:
--		-- Refresh navigation Buttons
--		local numTransactions = table.getn(self.transactionLog);
--		local numPages = ceil(numTransactions / MAX_TRANSACTIONS_DISPLAYED);
--
--		if self.currentTransactionPage > 1 then
--			BtnPrevPage:Enable();
--		end
--	
--		if numPages > self.currentTransactionPage then
--			BtnNextPage:Enable();
--		end
--
--		DKPHistoryButton:Show();
--
--		LogsUIFrameTitle:SetText("Transaction Log");
--		TransactionLogButton:Hide();
--		LogsUIFrameDKPHistory:Hide();
--
--		if self.isTransactionDetailsOpen then
--			BtnPrevPage:Hide();
--			BtnNextPage:Hide();
--			LogsUIFramePlayerList:Show();
--			BtnBack:Show();
--			UndoTransactionButton:Show();
--		else
--			LogsUIFrameTransactionsList:Show();
--		end;
--
--	end
end;

function module:PreviousTransactionUIPage()
	if self.isTransactionDetailsOpen then
		if self.currentDetailsPage > 1 then
			self.currentDetailsPage = self.currentDetailsPage - 1;
		end
		self:RefreshTransactionDetails();
		return;
	end

	if self.currentTransactionPage > 1 then
		self.currentTransactionPage = self.currentTransactionPage - 1;
	end
	self:RefreshLogElements();
end

function module:NextTransactionUIPage()
	if self.isTransactionDetailsOpen then
		local ravenLogs = SOTA:GetModule("RavenLogsForApp", true)
		if not ravenLogs then return end
		local transaction = ravenLogs:FindTransactionFromId(self.selectedTransactionID)
		if not transaction then return end
		local numChanges = table.getn(transaction.dkpChanges)
		local numPages = ceil(numChanges / MAX_TRANSACTIONS_DISPLAYED);
		if numPages > self.currentDetailsPage then
			self.currentDetailsPage = self.currentDetailsPage + 1;
		end
		self:RefreshTransactionDetails();
		return;
	end

	local numTransactions= table.getn(SOTA.db.realm.RavenLogsForApp.dkpTransactions)
	local numPages = ceil(numTransactions / MAX_TRANSACTIONS_DISPLAYED);

	if numPages > self.currentTransactionPage then
		self.currentTransactionPage = self.currentTransactionPage + 1;
	end
	self:RefreshLogElements();
end

function module:RefreshTransactionDetails()
	local ravenLogs = SOTA:GetModule("RavenLogsForApp", true)
	if not ravenLogs then
		SOTA:Print("Error: module RavenLogs not found")
		return
	end

	local transaction = ravenLogs:FindTransactionFromId(self.selectedTransactionID)
	if not transaction then
		SOTA:Print("Error: Transaction is not found " .. self.selectedTransactionID);
		return
	end

	local id, player, change
	local numTransactions = table.getn(transaction.dkpChanges);

	for n = 0, MAX_TRANSACTIONS_DISPLAYED, 1 do
		if n == 0 then
			id = "ID"
			player = "Player"
			change = "Change"
		else
			local index = n + ((self.currentDetailsPage - 1) * MAX_TRANSACTIONS_DISPLAYED);
			id = ""
			player = ""
			change = ""

			if numTransactions >= index then
				local chg = transaction.dkpChanges[index]

				id = chg.id
				player = chg.player
				change = chg.change
			end
		end

		SOTA:Debug(tostring(n), tostring(id), tostring(player), tostring(change))
		local frame = self.frameDkpChg.rows[n]
		frame.id:SetText(id)
		frame.player:SetText(player)
		frame.change:SetText(change)
		frame:Show()
	end
end


--[[
--	Initalize Transaction Log UI elements
--]]
function module:TransactionLogUIInit()
	for n=0,MAX_TRANSACTIONS_DISPLAYED, 1 do
		local lgEntry = CreateFrame("Button", "$parentEntry"..n, self.frameTrans, "SOTA_TransactionTemplate");
		local dhEntry = CreateFrame("Button", "$parentEntry"..n, self.frameDkpChg, "SOTA_DkpChangeTemplate");
		lgEntry:SetID(n);
		dhEntry:SetID(n);
		if n == 0 then
			lgEntry:SetPoint("TOPLEFT", 4, -4);
			dhEntry:SetPoint("TOPLEFT", 4, -4);
		else
			lgEntry:SetPoint("TOP", "$parentEntry"..(n-1), "BOTTOM");
			dhEntry:SetPoint("TOP", "$parentEntry"..(n-1), "BOTTOM");
		end

		self.frameTrans.rows[n] = lgEntry
		self.frameTrans.rows[n].id = getglobal(lgEntry:GetName() .. "Id")
		self.frameTrans.rows[n].type = getglobal(lgEntry:GetName() .. "Type")
		self.frameTrans.rows[n].auctionId = getglobal(lgEntry:GetName() .. "AuctionId")
		self.frameTrans.rows[n].bossName = getglobal(lgEntry:GetName() .. "BossName")
		self.frameTrans.rows[n].officer = getglobal(lgEntry:GetName() .. "Officer")

		self.frameDkpChg.rows[n] = dhEntry
		self.frameDkpChg.rows[n].id = getglobal(dhEntry:GetName() .. "Id")
		self.frameDkpChg.rows[n].player = getglobal(dhEntry:GetName() .. "Player")
		self.frameDkpChg.rows[n].change = getglobal(dhEntry:GetName() .. "Change")
	end
end


--[[
--	Get transaction with id=<tid>
--]]
function module:GetTransaction(transactionID)
	transactionID = 1 * transactionID;

	for n=1, table.getn(self.transactionLog), 1 do
		if (1 * self.transactionLog[n][2]) == transactionID then
			return self.transactionLog[n];
		end
	end
	return nil;
end


function module:OnTransactionLogClick(object)
	local msgID = object:GetID();
	self.selectedTransactionID = getglobal(object:GetName().."Id"):GetText();
	if not self.selectedTransactionID then
		return;
	end

	self:OpenTransactionDetails();
	self:RefreshTransactionDetails();
end

function module:OnTransactionLogDetailPlayer(object)
	if SOTA:CanWriteNotes() then
		local msgID = object:GetID();
		local playername = getglobal(object:GetName().."PlayerButton"):GetText();
	
		self:ToggleIncludePlayerInTransaction(playername);
	end;
end


function SOTA_OpenTransactionsLogUI()
	module:OpenTransactionsLogUI()
end

function SOTA_CloseTransactionUI()
	module:CloseTransactionUI()
end

function SOTA_ViewTransactionLog()
	module:ViewTransactionLog()
end

function SOTA_PreviousTransactionUIPage()
	module:PreviousTransactionUIPage()
end

function SOTA_NextTransactionUIPage()
	module:NextTransactionUIPage()
end

function SOTA_CloseTransactionDetails()
	module:CloseTransactionDetails()
end

function SOTA_RequestUndoTransaction()
	module:RequestUndoTransaction()
end

function SOTA_OnTransactionLogClick(obj)
	module:OnTransactionLogClick(obj)
end

function SOTA_OnTransactionLogDetailPlayer(obj)
	module:OnTransactionLogDetailPlayer(obj)
end

function SOTA_OnTransactionLogDetailPlayer(obj)
	module:SOTA_OnTransactionLogDetailPlayer(obj)
end