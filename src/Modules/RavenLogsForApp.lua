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

function module:LogTransaction(transactionType, playerName, dkpChange, auctionId, bossName)
    local uniqueAuctionId = self:getUniqueId()
    SOTA:Print("Logging transaction with id:", uniqueAuctionId, transactionType, playerName, dkpChange, tostring(auctionId))

    local finalAuctionId = nil
    if auctionId then
        finalAuctionId = auctionId
    end

    table.insert(SOTA.db.realm.RavenLogsForApp.dkpMoves, {
        id = uniqueAuctionId,
        type = transactionType,
        name = playerName,
        change = dkpChange,
        auctionId = finalAuctionId,
        officer = UnitName("player"),
        bossName = bossName,
    })

    return uniqueAuctionId
end

function module:LogAuction(itemId, bossName, winner, finalBid)
    local uniqueAuctionId = self:getUniqueId()
    SOTA:Print("Logging auction with id:", uniqueAuctionId)

    table.insert(SOTA.db.realm.RavenLogsForApp.auctions, {
        id = uniqueAuctionId,
        itemId = itemId,
        bossName = bossName,
        winner = winner,
        finalBid = finalBid,
        officer = UnitName("player"),
    })

    return uniqueAuctionId
end