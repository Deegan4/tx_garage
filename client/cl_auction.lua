-- tx_garage — Auction UI

function OpenAuctionUI()
    local auctions = lib.callback.await('tx_garage:listAuctions', false) or {}
    SendNUIMessage({
        action = 'openAuction',
        auctions = auctions,
        config = GetClientConfig().Auction,
    })
    SetNuiFocus(true, true)
end

RegisterNUICallback('auction/bid', function(data, cb)
    TriggerServerEvent('tx_garage:placeBid', data.auctionId, data.amount)
    cb({ ok = true })
end)

RegisterNUICallback('auction/watch', function(data, cb)
    TriggerServerEvent('tx_garage:watchAuction', data.auctionId, data.watching)
    cb({ ok = true })
end)

RegisterNetEvent('tx_garage:auctionUpdate', function(auctionId, newBid)
    SendNUIMessage({
        action = 'auctionUpdate',
        auctionId = auctionId,
        newBid = newBid,
    })
end)
