local SOTA = SOTAG

local module = SOTA:NewModule("Dashboard", "AceEvent-2.0")

function module:OnEnable()
	self.lootsFrames = {}
	self.statsFrame = getglobal("SOTA_Dash_Stats")

	self:RegisterEvent("SOTA_ITEMPRIOS_UPDATED", "RefreshStats")
	self:RegisterEvent("LOOT_OPENED", "RefreshLootsList")
	self:RegisterEvent("LOOT_SLOT_CLEARED", "RefreshLootsList")
	self:RegisterEvent("LOOT_CLOSED", "RefreshLootsList")
	self:ScheduleRepeatingEvent("SOTA_OnSecondTimer", self.OnSecondTimer, 1, self)

	self:RefreshStats()
	self:OnSecondTimer()

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
			self.lootsFrames[lootSlot].itemSoftLink = getglobal(self.lootsFrames[lootSlot]:GetName() .. "ItemSoftLink");
			self.lootsFrames[lootSlot].itemPrio = getglobal(self.lootsFrames[lootSlot]:GetName() .. "ItemPrio");
			self.lootsFrames[lootSlot].itemNotes = getglobal(self.lootsFrames[lootSlot]:GetName() .. "ItemNotes");
		end

		self.lootsFrames[lootSlot]:Show()
		self.lootsFrames[lootSlot].itemName:SetText(itemName)
		self.lootsFrames[lootSlot].itemName:SetTextColor((itemColor[1] / 255), (itemColor[2] / 255), (itemColor[3] / 255),
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
end

function module:RefreshStats()
	self.statsFrame:SetText("Loot prios counter: " .. table.getn(SOTA.db.realm.ItemPriorities))
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
	module:TriggerEvent("SOTA_REQUEST_AUCTION", itemLink)
end
