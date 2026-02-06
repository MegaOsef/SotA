local SOTA = SOTAG

local module = SOTA:NewModule("Dashboard", "AceEvent-2.0")

function module:OnEnable()
	self.lootsFrames = {}
	self.statsFrame = getglobal("SOTA_Dash_Stats")
	self.warnNotRL = getglobal("SOTA_DashWarn_NotRL")
	self.warnNotML = getglobal("SOTA_DashWarn_NotML")
	self.currentLootedMobName = nil

	self:RegisterEvent("SOTA_RAVENLOGS_UPDATED")
	self:RegisterEvent("SOTA_BOSS_KILLED")
	self:RegisterEvent("LOOT_OPENED")
	self:RegisterEvent("LOOT_SLOT_CLEARED", "RefreshLootsList")
	self:RegisterEvent("LOOT_CLOSED")
	self:ScheduleRepeatingEvent("SOTA_OnSecondTimer", self.OnSecondTimer, 1, self)

	self:OnSecondTimer()

	self:RefreshLootsList()

	self.bossDkpFrame = getglobal("DashboardUIFrameItemShareBossDkp")
	self.bossDkpFrame.texture = getglobal(self.bossDkpFrame:GetName() .. "IconTexture")
	self.bossDkpFrame.name = getglobal(self.bossDkpFrame:GetName() .. "BossName")
	self.bossDkpFrame.dkpValue = getglobal(self.bossDkpFrame:GetName() .. "DkpValue")

	self.bossDkpFrame.texture:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
	self.bossDkpFrame:Hide()
end

function module:SOTA_RAVENLOGS_UPDATED()
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
	-- Hide all existing lootsFrames
	for i = 1, table.getn(self.lootsFrames), 1 do
		local frame = self.lootsFrames[i]
		if frame then
			frame:Hide()
		end
	end

	for lootSlot = 1, GetNumLootItems(), 1 do
		local itemLink = GetLootSlotLink(lootSlot)
		SOTA:Debug("Loot #"..lootSlot.." link: "..tostring(itemLink))
		if itemLink then
			local itemId = SOTA:GetItemIDFromLink(itemLink)
			if not itemId then
				SOTA:Print("Could not extract itemId from link: " .. tostring(itemLink))
				break
			end
			local itemName, itemSoftLink, itemRarity, _, _, _, _, _, itemTexture = GetItemInfo(itemId)
			local itemColor = SOTA:GetQualityColor(itemRarity)

			-- Do we need to create a new loot frame?
			if table.getn(self.lootsFrames) < lootSlot then
				local entry = CreateFrame("Button", "$parentEntry" .. lootSlot, DashboardUIFrameLootsList,
					"SOTA_LootTemplate");
				if lootSlot == 1 then
					entry:SetPoint("TOPLEFT", 0, 0);
				else
					entry:SetPoint("TOP", "$parentEntry" .. (lootSlot - 1), "BOTTOM");
				end
				self.lootsFrames[lootSlot] = entry
				self.lootsFrames[lootSlot].itemName = getglobal(self.lootsFrames[lootSlot]:GetName() .. "ItemName");
				self.lootsFrames[lootSlot].itemTexture = getglobal(self.lootsFrames[lootSlot]:GetName() .. "ItemTexture");
				self.lootsFrames[lootSlot].itemLink = getglobal(self.lootsFrames[lootSlot]:GetName() .. "ItemLink");
				self.lootsFrames[lootSlot].itemSoftLink = getglobal(self.lootsFrames[lootSlot]:GetName() ..
				"ItemSoftLink");
				self.lootsFrames[lootSlot].itemPrio = getglobal(self.lootsFrames[lootSlot]:GetName() .. "ItemPrio");
				self.lootsFrames[lootSlot].itemNotes = getglobal(self.lootsFrames[lootSlot]:GetName() .. "ItemNotes");
			end

			self.lootsFrames[lootSlot]:Show()
			self.lootsFrames[lootSlot].itemName:SetText(itemName)
			self.lootsFrames[lootSlot].itemName:SetTextColor((itemColor[1] / 255), (itemColor[2] / 255),
				(itemColor[3] / 255),
				255);
			self.lootsFrames[lootSlot].itemTexture:SetTexture(itemTexture)
			self.lootsFrames[lootSlot].itemLink:SetText(itemLink)
			self.lootsFrames[lootSlot].itemSoftLink:SetText(itemSoftLink)


			self.lootsFrames[lootSlot].itemPrio:SetText("")
			self.lootsFrames[lootSlot].itemNotes:SetText("")
			local prioFound = SOTA:FindItemPriority(itemId)
			if prioFound then
				if prioFound.priority then
					self.lootsFrames[lootSlot].itemPrio:SetText(string.format("Priority: %s", prioFound.priority))
				end
				if prioFound.notes then
					self.lootsFrames[lootSlot].itemNotes:SetText(string.format("Notes: %s", prioFound.notes))
				end
			end
		end
	end
end

function module:SOTA_BOSS_KILLED(bossName, dkpValue)
	self.bossDkpFrame.name:SetText(bossName)
	self.bossDkpFrame.dkpValue:SetText("Dkp Value: " .. tostring(dkpValue))
	self.bossDkpFrame.numericDkpValue = dkpValue
	self.bossDkpFrame:Show()
	PlaySound("AuctionWindowClose")
end

function module:OnSecondTimer()
	if SOTA:IsInRaid(true) then
		if SOTA.db.realm.DisableDashboard == 0 then
			SOTA_OpenDashboard();
		end
	else
		if SOTA.db.realm.DisableDashboard == 0 then
			SOTA_CloseDashboard();
		end
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
	module:TriggerEvent("SOTA_REQUEST_AUCTION", itemLink, SOTA:RealZoneToRaidName(GetRealZoneText()), module.currentLootedMobName);
end

function SOTA_OnEarnBossDkp()
	if not module.bossDkpFrame.numericDkpValue or module.bossDkpFrame.numericDkpValue == 0 then
		SOTA:Print("Error: No boss dkp value to award.")
		return
	end

	SOTA:Async_AddRaidDKP(module.bossDkpFrame.numericDkpValue, SOTA.LOGTYPE.BOSS, module.bossDkpFrame.name:GetText());
	module.bossDkpFrame:Hide()
	PlaySound("igBackPackCoinSelect")
end


function SOTA_ExportRavenLogsButton_OnClick()
	module:TriggerEvent("SOTA_EXPORTRAVENLOGS_REQUEST")
	SOTA.db.realm.NeedsToExportRavenLogs = false
end

function SOTA_ClearRavenLogsButton_OnClick()
	SOTA.db.realm.RavenLogsForApp = { dkpTransactions = {}, auctions = {} }
	SOTA:Print("Raven logs cleared.")
	SOTA.db.realm.NeedsToExportRavenLogs = false
end
