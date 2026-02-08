local SOTA = SOTAG

local module = SOTA:NewModule("PreviousAuctions", "AceEvent-2.0")

local MAX_AUCTIONS = 24

function module:OnEnable()
    self.window = SOTA_PreviousAuctionsUI
    self.listFrame = getglobal(self.window:GetName() .. "AuctionsList")
    self.listFrame:Show()
    self.rows = {}

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

        self.rows[n]:Hide()
    end

    self.window:Hide()

    self:RegisterEvent("SOTA_RAVENLOGS_UPDATED", "RefreshAuctionsList")
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
    local auctions = SOTA:CloneTable(SOTA.db.realm.RavenLogsForApp.auctions)
    sortAuctionsDescending(auctions)

    local id, item, bossName, winner, finalBid, bidType, officer
    for n = 0, MAX_AUCTIONS, 1 do
        self.rows[n].rollbackBtn:Hide()
        if n == 0 then
            id = "ID"
            item = "Item"
            bossName = "Boss Name"
            winner = "Winner"
            finalBid = "Final Bid"
            bidType = "Bid Type"
            officer = "Officer"
        else
            local index = n

            id = ""
            item = ""
            bossName = ""
            winner = ""
            finalBid = ""
            bidType = ""
            officer = ""

            if table.getn(auctions) >= index then
                local auc = auctions[index]

                id = auc.id
                item = GetItemInfo(auc.itemId)
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
                if auc.valid then
                    self.rows[n].rollbackBtn:Enable()
                else
                    self.rows[n].rollbackBtn:Disable()
                end
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

function SOTA_Rollback_PreviousAuction(object)
    module.rollbackAuctionInValidation = object:GetID()

    StaticPopup_Show("SOTA_CONFIRM_AUCTIONROLLBACK")
end
