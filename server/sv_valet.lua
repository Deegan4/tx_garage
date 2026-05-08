-- tx_garage — Valet system server logic
-- Differentiator #1: no competing FiveM garage script ships valet support as of May 2026.

local valetCooldowns = {}
local activeValets = {}  -- src -> { plate, requestedAt, deliverAt, cost, cancelled }

local function inCooldown(src)
    local last = valetCooldowns[src]
    return last and (os.time() - last) < Config.Valet.cooldown
end

RegisterNetEvent('tx_garage:requestValet', function(garageName, fromCoords)
    local src = source
    if not Config.Valet.enabled then return end

    local p = Bridge.GetPlayer(src)
    if not p then return end

    -- Validate inputs (never trust client)
    if type(garageName) ~= 'string' or #garageName > 64 then return end
    if type(fromCoords) ~= 'table' or
       type(fromCoords.x) ~= 'number' or
       type(fromCoords.y) ~= 'number' or
       type(fromCoords.z) ~= 'number' then return end

    -- Enforce Config.Valet.maxDistance: the caller must be within range of at
    -- least one configured garage. Coords are client-supplied, so this enforces
    -- policy rather than authority — but cheating "I'm near a garage" only
    -- spawns the vehicle where the client said it was anyway (same coords flow
    -- through to cl_valet.lua for spawn placement), so there's nothing to gain.
    local maxDist = Config.Valet.maxDistance or 500.0
    local nearestGarage = math.huge
    for _, g in ipairs(Config.Garages) do
        local dx = fromCoords.x - g.coords.x
        local dy = fromCoords.y - g.coords.y
        local dz = fromCoords.z - g.coords.z
        local d = math.sqrt(dx * dx + dy * dy + dz * dz)
        if d < nearestGarage then nearestGarage = d end
    end
    if nearestGarage > maxDist then
        Bridge.Notify(src, Locale('valet.too_far', math.floor(maxDist)), 'error')
        return
    end

    if inCooldown(src) then
        Bridge.Notify(src, Locale('valet.cooldown',
            Config.Valet.cooldown - (os.time() - valetCooldowns[src])), 'error')
        return
    end

    if activeValets[src] then
        Bridge.Notify(src, Locale('error.cooldown'), 'error')
        return
    end

    -- Server-side plate resolution: pick one of the caller's stored vehicles in this garage.
    -- ORDER BY plate DESC is deterministic but arbitrary — there is no created_at column on
    -- player_vehicles in the standard schema, so "most-recent" cannot be expressed without
    -- a schema change (deferred to v1.1 to keep INSTALL.sql non-destructive).
    -- We never accept a client-supplied plate — prevents stealing other players' vehicles.
    local id = Bridge.GetIdentifier(p)
    local pickSql = (Config.Framework == 'esx')
        and [[SELECT plate, vehicle FROM player_vehicles
              WHERE owner=? AND tx_garage_state='stored' AND (tx_garage_name=? OR tx_garage_name IS NULL)
              ORDER BY plate DESC LIMIT 1]]
        or  [[SELECT plate, vehicle FROM player_vehicles
              WHERE citizenid=? AND tx_garage_state='stored' AND (tx_garage_name=? OR tx_garage_name IS NULL)
              ORDER BY plate DESC LIMIT 1]]
    local owns = MySQL.query.await(pickSql, { id, garageName })
    if not owns or not owns[1] then
        Bridge.Notify(src, Locale('error.not_owner'), 'error')
        return
    end
    local plate = owns[1].plate
    -- Synthesize the same shape the rest of the handler expects
    owns = { { vehicle = owns[1].vehicle, state = 'stored' } }

    -- Charge upfront
    if not Bridge.RemoveMoney(src, 'cash', Config.Valet.callCost) then
        Bridge.Notify(src, Locale('valet.not_enough_money', Utils.formatMoney(Config.Valet.callCost)), 'error')
        return
    end

    local eta = math.random(Config.Valet.deliveryTime.min, Config.Valet.deliveryTime.max)
    local deliverAt = os.time() + eta
    activeValets[src] = {
        plate = plate,
        vehicle = owns[1].vehicle,
        requestedAt = os.time(),
        deliverAt = deliverAt,
        cost = Config.Valet.callCost,
        fromCoords = fromCoords,
        cancelled = false,
    }

    -- Log
    MySQL.insert('INSERT INTO tx_garage_valet_log (citizenid, plate, cost) VALUES (?, ?, ?)',
        { id, plate, Config.Valet.callCost })

    Bridge.Notify(src, Locale('valet.requested', eta), 'inform')

    -- Schedule delivery
    SetTimeout(eta * 1000, function()
        local job = activeValets[src]
        if not job or job.cancelled then return end

        -- Mark vehicle out and spawn it client-side
        MySQL.update.await([[
            UPDATE player_vehicles
            SET tx_garage_state = 'out', tx_garage_name = NULL
            WHERE plate = ?
        ]], { plate })

        TriggerClientEvent('tx_garage:valetDeliver', src, plate, job.vehicle, job.fromCoords)
        TriggerEvent('qb-vehiclekeys:server:GiveKeys', src, plate)
        Bridge.Notify(src, Locale('valet.arrived'), 'success')

        MySQL.update('UPDATE tx_garage_valet_log SET delivered_at = NOW() WHERE citizenid = ? AND plate = ? AND delivered_at IS NULL ORDER BY id DESC LIMIT 1',
            { Bridge.GetIdentifier(p), plate })

        valetCooldowns[src] = os.time()
        activeValets[src] = nil
    end)
end)

RegisterNetEvent('tx_garage:cancelValet', function()
    local src = source
    local job = activeValets[src]
    if not job or job.cancelled then return end

    job.cancelled = true
    local refund = math.floor(job.cost * Config.Valet.cancelRefund)
    if refund > 0 then
        Bridge.AddMoney(src, 'cash', refund)
    end

    Bridge.Notify(src, Locale('valet.cancelled', Utils.formatMoney(refund)), 'inform')

    local p = Bridge.GetPlayer(src)
    if p then
        MySQL.update('UPDATE tx_garage_valet_log SET cancelled_at = NOW() WHERE citizenid = ? AND plate = ? AND cancelled_at IS NULL ORDER BY id DESC LIMIT 1',
            { Bridge.GetIdentifier(p), job.plate })
    end

    activeValets[src] = nil
end)

AddEventHandler('playerDropped', function()
    local src = source
    if activeValets[src] then activeValets[src].cancelled = true end
    activeValets[src] = nil
    valetCooldowns[src] = nil
end)
