-- tx_garage — Impound auction server logic
-- Differentiator #2: no competing FiveM garage script ships impound auctions as of May 2026.

local AUCTION_TICK_SECONDS = 60

---Look up a vehicle's value (used to compute starting bid).
local function getVehicleValue(plate, model)
    local ok, result = pcall(function()
        return MySQL.scalar.await('SELECT depvalue FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
    end)
    if ok and result and tonumber(result) then return tonumber(result) end
    return Config.Auction.fallbackValue
end

---Promote vehicles overdue in impound to auction.
local function promoteOverdueImpounds()
    if not Config.Auction.enabled then return end

    local overdue = MySQL.query.await([[
        SELECT plate, vehicle
        FROM player_vehicles
        WHERE tx_garage_state = 'impound'
          AND tx_garage_impounded_at IS NOT NULL
          AND TIMESTAMPDIFF(DAY, tx_garage_impounded_at, NOW()) >= ?
    ]], { Config.Auction.impoundDays })

    for _, v in ipairs(overdue or {}) do
        -- Skip if already in auctions table
        local existing = MySQL.scalar.await('SELECT id FROM tx_garage_auctions WHERE plate = ? LIMIT 1', { v.plate })
        if not existing then
            local value = getVehicleValue(v.plate, v.vehicle)
            local startingBid = math.floor(value * Config.Auction.startingBidPercent)
            local endsAt = os.date('%Y-%m-%d %H:%M:%S', os.time() + Config.Auction.auctionLength)

            MySQL.insert.await([[
                INSERT INTO tx_garage_auctions (plate, vehicle_model, starting_bid, current_bid, ends_at)
                VALUES (?, ?, ?, ?, ?)
            ]], { v.plate, v.vehicle, startingBid, startingBid, endsAt })

            MySQL.update.await(
                "UPDATE player_vehicles SET tx_garage_state = 'auction' WHERE plate = ?",
                { v.plate }
            )
            Utils.dbg('Promoted plate to auction:', v.plate)
        end
    end
end

---Close auctions whose end time has passed; transfer or forfeit.
local function closeExpiredAuctions()
    local expired = MySQL.query.await([[
        SELECT id, plate, vehicle_model, current_bid, leading_bidder
        FROM tx_garage_auctions
        WHERE status = 'open' AND ends_at <= NOW()
    ]])

    for _, a in ipairs(expired or {}) do
        if a.leading_bidder then
            -- Charge bidder (offline-safe)
            local houseCut = math.floor(a.current_bid * Config.Auction.houseCutPercent)
            local netToCity = a.current_bid - houseCut

            local paid = Bridge.RemoveMoneyOffline(a.leading_bidder, 'bank', a.current_bid)
            if paid then
                -- Transfer ownership
                local transferSql = (Config.Framework == 'esx')
                    and "UPDATE player_vehicles SET owner=?, tx_garage_state='impound', tx_garage_impounded_at=NOW() WHERE plate=?"
                    or  "UPDATE player_vehicles SET citizenid=?, tx_garage_state='impound', tx_garage_impounded_at=NOW() WHERE plate=?"
                MySQL.update.await(transferSql, { a.leading_bidder, a.plate })
                MySQL.update.await(
                    "UPDATE tx_garage_auctions SET status = 'closed' WHERE id = ?",
                    { a.id }
                )
                Utils.dbg('Auction closed:', a.plate, '→', a.leading_bidder, 'for', a.current_bid)
            else
                -- Bidder couldn't pay — forfeit and re-list
                MySQL.update.await(
                    "UPDATE tx_garage_auctions SET status = 'forfeited' WHERE id = ?",
                    { a.id }
                )
                MySQL.update.await(
                    "UPDATE player_vehicles SET tx_garage_state = 'impound' WHERE plate = ?",
                    { a.plate }
                )
                Utils.dbg('Auction forfeited (bidder broke):', a.plate)
            end
        else
            -- No bids — return to impound, will re-promote later
            MySQL.update.await("UPDATE tx_garage_auctions SET status = 'closed' WHERE id = ?", { a.id })
            MySQL.update.await("UPDATE player_vehicles SET tx_garage_state = 'impound' WHERE plate = ?", { a.plate })
        end
    end
end

CreateThread(function()
    while true do
        promoteOverdueImpounds()
        closeExpiredAuctions()
        Wait(AUCTION_TICK_SECONDS * 1000)
    end
end)

lib.callback.register('tx_garage:listAuctions', function(src)
    return MySQL.query.await([[
        SELECT id, plate, vehicle_model, starting_bid, current_bid, leading_bidder, ends_at
        FROM tx_garage_auctions
        WHERE status = 'open'
        ORDER BY ends_at ASC
    ]])
end)

RegisterNetEvent('tx_garage:placeBid', function(auctionId, amount)
    local src = source
    if isOnCooldown(src, 'bid', 2) then return end

    local p = Bridge.GetPlayer(src)
    if not p then return end

    amount = tonumber(amount)
    if not amount or amount <= 0 then return end

    local row = MySQL.query.await([[
        SELECT current_bid, leading_bidder, status, ends_at FROM tx_garage_auctions WHERE id = ? LIMIT 1
    ]], { auctionId })
    if not row or not row[1] or row[1].status ~= 'open' then return end

    local minNext = row[1].current_bid + Config.Auction.minBidIncrement
    if amount < minNext then
        Bridge.Notify(src, Locale('auction.bid_too_low', Utils.formatMoney(minNext)), 'error')
        return
    end

    -- Verify funds (live check, but we DO NOT debit yet — only on auction close)
    local money = (Config.Framework == 'esx')
        and p.getAccount('bank').money
        or p.PlayerData.money.bank
    if money < amount then
        Bridge.Notify(src, Locale('auction.no_money'), 'error')
        return
    end

    local id = Bridge.GetIdentifier(p)
    local previousBidder = row[1].leading_bidder

    MySQL.update.await([[
        UPDATE tx_garage_auctions SET current_bid = ?, leading_bidder = ? WHERE id = ?
    ]], { amount, id, auctionId })

    MySQL.insert('INSERT INTO tx_garage_auction_bids (auction_id, bidder, bid_amount) VALUES (?, ?, ?)',
        { auctionId, id, amount })

    -- Notify previously leading bidder if online
    if previousBidder and previousBidder ~= id then
        local idCol = (Config.Framework == 'esx') and 'identifier' or 'citizenid'
        for _, otherSrc in ipairs(GetPlayers()) do
            local op = Bridge.GetPlayer(tonumber(otherSrc))
            if op and Bridge.GetIdentifier(op) == previousBidder then
                Bridge.Notify(tonumber(otherSrc),
                    Locale('auction.outbid', '#' .. auctionId, Utils.formatMoney(amount)),
                    'error')
                break
            end
        end
    end

    Bridge.Notify(src, Locale('success.payment', Utils.formatMoney(amount)), 'success')
    -- Broadcast only bid amount — never expose the bidder's identifier to all clients
    TriggerClientEvent('tx_garage:auctionUpdate', -1, auctionId, amount)
end)
