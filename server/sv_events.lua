-- tx_garage — Misc server events (keys, etc.)

RegisterNetEvent('tx_garage:giveKey', function(plate, targetServerId)
    local src = source
    local p = Bridge.GetPlayer(src)
    if not p then return end

    local target = Bridge.GetPlayer(targetServerId)
    if not target then return end

    -- Verify caller owns the vehicle before handing off keys
    local id = Bridge.GetIdentifier(p)
    local ownSql = (Config.Framework == 'esx')
        and 'SELECT 1 FROM player_vehicles WHERE owner=? AND plate=? LIMIT 1'
        or  'SELECT 1 FROM player_vehicles WHERE citizenid=? AND plate=? LIMIT 1'
    if not MySQL.scalar.await(ownSql, { id, plate }) then
        Bridge.Notify(src, Locale('error.not_owner'), 'error')
        return
    end

    -- Hand off to keys resource if configured
    if Config.Storage.keysResource == 'qb-vehiclekeys' then
        TriggerClientEvent('qb-vehiclekeys:client:GiveKeys', targetServerId, plate)
    elseif Config.Storage.keysResource == 'qs-vehiclekeys' then
        exports['qs-vehiclekeys']:GiveKeys(targetServerId, plate)
    else
        -- Default: trust framework's default behavior
        TriggerClientEvent('vehiclekeys:client:SetOwner', targetServerId, plate)
    end

    Bridge.Notify(src, Locale('ui.garage.givekey'), 'success')
    Bridge.Notify(targetServerId, Locale('ui.garage.givekey'), 'success')
end)
