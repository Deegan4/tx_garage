-- tx_garage — Valet system server logic
-- Differentiator #1: no competing FiveM garage script ships valet support as of May 2026.

local valetCooldowns = {}
local activeValets = {}  -- src -> { plate, requestedAt, deliverAt, cost, cancelled }

local function inCooldown(src)
    local last = valetCooldowns[src]
    return last and (os.time() - last) < Config.Valet.cooldown
end

RegisterNetEvent('tx_garage:requestValet', function(plate, fromCoords)
    local src = source
    if not Config.Valet.enabled then return end

    local p = Bridge.GetPlayer(src)
    if not p then return end

    if inCooldown(src) then
        Bridge.Notify(src, Locale('valet.cooldown',
            Config.Valet.cooldown - (os.time() - valetCooldowns[src])), 'error')
        return
    end

    if activeValets[src] then
        Bridge.Notify(src, Locale('error.cooldown'), 'error')
        return
    end

    -- Verify the player owns this vehicle and it's stored
    local id = Bridge.GetIdentifier(p)
    local ownSql = (Config.Framework == 'esx')
        and 'SELECT vehicle, tx_garage_state AS state FROM player_vehicles WHERE owner=? AND plate=? LIMIT 1'
        or  'SELECT vehicle, tx_garage_state AS state FROM player_vehicles WHERE citizenid=? AND plate=? LIMIT 1'
    local owns = MySQL.query.await(ownSql, { id, plate })
    if not owns or not owns[1] or owns[1].state ~= 'stored' then
        Bridge.Notify(src, Locale('error.not_owner'), 'error')
        return
    end

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
