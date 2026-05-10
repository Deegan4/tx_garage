-- tx_garage v2.0 — Impound auction
-- ────────────────────────────────────────────────────────────────────────────
-- C1 fix (concurrent bid race) — optimistic concurrency:
--   • UPDATE includes WHERE current_bid = expectedPreviousBid
--   • If two bidders race, only the first UPDATE matches; second gets 0 rows
--     and we refund the loser. No transactions, no row locks needed.
--
-- H3 fix (re-promote duplicate plate) — drops legacy ux_plate constraint
-- (handled in INSTALL.sql). Auctions can now have multiple historical rows
-- per plate; we read only the latest 'open' row.
--
-- H4 — payout split is configurable: original owner / society / sink.
-- Anti-snipe: bids in the final N seconds extend the auction by M seconds.

local AUCTION_MAX_TICK_SECONDS = 300   -- never sleep longer than 5 minutes
local AUCTION_MIN_TICK_SECONDS = 30
local WATCHLIST_NOTIFY_SECONDS = 300   -- notify watchers ~5 min before close

local auctionCooldowns = {}
-- watchlist[auctionId] = { [citizenid] = src }
local watchlist = {}

-- ─────────────────────────────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────────────────────────────

local function getVehicleValue(plate)
    local col = Config.Auction.valueColumn or 'depvalue'
    local sql = ('SELECT %s AS v FROM player_vehicles WHERE plate = ? LIMIT 1'):format(col)
    local ok, row = pcall(MySQL.query.await, sql, { plate })
    if ok and row and row[1] and tonumber(row[1].v) then return tonumber(row[1].v) end
    return Config.Auction.fallbackValue
end

local function distributePayout(originalOwner, amount)
    local split = Config.Auction.payoutSplit
    if not split then return end
    -- Round to integers; any rounding loss goes to the sink.
    local ownerCut   = math.floor(amount * (split.originalOwner or 0))
    local societyCut = math.floor(amount * (split.society or 0))

    if ownerCut > 0 and originalOwner then
        Garage.AddMoneyOffline(originalOwner, 'bank', ownerCut)
        Garage.LogSociety('auction', originalOwner, 'auction_payout', ownerCut, 'owner cut')
    end
    if societyCut > 0 and Config.Auction.societyAccount then
        -- Society balance is tracked via the ledger; integration with qbx_management
        -- can read tx_garage_society_log for net balance.
        Garage.LogSociety(Config.Auction.societyAccount, 'system', 'auction_cut', societyCut, 'auction')
    end
    -- Government / sink cut is whatever's left — money out of economy.
end

-- ─────────────────────────────────────────────────────────────────────
-- Promotion & closing (run by tick)
-- ─────────────────────────────────────────────────────────────────────

local function promoteOverdueImpounds()
    if not Config.Auction.enabled then return end

    local overdue = MySQL.query.await([[
        SELECT plate, vehicle, citizenid AS owner
        FROM player_vehicles
        WHERE tx_garage_state = 'impound'
          AND tx_garage_impounded_at IS NOT NULL
          AND TIMESTAMPDIFF(SECOND, tx_garage_impounded_at, NOW()) >= ?
    ]], { (Config.Auction.impoundDays or 7) * 86400 })

    for _, v in ipairs(overdue or {}) do
        -- Skip if there's already an open auction for this plate
        local existing = MySQL.scalar.await(
            "SELECT id FROM tx_garage_auctions WHERE plate = ? AND status = 'open' LIMIT 1",
            { v.plate }
        )
        if not existing then
            local value = getVehicleValue(v.plate)
            local startingBid = math.floor(value * (Config.Auction.startingBidPercent or 0.10))
            local endsAt = os.date('%Y-%m-%d %H:%M:%S', os.time() + Config.Auction.auctionLength)

            local insertId = MySQL.insert.await([[
                INSERT INTO tx_garage_auctions
                  (plate, vehicle_model, starting_bid, current_bid, original_owner, ends_at)
                VALUES (?, ?, ?, ?, ?, ?)
            ]], { v.plate, v.vehicle, startingBid, startingBid, v.owner, endsAt })

            MySQL.update.await(
                "UPDATE player_vehicles SET tx_garage_state = 'auction' WHERE plate = ? AND tx_garage_state = 'impound'",
                { v.plate }
            )
            Utils.dbg('Auction opened:', v.plate, '#'..insertId, 'starting', startingBid)

            -- Webhook
            TriggerEvent('tx_garage:internalAuctionStart', v.plate, v.vehicle, value, startingBid)
        end
    end
end

local function closeExpiredAuctions()
    local expired = MySQL.query.await([[
        SELECT id, plate, vehicle_model, current_bid, leading_bidder, original_owner
        FROM tx_garage_auctions
        WHERE status = 'open' AND ends_at <= NOW()
    ]])

    for _, a in ipairs(expired or {}) do
        if a.leading_bidder then
            -- Bid was already debited at place-time. Transfer ownership atomically.
            local upd = MySQL.update.await([[
                UPDATE player_vehicles
                SET citizenid = ?, tx_garage_state = 'impound', tx_garage_impounded_at = NOW()
                WHERE plate = ? AND tx_garage_state = 'auction'
            ]], { a.leading_bidder, a.plate })

            if upd and upd > 0 then
                MySQL.update.await(
                    "UPDATE tx_garage_auctions SET status = 'closed' WHERE id = ?", { a.id }
                )
                distributePayout(a.original_owner, a.current_bid)

                -- Notify winner if online
                local winSrc = Garage.GetSrcByCid(a.leading_bidder)
                if winSrc then
                    Garage.Notify(winSrc,
                        Locale('auction.won', a.vehicle_model, Utils.formatMoney(a.current_bid)),
                        'success')
                    Garage.Notify(winSrc,
                        Locale('auction.retrieve_window', Config.Auction.retrieveWindowHours),
                        'inform')
                end

                TriggerEvent('tx_garage:internalAuctionWon', a.plate, a.vehicle_model, a.leading_bidder, a.current_bid)
                Utils.dbg('Auction closed:', a.plate, '→', a.leading_bidder, 'for', a.current_bid)
            end
        else
            -- No bids — return to impound; will re-promote later if still unclaimed
            MySQL.update.await(
                "UPDATE tx_garage_auctions SET status = 'closed' WHERE id = ?", { a.id }
            )
            MySQL.update.await(
                "UPDATE player_vehicles SET tx_garage_state = 'impound' WHERE plate = ? AND tx_garage_state = 'auction'",
                { a.plate }
            )
        end
    end
end

local function notifyWatchers()
    local soon = MySQL.query.await([[
        SELECT id, vehicle_model
        FROM tx_garage_auctions
        WHERE status = 'open'
          AND TIMESTAMPDIFF(SECOND, NOW(), ends_at) BETWEEN 0 AND ?
    ]], { WATCHLIST_NOTIFY_SECONDS + AUCTION_MIN_TICK_SECONDS })

    for _, a in ipairs(soon or {}) do
        local watchers = watchlist[a.id]
        if watchers then
            for cid, src in pairs(watchers) do
                if src and GetPlayerName(src) then
                    Garage.Notify(src, Locale('auction.closing_soon', a.vehicle_model), 'inform')
                end
            end
        end
    end
end

-- M2 fix: dynamic tick — sleep until next ends_at or 5 minutes, whichever sooner
local function nextTickDelay()
    local row = MySQL.query.await([[
        SELECT TIMESTAMPDIFF(SECOND, NOW(), MIN(ends_at)) AS s
        FROM tx_garage_auctions WHERE status = 'open'
    ]])
    local until_ = (row and row[1] and row[1].s) or AUCTION_MAX_TICK_SECONDS
    if not until_ then return AUCTION_MAX_TICK_SECONDS end
    if until_ <= 0 then return AUCTION_MIN_TICK_SECONDS end
    return math.min(math.max(until_, AUCTION_MIN_TICK_SECONDS), AUCTION_MAX_TICK_SECONDS)
end

CreateThread(function()
    while true do
        promoteOverdueImpounds()
        closeExpiredAuctions()
        notifyWatchers()
        Wait(nextTickDelay() * 1000)
    end
end)

-- ─────────────────────────────────────────────────────────────────────
-- Watchlist
-- ─────────────────────────────────────────────────────────────────────

RegisterNetEvent('tx_garage:watchAuction', function(auctionId, watching)
    local src = source
    local p = Garage.GetPlayer(src); if not p then return end
    auctionId = tonumber(auctionId); if not auctionId then return end

    local cid = Garage.GetCid(p)
    if watching then
        watchlist[auctionId] = watchlist[auctionId] or {}
        watchlist[auctionId][cid] = src
        Garage.Notify(src, Locale('auction.watch_on'), 'inform')
    else
        if watchlist[auctionId] then watchlist[auctionId][cid] = nil end
        Garage.Notify(src, Locale('auction.watch_off'), 'inform')
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    auctionCooldowns[src] = nil
    for _, watchers in pairs(watchlist) do
        for cid, s in pairs(watchers) do
            if s == src then watchers[cid] = nil end
        end
    end
end)

-- ─────────────────────────────────────────────────────────────────────
-- List & bid
-- ─────────────────────────────────────────────────────────────────────

lib.callback.register('tx_garage:listAuctions', function(src)
    local rows = MySQL.query.await([[
        SELECT id, plate, vehicle_model, starting_bid, current_bid, leading_bidder,
               UNIX_TIMESTAMP(ends_at) AS ends_at_ts
        FROM tx_garage_auctions
        WHERE status = 'open'
        ORDER BY ends_at ASC
    ]]) or {}
    -- Strip leading_bidder identifier — never expose to other clients
    -- (we replace it with a boolean: "you're the leader" if cid matches)
    local p = Garage.GetPlayer(src)
    local cid = p and Garage.GetCid(p) or nil
    for _, r in ipairs(rows) do
        r.is_leader = (cid and r.leading_bidder == cid) or false
        r.leading_bidder = nil
    end
    return rows
end)

RegisterNetEvent('tx_garage:placeBid', function(auctionId, amount)
    local src = source
    if Utils.isOnCooldown(auctionCooldowns, src, 'bid', 2) then return end

    local p = Garage.GetPlayer(src); if not p then return end
    auctionId = tonumber(auctionId); if not auctionId then return end
    amount = tonumber(amount); if not amount or amount <= 0 then return end

    local row = MySQL.query.await([[
        SELECT current_bid, leading_bidder, status,
               UNIX_TIMESTAMP(ends_at) AS ends_at_ts
        FROM tx_garage_auctions WHERE id = ? LIMIT 1
    ]], { auctionId })
    if not row or not row[1] then return end
    if row[1].status ~= 'open' then return end

    local previousBid     = tonumber(row[1].current_bid) or 0
    local previousBidder  = row[1].leading_bidder
    local minNext = previousBid + (Config.Auction.minBidIncrement or 100)
    if amount < minNext then
        Garage.Notify(src, Locale('auction.bid_too_low', Utils.formatMoney(minNext)), 'error')
        return
    end

    local cid = Garage.GetCid(p)

    -- BID ESCROW: debit the new bidder NOW. Refund happens on outbid or auction-cancel.
    if not Garage.RemoveMoney(src, 'bank', amount) then
        Garage.Notify(src, Locale('auction.no_money'), 'error')
        return
    end

    -- C1 fix: optimistic concurrency. Only update if current_bid is still what we read.
    -- If 0 rows affected, another bid raced ahead → refund and tell client to retry.
    local antiSnipeExtend = 0
    local now = os.time()
    if (row[1].ends_at_ts - now) < (Config.Auction.antiSnipeSeconds or 60) then
        antiSnipeExtend = Config.Auction.antiSnipeExtend or 60
    end

    local upd
    if antiSnipeExtend > 0 then
        upd = MySQL.update.await([[
            UPDATE tx_garage_auctions
            SET current_bid = ?, leading_bidder = ?,
                ends_at = DATE_ADD(ends_at, INTERVAL ? SECOND)
            WHERE id = ? AND current_bid = ? AND status = 'open'
        ]], { amount, cid, antiSnipeExtend, auctionId, previousBid })
    else
        upd = MySQL.update.await([[
            UPDATE tx_garage_auctions
            SET current_bid = ?, leading_bidder = ?
            WHERE id = ? AND current_bid = ? AND status = 'open'
        ]], { amount, cid, auctionId, previousBid })
    end

    if not upd or upd == 0 then
        -- Race lost — refund the bidder
        Garage.AddMoney(src, 'bank', amount)
        Garage.Notify(src, Locale('auction.bid_stale'), 'error')
        return
    end

    -- Refund the previous bidder (offline-safe)
    if previousBidder and previousBid > 0 then
        Garage.AddMoneyOffline(previousBidder, 'bank', previousBid)
        local prevSrc = Garage.GetSrcByCid(previousBidder)
        if prevSrc and prevSrc ~= src then
            Garage.Notify(prevSrc,
                Locale('auction.outbid', tostring(auctionId), Utils.formatMoney(amount)),
                'error')
            Garage.Notify(prevSrc,
                Locale('auction.refunded', Utils.formatMoney(previousBid)),
                'inform')
        end
    end

    MySQL.insert(
        'INSERT INTO tx_garage_auction_bids (auction_id, bidder, bid_amount) VALUES (?, ?, ?)',
        { auctionId, cid, amount }
    )

    Garage.Notify(src, Locale('success.payment', Utils.formatMoney(amount)), 'success')
    if antiSnipeExtend > 0 then
        Garage.Notify(src, Locale('auction.extended', antiSnipeExtend), 'inform')
    end

    -- Broadcast bid amount + new ends_at if extended (never the bidder identity)
    local endsTs
    if antiSnipeExtend > 0 then
        local r = MySQL.query.await(
            'SELECT UNIX_TIMESTAMP(ends_at) AS ts FROM tx_garage_auctions WHERE id = ? LIMIT 1',
            { auctionId }
        )
        endsTs = r and r[1] and r[1].ts or nil
    end
    TriggerClientEvent('tx_garage:auctionUpdate', -1, auctionId, amount, endsTs)
end)
