local SOTA = SOTAG

local RAIDS_INFO = SOTA.RAIDS_INFO

local module = SOTA:NewModule("PreviousAuctions", "AceEvent-3.0")

local MAX_AUCTIONS = 24

function module:OnEnable()
    self.window = SOTA_PreviousAuctionsUI
    self.listFrame = getglobal(self.window:GetName() .. "AuctionsList")
    self.listFrame:Show()
    self.rows = {}
    self.currentPage = 1

    for n = 0, MAX_AUCTIONS, 1 do
        local entry = CreateFrame("Frame", "$parentEntry" .. n, self.listFrame, "SOTA_PreviousAuction_Template");
        entry:SetID(n)
        if n == 0 then
            entry:SetPoint("TOPLEFT", 4, -4);
        else
            entry:SetPoint("TOP", "$parentEntry" .. (n - 1), "BOTTOM");
        end

        self.rows[n] = entry
        self.rows[n].id = getglobal(entry:GetName() .. "Id")
        self.rows[n].item = getglobal(entry:GetName() .. "Item")
        self.rows[n].bossName = getglobal(entry:GetName() .. "BossName")
        self.rows[n].winner = getglobal(entry:GetName() .. "Winner")
        self.rows[n].finalBid = getglobal(entry:GetName() .. "FinalBid")
        self.rows[n].bidType = getglobal(entry:GetName() .. "BidType")
        self.rows[n].officer = getglobal(entry:GetName() .. "Officer")
        self.rows[n].rollbackBtn = getglobal(entry:GetName() .. "RollbackBtn")
        self.rows[n].rollbackBtn:SetID(n)
        self.rows[n].editBtn = getglobal(entry:GetName() .. "EditBtn")
        self.rows[n].editBtn:SetID(n)

        self.rows[n]:Hide()
    end

    self.btnPrev = getglobal(self.window:GetName() .. "BtnPrevPage")
    self.btnNext = getglobal(self.window:GetName() .. "BtnNextPage")
    self.pageIndicator = getglobal(self.window:GetName() .. "PageIndicator")

    self.window:Hide()

    self:RegisterMessage("SOTA_RAVENLOGS_UPDATED", "RefreshAuctionsList")
end

local function sortAuctionsDescending(sourcetable, index)
    local doSort = true
    while doSort do
        doSort = false
        for n = 1, table.getn(sourcetable) - 1, 1 do
            local a = sourcetable[n]
            local b = sourcetable[n + 1]
            if (tonumber(a.id)) < (tonumber(b.id)) then
                sourcetable[n] = b
                sourcetable[n + 1] = a
                doSort = true
            end
        end
    end
    return sourcetable;
end

function module:RefreshAuctionsList()
    self.sortedAuctions = SOTA:CloneTable(SOTA.db.realm.RavenLogsForApp.auctions)
    sortAuctionsDescending(self.sortedAuctions)

    self:RenderPage()
end

function module:RenderPage()
    local auctions = self.sortedAuctions or {}
    local totalAuctions = table.getn(auctions)
    local numPages = ceil(totalAuctions / MAX_AUCTIONS)
    if numPages < 1 then numPages = 1 end
    if self.currentPage > numPages then self.currentPage = numPages end

    self:UpdatePageControls(numPages)

    local canEdit = SOTA:CanWriteNotes()
    local id, item, bossName, winner, finalBid, bidType, officer
    for n = 0, MAX_AUCTIONS, 1 do
        self.rows[n].rollbackBtn:Hide()
        self.rows[n].editBtn:Hide()
        self.rows[n].itemLink = nil
        self.rows[n].itemSoftLink = nil
        if n == 0 then
            id = "ID"
            item = "Item"
            bossName = "Boss Name"
            winner = "Winner"
            finalBid = "Final Bid"
            bidType = "Bid Type"
            officer = "Officer"
            getglobal(self.rows[n].item:GetName() .. "Text"):SetTextColor(1, 0.82, 0)
        else
            local index = n + ((self.currentPage - 1) * MAX_AUCTIONS)

            id = ""
            item = ""
            bossName = ""
            winner = ""
            finalBid = ""
            bidType = ""
            officer = ""

            if totalAuctions >= index then
                local auc = auctions[index]

                id = auc.id
                local itemName, itemSoftLink, itemRarity = GetItemInfo(auc.itemId)
                item = itemName
                if itemSoftLink and itemName then
                    self.rows[n].itemSoftLink = itemSoftLink
                    local c = itemRarity and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[itemRarity]
                    local colorHex = c and string.format("%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255) or "ffffff"
                    self.rows[n].itemLink = "|cff" .. colorHex .. "|H" .. itemSoftLink .. "|h[" .. itemName .. "]|h|r"
                end
                if itemRarity and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[itemRarity] then
                    local c = ITEM_QUALITY_COLORS[itemRarity]
                    getglobal(self.rows[n].item:GetName() .. "Text"):SetTextColor(c.r, c.g, c.b)
                else
                    getglobal(self.rows[n].item:GetName() .. "Text"):SetTextColor(1, 1, 1)
                end
                bossName = auc.bossName
                if auc.winner then
                    winner = auc.winner
                else
                    winner = "-"
                end
                if auc.finalBid then
                    finalBid = auc.finalBid
                else
                    finalBid = "-"
                end
                if auc.bidType then
                    bidType = auc.bidType
                else
                    bidType = "-"
                end
                officer = auc.officer

                self.rows[n].rollbackBtn:Show()
                if canEdit then
                    self.rows[n].editBtn:Show()
                end
                if auc.valid then
                    self.rows[n].rollbackBtn:Enable()
                    self.rows[n].editBtn:Enable()
                else
                    self.rows[n].rollbackBtn:Disable()
                    self.rows[n].editBtn:Disable()
                end
            else
                getglobal(self.rows[n].item:GetName() .. "Text"):SetTextColor(1, 0.82, 0)
            end
        end

        local row = self.rows[n]
        row.id:SetText(id)
        row.item:SetText(item)
        row.bossName:SetText(bossName)
        row.winner:SetText(winner)
        row.finalBid:SetText(finalBid)
        row.bidType:SetText(bidType)
        row.officer:SetText(officer)

        row:Show()
    end
end

function module:UpdatePageControls(numPages)
    self.btnPrev:Show()
    self.btnNext:Show()
    self.pageIndicator:SetText("Page " .. self.currentPage .. " / " .. numPages)
    if self.currentPage > 1 then
        self.btnPrev:Enable()
    else
        self.btnPrev:Disable()
    end
    if self.currentPage < numPages then
        self.btnNext:Enable()
    else
        self.btnNext:Disable()
    end
end

function module:PreviousPage()
    if self.currentPage > 1 then
        self.currentPage = self.currentPage - 1
        self:RenderPage()
    end
end

function module:NextPage()
    self.currentPage = self.currentPage + 1
    self:RenderPage()
end

function module:RollbackPreviousAuction(index)
    -- invalidate the auction in logs
    local ravenLogs = SOTA:GetModule("RavenLogsForApp", true)
    if not ravenLogs then
        SOTA:Print("Critical: can't find RavenLog module.")
        return
    end
    local auctionId = self.rows[index].id:GetText()
    local auction = ravenLogs:FindAuctionFromId(auctionId)
    if not auction then
        SOTA:Print("Critical: can't find the auction in logs.")
        return
    end

    auction.valid = false

    -- Broadcast the rollback
    local itemName = GetItemInfo(auction.itemId)
    if auction.winner then
        SOTA:Broadcast(SOTA.CHANNEL.RAID,
            string.format("Auction for %s has been rollbacked. Buyer was %s for %i DKP (%s).",
                itemName,
                auction.winner,
                auction.finalBid,
                auction.bidType
            ))
    else
        SOTA:Broadcast(SOTA.CHANNEL.RAID,
            string.format("Auction for %s has be rollbacked.",
                itemName
            ))
    end

    -- Refund the player
    if auction.winner then
        SOTA:AddPlayerDKP(auction.winner, auction.finalBid, "refund")
    end

    self:RefreshAuctionsList()
end

function SOTA_OpenPreviousAuctionsUI()
    module.currentPage = 1
    module:RefreshAuctionsList()
    module.window:Show()
end

function SOTA_ClosePreviousAuctionsUI()
    module.window:Hide()
end

StaticPopupDialogs["SOTA_CONFIRM_AUCTIONROLLBACK"] = {
    text = "Do you really want to rollback this auction?",
    button1 = "Yes",
    button2 = "No",
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    OnAccept = function()
        module:RollbackPreviousAuction(module.rollbackAuctionInValidation)
    end,
}

function SOTA_PreviousAuction_ItemOnEnter(button)
    local row = button:GetParent()
    local itemSoftLink = row.itemSoftLink
    if itemSoftLink then
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(itemSoftLink)
        GameTooltip:Show()
    end
end

function SOTA_PreviousAuction_ItemOnClick(button, mouseButton)
    local row = button:GetParent()
    local itemLink = row.itemLink
    if not itemLink then
        return
    end
    if IsShiftKeyDown() and ChatFrameEditBox:IsVisible() then
        ChatFrameEditBox:Insert(itemLink)
    end
end

function SOTA_Rollback_PreviousAuction(object)
    module.rollbackAuctionInValidation = object:GetID()

    StaticPopup_Show("SOTA_CONFIRM_AUCTIONROLLBACK")
end

function SOTA_EditPreviousAuction(button)
    local rowId = button:GetID()
    module:OpenEditModal(rowId)
end

function SOTA_SaveEditedAuction()
    module:SaveEditedAuction()
end

function module:OpenEditModal(rowId)
    self.editingRowId = rowId
    local auctionId = self.rows[rowId].id:GetText()

    local ravenLogs = SOTA:GetModule("RavenLogsForApp", true)
    local auction = ravenLogs:FindAuctionFromId(auctionId)
    if not auction then
        SOTA:Print("Error: auction not found.")
        return
    end
    self.editingAuctionId = auctionId

    local modal = SOTA_EditAuctionModal

    if not self.editRaidDropdown then
        self:CreateEditDropdowns(modal)
    end

    local raidOptions = {}
    for n = 1, table.getn(RAIDS_INFO), 1 do
        raidOptions[n] = { text = RAIDS_INFO[n].name, value = n }
    end
    self.editRaidDropdown:SetOptions(raidOptions)

    self:PreselectRaidBoss(auction.raidName, auction.bossName)

    modal:Show()
end

function module:CreateEditDropdowns(modal)
    self.editRaidDropdown = SOTA:CreateDropdown(
        "SOTAEditAuctionRaidDropdown", modal, 250, "Select Raid")
    self.editRaidDropdown:GetFrame():SetPoint("TOPLEFT", modal, "TOPLEFT", 20, -50)

    self.editBossDropdown = SOTA:CreateDropdown(
        "SOTAEditAuctionBossDropdown", modal, 250, "Select Boss")
    self.editBossDropdown:GetFrame():SetPoint("TOPLEFT", self.editRaidDropdown:GetFrame(), "BOTTOMLEFT", 0, -10)
    self.editBossDropdown:SetEnabled(false)

    self.editRaidDropdown:SetOnChange(function(value, text)
        module:OnEditRaidChanged(value)
    end)
end

function module:OnEditRaidChanged(raidId)
    self.editBossDropdown:SetSelectedValue(0)
    if raidId >= 1 and raidId <= table.getn(RAIDS_INFO) then
        local bosses = RAIDS_INFO[raidId].bosses
        local bossOptions = {}
        for n = 1, table.getn(bosses), 1 do
            bossOptions[n] = { text = bosses[n], value = n }
        end
        self.editBossDropdown:SetOptions(bossOptions)
        self.editBossDropdown:SetEnabled(true)
    else
        self.editBossDropdown:SetOptions({})
        self.editBossDropdown:SetEnabled(false)
    end
end

function module:PreselectRaidBoss(raidName, bossName)
    local foundRaid = false
    for r = 1, table.getn(RAIDS_INFO), 1 do
        if RAIDS_INFO[r].name == raidName then
            self.editRaidDropdown:SetSelectedValue(r)
            self:OnEditRaidChanged(r)
            for b = 1, table.getn(RAIDS_INFO[r].bosses), 1 do
                if RAIDS_INFO[r].bosses[b] == bossName then
                    self.editBossDropdown:SetSelectedValue(b)
                    break
                end
            end
            foundRaid = true
            break
        end
    end
    if not foundRaid then
        self.editRaidDropdown:SetSelectedValue(0)
        self.editBossDropdown:SetOptions({})
        self.editBossDropdown:SetEnabled(false)
    end
end

function module:SaveEditedAuction()
    local raidVal = self.editRaidDropdown:GetSelectedValue()
    local bossVal = self.editBossDropdown:GetSelectedValue()

    if not raidVal or raidVal == 0 or not bossVal or bossVal == 0 then
        SOTA:Print("Please select both a raid and a boss.")
        return
    end

    local ravenLogs = SOTA:GetModule("RavenLogsForApp", true)
    local auction = ravenLogs:FindAuctionFromId(self.editingAuctionId)
    if not auction then
        SOTA:Print("Error: auction not found.")
        return
    end

    auction.raidName = RAIDS_INFO[raidVal].name
    auction.bossName = RAIDS_INFO[raidVal].bosses[bossVal]

    SOTA_EditAuctionModal:Hide()
    self:RefreshAuctionsList()
end

function SOTA_PreviousAuctions_PrevPage()
    module:PreviousPage()
end

function SOTA_PreviousAuctions_NextPage()
    module:NextPage()
end
