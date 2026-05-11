local SOTA = SOTAG

local module = SOTA:NewModule("Dashboard",
	"AceEvent-3.0",
	"AceTimer-3.0"
)

function module:OnEnable()
	self.lootsFrames = {}
	self.statsFrame = getglobal("SOTA_Dash_Stats")
	self.warnNotRL = getglobal("SOTA_DashWarn_NotRL")
	self.warnNotML = getglobal("SOTA_DashWarn_NotML")
	self.currentLootedMobName = nil
	self.warnedPlayers = {}

	self:RegisterMessage("SOTA_RAVENLOGS_UPDATED")
	self:RegisterMessage("SOTA_BOSS_KILLED")
	self:RegisterEvent("LOOT_OPENED")
	self:RegisterEvent("LOOT_SLOT_CLEARED", "RefreshLootsList")
	self:RegisterEvent("LOOT_CLOSED")
	self:RegisterEvent("RAID_ROSTER_UPDATE", "OnRaidRosterUpdate")
	self.OnSecondTimerTimer = self:ScheduleRepeatingTimer(self.OnSecondTimer, 1, self)

	self:OnSecondTimer()

	self:RefreshLootsList()

	self.bossDkpFrame = getglobal("DashboardUIFrameItemShareBossDkp")
	self.bossDkpFrame.texture = getglobal(self.bossDkpFrame:GetName() .. "IconTexture")
	self.bossDkpFrame.name = getglobal(self.bossDkpFrame:GetName() .. "BossName")
	self.bossDkpFrame.dkpValue = getglobal(self.bossDkpFrame:GetName() .. "DkpValue")

	self.bossDkpFrame.texture:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
	self.bossDkpFrame:Hide()
	self.cancelBossDkpButton = getglobal("DashboardUIFrameItemCancelBossDkp")
	self.cancelBossDkpButton:SetFrameLevel(self.bossDkpFrame:GetFrameLevel() + 1)
	self.cancelBossDkpButton:Hide()
end

function module:SOTA_RAVENLOGS_UPDATED(_)
	SOTA.db.realm.NeedsToExportRavenLogs = true
end

function module:LOOT_OPENED()
	self.currentLootedMobName = UnitName("target")
	self:RefreshLootsList()
end

function module:LOOT_CLOSED()
	self.currentLootedMobName = nil
	self:RefreshLootsList()
end

function module:RefreshLootsList()
	SOTA:Debug("RefreshLootsList: start, existing frames=" .. table.getn(self.lootsFrames) .. ", numLootItems=" .. GetNumLootItems())

	-- Hide all existing lootsFrames
	for i = 1, table.getn(self.lootsFrames), 1 do
		local frame = self.lootsFrames[i]
		if frame then
			frame:Hide()
			SOTA:Debug("RefreshLootsList: hiding frame #" .. i)
		end
	end

	local displayIndex = 0
	for lootSlot = 1, GetNumLootItems(), 1 do
		local itemLink = GetLootSlotLink(lootSlot)
		SOTA:Debug("Loot #"..lootSlot.." link: "..tostring(itemLink))
		if itemLink then
			local itemId = SOTA:GetItemIDFromLink(itemLink)
			if not itemId then
				SOTA:Print("Could not extract itemId from link: " .. tostring(itemLink))
				break
			end
			local itemName, itemSoftLink, itemRarity, _, _, _, _, _, _, itemTexture = GetItemInfo(itemId)
			local itemColor = SOTA:GetQualityColor(itemRarity)
			displayIndex = displayIndex + 1
			SOTA:Debug("Loot #" .. lootSlot .. " (display " .. displayIndex .. "): itemName=" .. tostring(itemName) .. ", itemRarity=" .. tostring(itemRarity) .. ", itemTexture=" .. tostring(itemTexture) .. ", itemSoftLink=" .. tostring(itemSoftLink))

			-- Do we need to create a new loot frame?
			if table.getn(self.lootsFrames) < displayIndex then
				SOTA:Debug("Loot #" .. lootSlot .. ": creating new frame (displayIndex=" .. displayIndex .. ")")
				local entry = CreateFrame("Button", "$parentEntry" .. displayIndex, DashboardUIFrameLootsList,
					"SOTA_LootTemplate");
				if displayIndex == 1 then
					entry:SetPoint("TOPLEFT", 0, 0);
				else
					entry:SetPoint("TOP", self.lootsFrames[displayIndex - 1], "BOTTOM");
				end
				SOTA:Debug("Loot #" .. lootSlot .. ": frame created, name=" .. tostring(entry:GetName()) .. ", parent=" .. tostring(entry:GetParent():GetName()))
				self.lootsFrames[displayIndex] = entry
				self.lootsFrames[displayIndex].itemName = getglobal(self.lootsFrames[displayIndex]:GetName() .. "ItemName");
				self.lootsFrames[displayIndex].itemTexture = getglobal(self.lootsFrames[displayIndex]:GetName() .. "ItemTexture");
				self.lootsFrames[displayIndex].itemLink = getglobal(self.lootsFrames[displayIndex]:GetName() .. "ItemLink");
				self.lootsFrames[displayIndex].itemSoftLink = getglobal(self.lootsFrames[displayIndex]:GetName() ..
				"ItemSoftLink");
				self.lootsFrames[displayIndex].itemPrio = getglobal(self.lootsFrames[displayIndex]:GetName() .. "ItemPrio");
				self.lootsFrames[displayIndex].itemNotes = getglobal(self.lootsFrames[displayIndex]:GetName() .. "ItemNotes");
				SOTA:Debug("Loot #" .. lootSlot .. ": refs - itemName=" .. tostring(self.lootsFrames[displayIndex].itemName) .. ", itemTexture=" .. tostring(self.lootsFrames[displayIndex].itemTexture) .. ", itemSoftLink=" .. tostring(self.lootsFrames[displayIndex].itemSoftLink))
			else
				SOTA:Debug("Loot #" .. lootSlot .. ": reusing existing frame, name=" .. tostring(self.lootsFrames[displayIndex]:GetName()))
			end

			self.lootsFrames[displayIndex]:Show()
			self.lootsFrames[displayIndex].itemName:SetText(itemName)
			self.lootsFrames[displayIndex].itemName:SetTextColor((itemColor[1] / 255), (itemColor[2] / 255),
				(itemColor[3] / 255),
				1);
			self.lootsFrames[displayIndex].itemTexture:SetTexture(itemTexture)
			self.lootsFrames[displayIndex].itemLink:SetText(itemLink)
			self.lootsFrames[displayIndex].itemSoftLink:SetText(itemSoftLink)

			-- Debug: verify what was actually set on the frame
			SOTA:Debug("Loot #" .. lootSlot .. " (display " .. displayIndex .. "): after SetText - visible=" .. tostring(self.lootsFrames[displayIndex]:IsVisible()) .. ", nameText=" .. tostring(self.lootsFrames[displayIndex].itemName:GetText()) .. ", textureFile=" .. tostring(self.lootsFrames[displayIndex].itemTexture:GetTexture()) .. ", color=(" .. tostring(itemColor[1]) .. "," .. tostring(itemColor[2]) .. "," .. tostring(itemColor[3]) .. ")")

			self.lootsFrames[displayIndex].itemPrio:SetText("")
			self.lootsFrames[displayIndex].itemNotes:SetText("")
			local prioFound = SOTA:FindItemPriority(itemId)
			if prioFound then
				if prioFound.priority then
					self.lootsFrames[displayIndex].itemPrio:SetText(string.format("Priority: %s", prioFound.priority))
				end
				if prioFound.notes then
					self.lootsFrames[displayIndex].itemNotes:SetText(string.format("Notes: %s", prioFound.notes))
				end
			end
		end
	end
	SOTA:Debug("RefreshLootsList: done, total frames=" .. table.getn(self.lootsFrames))
end

function module:SOTA_BOSS_KILLED(_, bossName, dkpValue)
	self.bossDkpFrame.name:SetText(bossName)
	self.bossDkpFrame.dkpValue:SetText("Dkp Value: " .. tostring(dkpValue))
	self.bossDkpFrame.numericDkpValue = dkpValue
	self.bossDkpFrame:Show()
	self.cancelBossDkpButton:Show()
	if SOTA:IsMasterLoot() then
		PlaySound("AuctionWindowClose")
	end
end

function module:OnSecondTimer()
	if SOTA.db.realm.DisableDashboard == 0 then
		SOTA_OpenDashboard();
	else
		SOTA_CloseDashboard();
	end

	if SOTA.db.realm.NeedsToExportRavenLogs then
		self.statsFrame:SetText("You need to export Raven logs!");
	else
		self.statsFrame:SetText("");
	end

	if SOTA:IsRaidLeader() then
		self.warnNotRL:Hide()
	else
		self.warnNotRL:Show()
	end

	if SOTA:IsMasterLoot() then
		self.warnNotML:Hide()
	else
		self.warnNotML:Show()
	end
end

function SOTA_OpenDashboard()
	DashboardUIFrame:Show();
end

function SOTA_CloseDashboard()
	DashboardUIFrame:Hide();
end

function SOTA_ShowDashboardToolTip(object, message)
	GameTooltip:SetOwner(object, "ANCHOR_PRESERVE");
	GameTooltip:AddLine(message, 1, 1, 1);
	GameTooltip:Show();
end

function SOTA_HideDashboardToolTip()
	GameTooltip:Hide();
end

function SOTA_OnLootClick(object)
	local itemLink = getglobal(object:GetName() .. "ItemLink"):GetText();
	if not itemLink or itemLink == "" then
		return;
	end
	module:SendMessage("SOTA_REQUEST_AUCTION", itemLink, SOTA:RealZoneToRaidName(GetRealZoneText()), module.currentLootedMobName);
end

function SOTA_OnEarnBossDkp()
	if not module.bossDkpFrame.numericDkpValue or module.bossDkpFrame.numericDkpValue == 0 then
		SOTA:Print("Error: No boss dkp value to award.")
		return
	end

	SOTA:Async_AddRaidDKP(module.bossDkpFrame.numericDkpValue, SOTA.LOGTYPE.BOSS, module.bossDkpFrame.name:GetText());
	module.bossDkpFrame:Hide()
	module.cancelBossDkpButton:Hide()
	PlaySound("igBackPackCoinSelect")
end

function SOTA_OnCancelBossDkp()
	module.bossDkpFrame:Hide()
	module.cancelBossDkpButton:Hide()
	module.bossDkpFrame.numericDkpValue = 0
end


function SOTA_ExportRavenLogsButton_OnClick()
	module:SendMessage("SOTA_EXPORTRAVENLOGS_REQUEST")
	SOTA.db.realm.NeedsToExportRavenLogs = false
end


StaticPopupDialogs["SOTA_CONFIRM_CLEARRAVENLOGS"] = {
	text = "Do you really want to clear Raven Logs?",
	button1 = "Yes",
	button2 = "No",
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnAccept = function()
		SOTA.db.realm.RavenLogsForApp = { dkpTransactions = {}, auctions = {} }
		SOTA:Print("Raven logs cleared.")
		SOTA.db.realm.NeedsToExportRavenLogs = false
	end,
}

function SOTA_ClearRavenLogsButton_OnClick()
	StaticPopup_Show("SOTA_CONFIRM_CLEARRAVENLOGS")
end

-------------------------------
--- Report Raid DKP to Officer Chat

function module:GetSessionRaidDkp()
	local transactions = SOTA.db.realm.RavenLogsForApp.dkpTransactions
	local totalDkp = 0
	for n = 1, table.getn(transactions), 1 do
		local tr = transactions[n]
		if tr.type == SOTA.LOGTYPE.BOSS or tr.type == SOTA.LOGTYPE.RAID then
			if table.getn(tr.dkpChanges) > 0 then
				totalDkp = totalDkp + tr.dkpChanges[1].change
			end
		end
	end
	return totalDkp
end

StaticPopupDialogs["SOTA_CONFIRM_BROADCAST_RAID_DKP"] = {
	text = "Broadcast raid DKP report to officer chat?",
	button1 = "Yes",
	button2 = "No",
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnAccept = function()
		module:BroadcastRaidDkpReport()
	end,
}

function SOTA_ReportRaidDkpButton_OnClick()
	StaticPopup_Show("SOTA_CONFIRM_BROADCAST_RAID_DKP")
end

function module:BroadcastRaidDkpReport()
	local totalDkp = self:GetSessionRaidDkp()
	local playerCount = GetNumRaidMembers()

	SOTA:Broadcast(SOTA.CHANNEL.OFFICER, string.format("DKP earned this session: %d per member.", totalDkp))

	if playerCount and playerCount > 0 then
		local notInGuildNames = {}
		local notInConfigNames = {}
		for n = 1, playerCount, 1 do
			local playerName, _, _, _, class = GetRaidRosterInfo(n)
			if playerName and playerName ~= "" then
				local guildInfo = SOTA:GetGuildPlayerInfo(playerName)
				if not guildInfo then
					table.insert(notInGuildNames, playerName)
				else
					local found = SOTA:GetPlayerGuildRosterRole(playerName)
					if not found then
						table.insert(notInConfigNames, playerName)
					end
				end
			end
		end

		if table.getn(notInGuildNames) > 0 then
			SOTA:Broadcast(SOTA.CHANNEL.OFFICER, "Not in guild: " .. table.concat(notInGuildNames, ", ") .. ".")
		end

		if table.getn(notInConfigNames) > 0 then
			SOTA:Broadcast(SOTA.CHANNEL.OFFICER, "Not in config: " .. table.concat(notInConfigNames, ", ") .. ".")
		end
	end
end

-------------------------------
--- Guild Roster Roles Validation

function module:OnRaidRosterUpdate()
	self:CheckRaidAgainstConfig()
end

function module:CheckRaidAgainstConfig()
	local config = SOTA.db.realm.GuildRosterRoles
	if table.getn(config) == 0 then
		return
	end

	local playerCount = GetNumRaidMembers()
	if not playerCount or playerCount == 0 then
		return
	end

	for n = 1, playerCount, 1 do
		local playerName, _, _, _, class = GetRaidRosterInfo(n)
		if playerName and playerName ~= "" and not self.warnedPlayers[playerName] then
			local found = SOTA:GetPlayerGuildRosterRole(playerName)
			if not found then
				SOTA:Print("Warning: " .. playerName .. " is not in the guild roster roles.")
				self.warnedPlayers[playerName] = true
			end
		end
	end
end

-------------------------------
--- Dashboard Tooltip (Guild Roster Roles Status)

function SOTA_OnDashboardEnter(frame)
	local config = SOTA.db.realm.GuildRosterRoles
	GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
	GameTooltip:AddLine("Raid Session Status", 1, 0.82, 0)

	local totalDkp = module:GetSessionRaidDkp()
	GameTooltip:AddLine(string.format("DKP earned this session: %d per member", totalDkp), 1, 1, 1)
	GameTooltip:AddLine(" ", 1, 1, 1)

	if table.getn(config) == 0 then
		GameTooltip:AddLine("No guild roster roles imported", 0.7, 0.7, 0.7)
		GameTooltip:Show()
		return
	end

	local playerCount = GetNumRaidMembers()
	if not playerCount or playerCount == 0 then
		GameTooltip:AddLine("Not in a raid", 0.7, 0.7, 0.7)
		GameTooltip:Show()
		return
	end

	local notInGuild = {}
	local notInConfig = {}
	for n = 1, playerCount, 1 do
		local playerName, _, _, _, class = GetRaidRosterInfo(n)
		if playerName and playerName ~= "" then
			local guildInfo = SOTA:GetGuildPlayerInfo(playerName)
			if not guildInfo then
				notInGuild[table.getn(notInGuild) + 1] = { name = playerName, class = class }
			else
				local found = SOTA:GetPlayerGuildRosterRole(playerName)
				if not found then
					notInConfig[table.getn(notInConfig) + 1] = { name = playerName, class = class }
				end
			end
		end
	end

	if table.getn(notInGuild) == 0 and table.getn(notInConfig) == 0 then
		GameTooltip:AddLine("All raid members are in config", 0.5, 1, 0.5)
	end

	if table.getn(notInGuild) > 0 then
		GameTooltip:AddLine("Not in guild:", 1, 0.3, 0.3)
		for n = 1, table.getn(notInGuild), 1 do
			local color = SOTA:GetClassColorCodes(notInGuild[n].class)
			GameTooltip:AddLine("  " .. notInGuild[n].name, color[1] / 255, color[2] / 255, color[3] / 255)
		end
	end

	if table.getn(notInConfig) > 0 then
		GameTooltip:AddLine("Not in config:", 1, 0.5, 0.2)
		for n = 1, table.getn(notInConfig), 1 do
			local color = SOTA:GetClassColorCodes(notInConfig[n].class)
			GameTooltip:AddLine("  " .. notInConfig[n].name, color[1] / 255, color[2] / 255, color[3] / 255)
		end
	end

	GameTooltip:Show()
end

function SOTA_OnDashboardLeave()
	GameTooltip:Hide()
end
