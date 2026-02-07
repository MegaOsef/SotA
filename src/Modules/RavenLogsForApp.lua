local SOTA = SOTAG

SOTA.LOGTYPE = {
    BOSS = "boss",
    AUCTION = "auction",
    DECAY = "decay",
    MANUAL = "manual",
    RAID = "raid",
}

local module = SOTA:NewModule("RavenLogsForApp", "AceEvent-2.0")

function module:OnEnable()
    self.TsId = 0
    self.LastTs = 0

    self.exportModal = getglobal("SOTA_ExportRavenLogsModal")
    self.exportModal.editBox = getglobal("SOTA_ExportRavenLogsModalScrollFrameMessage")

    self:RegisterEvent("SOTA_EXPORTRAVENLOGS_REQUEST")
end

function module:SOTA_EXPORTRAVENLOGS_REQUEST()
    local exportObject = {
        auctions = SOTA.db.realm.RavenLogsForApp.auctions,
        -- dkpTransactions = SOTA.db.realm.RavenLogsForApp.dkpTransactions, -- For staging purposes.
    }
    local exportString = SOTA.json.encode(exportObject)
    self.exportModal.editBox:SetText(exportString)
    self.exportModal:Show()
end

function module:getUniqueId()
    local ts = SOTA:GetDateTimestampId()
    if ts ~= self.LastTs then
        self.TsId = 0
        self.LastTs = ts
    else
        self.TsId = self.TsId + 1
    end
    return tostring(ts) .. string.format("%03d", self.TsId)
end

function module:FindTransactionFromId(id)
    for _, transaction in ipairs(SOTA.db.realm.RavenLogsForApp.dkpTransactions) do
        if transaction.id == id then
            return transaction
        end
    end
    return nil
end

function module:FindAuctionFromId(id)
    for _, auction in ipairs(SOTA.db.realm.RavenLogsForApp.auctions) do
        if auction.id == id then
            return auction
        end
    end
    return nil
end

function module:LogTransaction(transactionType, auctionId, bossName)
    local uniqueAuctionId = self:getUniqueId()
    local finalAuctionId = nil
    if auctionId then
        finalAuctionId = auctionId
    end

    table.insert(SOTA.db.realm.RavenLogsForApp.dkpTransactions, {
        id = uniqueAuctionId,
        type = transactionType,
        --name = playerName,
        --change = dkpChange,
        auctionId = finalAuctionId,
        officer = UnitName("player"),
        bossName = bossName,
        dkpChanges = {},
    })

    return uniqueAuctionId
end

function module:LogDkpChange(transactionId, playerName, dkpChange)

    local tr = self:FindTransactionFromId(transactionId)
    if not tr then
        SOTA:Print(string.format("Error: could not find transaction with id %s to log DKP change for player %s", tostring(transactionId), tostring(playerName)))
        return
    end

    local dkpChangeId = self:getUniqueId()

    table.insert(tr.dkpChanges, {
        id = dkpChangeId,
        player = playerName,
        change = dkpChange,
    })

    return dkpChangeId
end

function module:LogAuction(itemId, bossName, winner, finalBid, bidType)
    local uniqueAuctionId = self:getUniqueId()

    table.insert(SOTA.db.realm.RavenLogsForApp.auctions, {
        id = uniqueAuctionId,
        itemId = itemId,
        bossName = bossName,
        winner = winner,
        finalBid = finalBid,
        bidType = bidType,
        officer = UnitName("player"),
        valid = true
    })

    self:TriggerEvent("SOTA_RAVENLOGS_UPDATED")

    return uniqueAuctionId
end

function SOTA_ExportRavenLogs_close()
    module.exportModal:Hide()
end