-- tx_garage v2.0 — Valet system
-- ────────────────────────────────────────────────────────────────────────────
-- Premium UX:
--   • Distance-based pricing (base + per-km)
--   • Anti-stuck: if path validation fails, server tells client to try fallback offsets
--   • Fuel deduction on delivery (uses ox_fuel via client setVehicleFuelLevel)
--   • Cancel refund (configurable %)
--   • Per-player cooldowns + active-job table prevents double-dispatch

local valetCooldowns = {}
local activeValets   = {}   -- src → { plate, vehicle, deliverAt, cost, cancelled, fromCoords }

local function inCooldown(src)
    local last = valetCooldowns[src]
    return last and (os.time() - last) < Config.Valet.cooldown
end

local function nearestGarageDistance(coords)
    local nearest = math.huge
    for _, g in ipairs(Config.Garages) do
        local d = Utils.dist(coords, g.coords)
        if d < nearest then nearest = d end
    end
    return nearest
end

local function calculateValetCost(coords)
    local nearest = nearestGarageDistance(coords)
    local km = nearest / 1000.0
    return math.floor(Config.Valet.callCost + km * Config.Valet.pricePerKm)
end

RegisterNetEvent('tx_garage:requestValet', function(garageName, fromCoords)
    local src = source
    if not Config.Valet.enabled then return end
    if Utils.isOnCooldown(valetCooldowns, src, '_check', 1) then return end

    local p = Garage.GetPlayer(src); if not p then return end

    -- Validate inputs
    if type(garageName) ~= 'string' or #garageName > 64 then return end
    if type(fromCoords) ~= 'table'
       or type(fromCoords.x) ~= 'number'
       or type(fromCoords.y) ~= 'number'
       or type(fromCoords.z) ~= 'number' then return end

    -- Distance gate
    local dist = nearestGarageDistance(fromCoords)
    if dist > (Config.Valet.maxDistance or 500.0) then
        Garage.Notify(src, Locale('valet.too_far', math.floor(Config.Valet.maxDistance)), 'error')
        return
    end

    if inCooldown(src) then
        local remaining = Config.Valet.cooldown - (os.time() - valetCooldowns[src])
        Garage.Notify(src, Locale('valet.cooldown', remaining), 'error')
        return
    end
    if activeValets[src] then
        Garage.Notify(src, Locale('valet.in_progress'), 'error'); return
    end

    -- Server-side plate selection — never trust client to pick the vehicle.
    local cid = Garage.GetCid(p)
    local pick = MySQL.query.await([[
        SELECT plate, vehicle FROM player_vehicles
        WHERE (citizenid = ? OR JSON_CONTAINS(IFNULL(tx_garage_sub_owners,'[]'), JSON_QUOTE(?)))
          AND tx_garage_state = 'stored'
          AND (tx_garage_name = ? OR tx_garage_name IS NULL)
        ORDER BY tx_garage_fav DESC, plate DESC
        LIMIT 1
    ]], { cid, cid, garageName })
    if not pick or not pick[1] then
        Garage.Notify(src, Locale('valet.no_vehicles'), 'error'); return
    end

    local plate   = pick[1].plate
    local vehicle = pick[1].vehicle
    local cost    = calculateValetCost(fromCoords)

    if not Garage.RemoveMoney(src, 'cash', cost) then
        Garage.Notify(src, Locale('valet.not_enough_money', Utils.formatMoney(cost)), 'error')
        return
    end

    local eta = math.random(Config.Valet.deliveryTime.min, Config.Valet.deliveryTime.max)
    activeValets[src] = {
        plate       = plate,
        vehicle     = vehicle,
        requestedAt = os.time(),
        deliverAt   = os.time() + eta,
        cost        = cost,
        fromCoords  = fromCoords,
        cancelled   = false,
    }

    MySQL.insert(
        'INSERT INTO tx_garage_valet_log (citizenid, plate, cost) VALUES (?, ?, ?)',
        { cid, plate, cost }
    )

    Garage.Notify(src, Locale('valet.requested', eta, Utils.formatMoney(cost)), 'inform')

    SetTimeout(eta * 1000, function()
        local job = activeValets[src]
        if not job or job.cancelled then return end

        -- Atomic state transition (only deliver if still 'stored')
        local upd = MySQL.update.await([[
            UPDATE player_vehicles SET tx_garage_state = 'out', tx_garage_name = NULL
            WHERE plate = ? AND tx_garage_state = 'stored'
        ]], { plate })

        if not upd or upd == 0 then
            -- Vehicle moved out from under us (admin spawned, etc.) — refund full
            Garage.AddMoney(src, 'cash', cost)
            Garage.Notify(src, Locale('error.bad_state'), 'error')
            activeValets[src] = nil
            return
        end

        -- Fuel deduction is applied client-side on spawn (server tells client how much to subtract)
        TriggerClientEvent('tx_garage:valetDeliver', src,
            plate, vehicle, job.fromCoords,
            Config.Valet.fuelDeduction or 5.0)

        Garage.Notify(src, Locale('valet.arrived'), 'success')

        MySQL.update(
            [[UPDATE tx_garage_valet_log SET delivered_at = NOW()
              WHERE citizenid = ? AND plate = ? AND delivered_at IS NULL
              ORDER BY id DESC LIMIT 1]],
            { cid, plate }
        )

        valetCooldowns[src] = os.time()
        activeValets[src]   = nil
    end)
end)

RegisterNetEvent('tx_garage:cancelValet', function()
    local src = source
    local job = activeValets[src]
    if not job or job.cancelled then return end

    job.cancelled = true
    local refund = math.floor(job.cost * (Config.Valet.cancelRefund or 0.5))
    if refund > 0 then Garage.AddMoney(src, 'cash', refund) end
    Garage.Notify(src, Locale('valet.cancelled', Utils.formatMoney(refund)), 'inform')

    local p = Garage.GetPlayer(src)
    if p then
        MySQL.update(
            [[UPDATE tx_garage_valet_log SET cancelled_at = NOW()
              WHERE citizenid = ? AND plate = ? AND cancelled_at IS NULL
              ORDER BY id DESC LIMIT 1]],
            { Garage.GetCid(p), job.plate }
        )
    end

    activeValets[src] = nil
end)

-- Client tells us its anti-stuck path failed; we permit a refund + retry.
RegisterNetEvent('tx_garage:valetPathFailed', function()
    local src = source
    local job = activeValets[src]
    if not job then return end
    job.cancelled = true
    Garage.AddMoney(src, 'cash', job.cost)
    Garage.Notify(src, Locale('valet.path_blocked'), 'error')
    activeValets[src] = nil
end)

AddEventHandler('playerDropped', function()
    local src = source
    if activeValets[src] then activeValets[src].cancelled = true end
    activeValets[src]   = nil
    valetCooldowns[src] = nil
end)
