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
    local exportString = SOTA.json.encode(SOTA.db.realm.RavenLogsForApp)
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

function module:LogTransaction(transactionType, playerName, dkpChange, auctionId, bossName)
    -- Not implemented yet in the WebApp.
    --[[
    local uniqueAuctionId = self:getUniqueId()
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

    self:TriggerEvent("SOTA_RAVENLOGS_UPDATED")

    return uniqueAuctionId
    ]]
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
    })

    self:TriggerEvent("SOTA_RAVENLOGS_UPDATED")

    return uniqueAuctionId
end

function SOTA_ExportRavenLogs_close()
    module.exportModal:Hide()
end