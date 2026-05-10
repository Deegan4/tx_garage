-- tx_garage v2.0 — Auction client
-- ────────────────────────────────────────────────────────────────────────────
-- Live ticking timers via single CreateThread → SendNUIMessage 'tick'
-- (NUI updates every visible card's countdown in pure JS — no per-card threads).

local auctionTickerActive = false

function OpenAuctionUI()
    if IsNuiOpen() then return end
    local cfg = GetClientConfig()
    if not cfg or not cfg.Auction.enabled then return end

    local auctions = lib.callback.await('tx_garage:listAuctions', false) or {}
    SendNUIMessage({
        action   = 'openAuction',
        auctions = auctions,
        config   = cfg.Auction,
        currency = cfg.Currency,
    })
    SetNuiOpen(true)

    -- Start the per-second tick if not already running
    if not auctionTickerActive then
        auctionTickerActive = true
        CreateThread(function()
            while IsNuiOpen() do
                SendNUIMessage({
                    action = 'auctionTick',
                    nowTs  = math.floor(os.time()),
                })
                Wait(1000)
            end
            auctionTickerActive = false
        end)
    end
end

RegisterNUICallback('auction/bid', function(data, cb)
    -- Server validates everything; we just forward
    TriggerServerEvent('tx_garage:placeBid', data.auctionId, data.amount)
    cb({ ok = true })
end)

RegisterNUICallback('auction/watch', function(data, cb)
    TriggerServerEvent('tx_garage:watchAuction', data.auctionId, data.watching)
    cb({ ok = true })
end)

-- Server pushes auction updates (broadcast to all). Includes new ends_at if extended.
RegisterNetEvent('tx_garage:auctionUpdate', function(auctionId, newBid, endsTs)
    SendNUIMessage({
        action    = 'auctionUpdate',
        auctionId = auctionId,
        newBid    = newBid,
        endsTs    = endsTs,
    })
end)
