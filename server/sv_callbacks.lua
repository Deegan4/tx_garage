-- tx_garage v2.0 — Centralized lib.callback registrations
-- ────────────────────────────────────────────────────────────────────────────
-- Pure read-only callbacks live here. Mutating callbacks are colocated with
-- their domain logic (sv_garage, sv_auction, sv_valet).

-- Trimmed config for client (strip server-only fields)
lib.callback.register('tx_garage:getConfig', function(src)
    return {
        Currency       = Config.Currency,
        ResourceName   = Config.ResourceName,
        GarageTypes    = Config.GarageTypes,
        Garages        = Config.Garages,
        Valet          = {
            enabled        = Config.Valet.enabled,
            callCost       = Config.Valet.callCost,
            pricePerKm     = Config.Valet.pricePerKm,
            maxDistance    = Config.Valet.maxDistance,
            cancelRefund   = Config.Valet.cancelRefund,
        },
        Auction        = {
            enabled             = Config.Auction.enabled,
            minBidIncrement     = Config.Auction.minBidIncrement,
            retrieveWindowHours = Config.Auction.retrieveWindowHours,
            antiSnipeSeconds    = Config.Auction.antiSnipeSeconds,
            antiSnipeExtend     = Config.Auction.antiSnipeExtend,
            auctionLot          = Config.Auction.auctionLot,
            auctionBlip         = Config.Auction.auctionBlip,
        },
        Impound        = Config.Impound,
        Notify         = Config.Notify,
        Interaction    = Config.Interaction,
        PlateChange    = Config.PlateChange,
        SubOwners      = Config.SubOwners,
        Transfer       = Config.Transfer,
        Debug          = Config.Debug,
    }
end)

-- ─────────────────────────────────────────────────────────────────────
-- Vehicle search (used by NUI search bar)
-- ─────────────────────────────────────────────────────────────────────
lib.callback.register('tx_garage:searchVehicles', function(src, query)
    local p = Garage.GetPlayer(src); if not p then return {} end
    local cid = Garage.GetCid(p)
    if type(query) ~= 'string' or #query == 0 then return {} end
    -- Sanitize: only letters/digits/space/dash
    query = query:gsub('[^%w%s%-]', ''):sub(1, 32)
    local like = '%'..query..'%'
    return MySQL.query.await([[
        SELECT plate, vehicle, tx_garage_name AS at_garage,
               tx_garage_state AS state, tx_garage_fav,
               tx_garage_mileage AS mileage
        FROM player_vehicles
        WHERE citizenid = ?
          AND tx_garage_state IN ('stored','impound','out')
          AND (plate LIKE ? OR vehicle LIKE ?)
        ORDER BY tx_garage_fav DESC
        LIMIT 20
    ]], { cid, like, like })
end)

-- ─────────────────────────────────────────────────────────────────────
-- Sub-owner list (read-only; mutations are in sv_events)
-- ─────────────────────────────────────────────────────────────────────
lib.callback.register('tx_garage:getSubOwners', function(src, plate)
    local p = Garage.GetPlayer(src); if not p then return {} end
    plate = Utils.normalizePlate(plate); if not plate then return {} end

    local row = MySQL.query.await([[
        SELECT tx_garage_sub_owners FROM player_vehicles
        WHERE plate = ? AND citizenid = ? LIMIT 1
    ]], { plate, Garage.GetCid(p) })
    if not row or not row[1] or not row[1].tx_garage_sub_owners then return {} end

    local list = json.decode(row[1].tx_garage_sub_owners) or {}
    -- Resolve display names
    local enriched = {}
    for _, c in ipairs(list) do
        local nameRow = MySQL.query.await(
            'SELECT charinfo FROM players WHERE citizenid = ? LIMIT 1', { c }
        )
        local name = c
        if nameRow and nameRow[1] and nameRow[1].charinfo then
            local info = json.decode(nameRow[1].charinfo)
            if info and info.firstname then
                name = (info.firstname or '') .. ' ' .. (info.lastname or '')
            end
        end
        enriched[#enriched+1] = { citizenid = c, name = name }
    end
    return enriched
end)

-- ─────────────────────────────────────────────────────────────────────
-- Boss menu: society balance from ledger
-- ─────────────────────────────────────────────────────────────────────
lib.callback.register('tx_garage:getSocietyBalance', function(src, society)
    local p = Garage.GetPlayer(src); if not p then return 0 end
    if not Garage.IsBoss(p) then return 0 end
    if Garage.GetJob(p) ~= society then return 0 end

    local row = MySQL.query.await([[
        SELECT
            COALESCE(SUM(CASE WHEN action IN ('deposit','auction_cut') THEN amount ELSE 0 END), 0)
          - COALESCE(SUM(CASE WHEN action = 'withdraw' THEN amount ELSE 0 END), 0)
            AS balance
        FROM tx_garage_society_log WHERE society = ?
    ]], { society })
    return (row and row[1] and tonumber(row[1].balance)) or 0
end)
