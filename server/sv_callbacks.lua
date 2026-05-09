-- tx_garage — Centralized lib.callback registrations

-- Favorite / pin a vehicle
RegisterNetEvent('tx_garage:favoriteVehicle', function(plate, fav)
    local src = source
    local p = Bridge.GetPlayer(src)
    if not p then return end
    local id = Bridge.GetIdentifier(p)
    local isEsx = Config.Framework == 'esx'
    local ownSql = isEsx
        and 'SELECT 1 FROM player_vehicles WHERE owner=? AND plate=? LIMIT 1'
        or  'SELECT 1 FROM player_vehicles WHERE citizenid=? AND plate=? LIMIT 1'
    if not MySQL.scalar.await(ownSql, { id, plate }) then return end
    MySQL.update.await(
        'UPDATE player_vehicles SET tx_garage_fav=? WHERE plate=?',
        { fav and 1 or 0, plate }
    )
end)

lib.callback.register('tx_garage:getConfig', function(src)
    -- Strip server-only fields, return only what the client needs to render UI
    return {
        Currency       = Config.Currency,
        GarageTypes    = Config.GarageTypes,
        Garages        = Config.Garages,
        Valet          = Config.Valet,
        Auction        = {
            enabled            = Config.Auction.enabled,
            minBidIncrement    = Config.Auction.minBidIncrement,
            retrieveWindowHours = Config.Auction.retrieveWindowHours,
        },
        Impound        = Config.Impound,
        Notify         = Config.Notify,
        Interaction    = Config.Interaction,
    }
end)
