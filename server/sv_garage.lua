-- tx_garage v2.0 — Core garage logic
-- ────────────────────────────────────────────────────────────────────────────
-- Security model:
--   • Server is the single source of truth for ownership and state.
--   • Every mutation uses WHERE clauses that include the EXPECTED state, so a
--     concurrent path that already mutated the row results in 0 affectedRows
--     and we reject (treats race as hostile).
--   • Money/health values from the client are clamped against DB previous
--     values — we never let stored health *increase* between sessions.
--   • Per-source cooldowns on every net event.

local cooldowns = {}

local function isOnCooldown(src, key, seconds)
    return Utils.isOnCooldown(cooldowns, src, key, seconds)
end

AddEventHandler('playerDropped', function() cooldowns[source] = nil end)

-- ─────────────────────────────────────────────────────────────────────
-- Ownership helpers
-- ─────────────────────────────────────────────────────────────────────

---Returns true if the citizenid is the owner OR a sub-owner of the plate.
local function ownsOrSubOwns(cid, plate)
    local row = MySQL.query.await(
        'SELECT citizenid, tx_garage_sub_owners FROM player_vehicles WHERE plate = ? LIMIT 1',
        { plate }
    )
    if not row or not row[1] then return false, false end
    local r = row[1]
    if r.citizenid == cid then return true, true end  -- isOwner=true, isAuthorized=true
    if Config.SubOwners.enabled and r.tx_garage_sub_owners then
        local list = json.decode(r.tx_garage_sub_owners) or {}
        for _, c in ipairs(list) do
            if c == cid then return false, true end   -- isAuthorized but not full owner
        end
    end
    return false, false
end

local function isFullOwner(cid, plate)
    local owned = MySQL.scalar.await(
        'SELECT 1 FROM player_vehicles WHERE citizenid = ? AND plate = ? LIMIT 1',
        { cid, plate }
    )
    return owned == 1
end

-- ─────────────────────────────────────────────────────────────────────
-- List vehicles for a garage
-- ─────────────────────────────────────────────────────────────────────

local function listVehicles(cid, garage)
    if garage.type == 'impound' then
        return MySQL.query.await([[
            SELECT plate, vehicle, mods, fuel, engine, body,
                   tx_garage_state AS state, tx_garage_impounded_at AS impounded_at,
                   tx_garage_fav, tx_garage_mileage AS mileage
            FROM player_vehicles
            WHERE citizenid = ? AND tx_garage_state = 'impound'
            ORDER BY tx_garage_fav DESC, plate ASC
        ]], { cid })
    end

    -- Owner OR sub-owner, in 'stored' state, in this garage (or NULL == any)
    return MySQL.query.await([[
        SELECT plate, vehicle, mods, fuel, engine, body,
               tx_garage_name AS at_garage, tx_garage_state AS state,
               tx_garage_fav, tx_garage_mileage AS mileage,
               (citizenid = ?) AS is_owner
        FROM player_vehicles
        WHERE (citizenid = ? OR JSON_CONTAINS(IFNULL(tx_garage_sub_owners, '[]'), JSON_QUOTE(?)))
          AND tx_garage_state = 'stored'
          AND (tx_garage_name = ? OR tx_garage_name IS NULL)
        ORDER BY tx_garage_fav DESC, plate ASC
    ]], { cid, cid, cid, garage.name })
end

lib.callback.register('tx_garage:listVehicles', function(src, garageName)
    local p = Garage.GetPlayer(src); if not p then return {} end
    local garage = Garage.FindGarage(garageName); if not garage then return {} end

    -- Permission gate
    if garage.type == 'job' and garage.jobs and not Garage.HasJob(p, garage.jobs) then return {} end
    if garage.type == 'gang' and garage.gangs and not Garage.HasGang(p, garage.gangs) then return {} end
    if garage.type == 'vip' and garage.aceCheck and not Garage.HasAce(src, garage.aceCheck) then return {} end

    return listVehicles(Garage.GetCid(p), garage) or {}
end)

-- ─────────────────────────────────────────────────────────────────────
-- Retrieve (handles weekly rent for private — fixes H1)
-- ─────────────────────────────────────────────────────────────────────

local function chargePrivateRent(src, plate)
    local cfg = Config.GarageTypes.private
    if cfg.cost <= 0 then return true end

    local row = MySQL.query.await(
        'SELECT tx_garage_rent_paid_at FROM player_vehicles WHERE plate = ? LIMIT 1', { plate }
    )
    if not row or not row[1] then return true end

    local last = row[1].tx_garage_rent_paid_at
    if last then
        -- Skip if within rentDays
        local elapsed = MySQL.scalar.await(
            'SELECT TIMESTAMPDIFF(SECOND, ?, NOW())', { last }
        ) or math.huge
        if elapsed < (cfg.rentDays or 7) * 86400 then return true end
    end

    if not Garage.RemoveMoney(src, 'bank', cfg.cost) then return false end
    MySQL.update.await(
        'UPDATE player_vehicles SET tx_garage_rent_paid_at = NOW() WHERE plate = ?', { plate }
    )
    Garage.Notify(src, Locale('success.payment', Utils.formatMoney(cfg.cost)), 'inform')
    return true
end

-- Returns: result table, or nil + error string
lib.callback.register('tx_garage:retrieveVehicle', function(src, garageName, plate)
    if isOnCooldown(src, 'retrieve', 3) then return nil, 'cooldown' end

    local p = Garage.GetPlayer(src); if not p then return nil, 'no_player' end
    local garage = Garage.FindGarage(garageName); if not garage then return nil, 'no_garage' end
    plate = Utils.normalizePlate(plate); if not plate then return nil, 'bad_plate' end

    local cid = Garage.GetCid(p)
    local _, authorized = ownsOrSubOwns(cid, plate)
    if not authorized then
        Garage.Notify(src, Locale('error.not_owner'), 'error')
        return nil, 'not_owner'
    end

    -- Verify state matches the garage type (impound vs stored)
    local expectedState = (garage.type == 'impound') and 'impound' or 'stored'
    local row = MySQL.query.await([[
        SELECT vehicle, mods, fuel, engine, body, tx_garage_state AS state,
               tx_garage_impounded_at AS impounded_at, tx_garage_mileage AS mileage,
               tx_garage_name AS at_garage
        FROM player_vehicles WHERE plate = ? LIMIT 1
    ]], { plate })
    if not row or not row[1] or row[1].state ~= expectedState then
        Garage.Notify(src, Locale('error.bad_state'), 'error')
        return nil, 'bad_state'
    end
    local v = row[1]
    -- For stored vehicles, additionally enforce garage name match (NULL means any)
    if expectedState == 'stored' and v.at_garage and v.at_garage ~= garage.name then
        Garage.Notify(src, Locale('error.bad_state'), 'error')
        return nil, 'wrong_garage'
    end

    -- Fees
    if garage.type == 'impound' then
        local days = 1
        if v.impounded_at then
            local elapsed = MySQL.scalar.await(
                'SELECT TIMESTAMPDIFF(SECOND, ?, NOW())', { v.impounded_at }
            ) or 86400
            days = math.max(1, math.ceil(elapsed / 86400))
        end
        local cost = Config.Impound.baseCost + (days * Config.Impound.perDayCost)
        if not Garage.RemoveMoney(src, Config.Impound.paymentAccount, cost) then
            Garage.Notify(src, Locale('error.no_money'), 'error')
            return nil, 'no_money'
        end
        Garage.Notify(src, Locale('success.payment', Utils.formatMoney(cost)), 'success')
    elseif garage.type == 'private' then
        if not chargePrivateRent(src, plate) then
            Garage.Notify(src, Locale('error.no_money'), 'error')
            return nil, 'no_money'
        end
    end

    -- Atomic state transition: stored/impound → out, ONLY if state is still what we read.
    -- Concurrent retrieve attempts (dupe path) result in 0 affectedRows → reject second caller.
    local upd = MySQL.update.await([[
        UPDATE player_vehicles
        SET tx_garage_state = 'out', tx_garage_name = NULL, tx_garage_impounded_at = NULL
        WHERE plate = ? AND tx_garage_state = ?
    ]], { plate, expectedState })
    if not upd or upd == 0 then
        Garage.Notify(src, Locale('error.bad_state'), 'error')
        return nil, 'race_lost'
    end

    return {
        spawn   = garage.spawn,
        model   = v.vehicle,
        plate   = plate,
        mods    = v.mods,
        fuel    = v.fuel,
        engine  = v.engine,
        body    = v.body,
        mileage = v.mileage or 0,
    }
end)

-- ─────────────────────────────────────────────────────────────────────
-- Store (fixes C4 — state guard, H2 — health clamp, C5 — callback flow)
-- ─────────────────────────────────────────────────────────────────────

lib.callback.register('tx_garage:storeVehicle', function(src, garageName, plate, props)
    if isOnCooldown(src, 'store', 2) then return false, 'cooldown' end

    local p = Garage.GetPlayer(src); if not p then return false, 'no_player' end
    local garage = Garage.FindGarage(garageName); if not garage then return false, 'no_garage' end
    if not Config.GarageTypes[garage.type].canStore then return false, 'cannot_store' end
    plate = Utils.normalizePlate(plate); if not plate then return false, 'bad_plate' end
    if type(props) ~= 'table' then return false, 'bad_props' end

    local cid = Garage.GetCid(p)
    local _, authorized = ownsOrSubOwns(cid, plate)
    if not authorized then
        Garage.Notify(src, Locale('error.not_owner'), 'error')
        return false, 'not_owner'
    end

    -- C4 fix: only store vehicles currently in 'out' state.
    -- Read previous health values for H2 clamp.
    local prev = MySQL.query.await([[
        SELECT fuel, engine, body, tx_garage_state AS state,
               tx_garage_mileage AS mileage
        FROM player_vehicles WHERE plate = ? LIMIT 1
    ]], { plate })
    if not prev or not prev[1] or prev[1].state ~= 'out' then
        Garage.Notify(src, Locale('error.bad_state'), 'error')
        return false, 'bad_state'
    end
    local prevRow = prev[1]

    -- H2 fix: clamp health values — never let stored values exceed previous.
    -- Players can only ever DAMAGE a vehicle further between sessions, never heal.
    -- (Repair must happen via mechanic resources before storing.)
    local maxFuel   = Utils.clamp(prevRow.fuel   or Config.Storage.maxStoreFuel,   0, Config.Storage.maxStoreFuel)
    local maxEngine = Utils.clamp(prevRow.engine or Config.Storage.maxStoreEngine, 0, Config.Storage.maxStoreEngine)
    local maxBody   = Utils.clamp(prevRow.body   or Config.Storage.maxStoreBody,   0, Config.Storage.maxStoreBody)

    local fuel   = Utils.clamp(tonumber(props.fuel)   or maxFuel,   0, maxFuel)
    local engine = Utils.clamp(tonumber(props.engine) or maxEngine, 0, maxEngine)
    local body   = Utils.clamp(tonumber(props.body)   or maxBody,   0, maxBody)

    -- Mileage is monotonic — never decrease.
    local newMileage = math.max(tonumber(prevRow.mileage) or 0, tonumber(props.mileage) or 0)

    -- Mods JSON: validate parseable
    local modsJson = '{}'
    if type(props.mods) == 'table' then
        local ok, encoded = pcall(json.encode, props.mods)
        if ok then modsJson = encoded end
    elseif type(props.mods) == 'string' then
        -- Sanity: must be valid JSON
        local ok = pcall(json.decode, props.mods)
        if ok then modsJson = props.mods end
    end

    local upd = MySQL.update.await([[
        UPDATE player_vehicles
        SET tx_garage_state = 'stored', tx_garage_name = ?,
            mods = ?, fuel = ?, engine = ?, body = ?, tx_garage_mileage = ?
        WHERE plate = ? AND tx_garage_state = 'out'
    ]], { garage.name, modsJson, fuel, engine, body, newMileage, plate })

    if not upd or upd == 0 then
        Garage.Notify(src, Locale('error.bad_state'), 'error')
        return false, 'race_lost'
    end

    Garage.Notify(src, Locale('success.vehicle_stored'), 'success')
    return true
end)

-- ─────────────────────────────────────────────────────────────────────
-- Police impound (C6 fix — vehicle must be unoccupied & stationary)
-- ─────────────────────────────────────────────────────────────────────

RegisterNetEvent('tx_garage:policeImpound', function(vehicleNetId)
    local src = source
    if isOnCooldown(src, 'policeImpound', 3) then return end

    local p = Garage.GetPlayer(src); if not p then return end

    -- Job + grade gate
    if not Garage.HasJob(p, Config.PoliceImpound.jobs) then
        Garage.Notify(src, Locale('error.no_permission'), 'error'); return
    end
    if Garage.GetJobGrade(p) < (Config.PoliceImpound.minGrade or 0) then
        Garage.Notify(src, Locale('error.no_permission'), 'error'); return
    end

    if type(vehicleNetId) ~= 'number' or vehicleNetId <= 0 then return end
    local veh = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then
        Garage.Notify(src, Locale('error.not_owner'), 'error'); return
    end

    -- Read plate from entity (server is authoritative)
    local plate = Utils.normalizePlate(GetVehicleNumberPlateText(veh))
    if not plate then return end

    -- Validate plate is in player_vehicles
    local known = MySQL.scalar.await(
        'SELECT 1 FROM player_vehicles WHERE plate = ? LIMIT 1', { plate }
    )
    if not known then
        Garage.Notify(src, Locale('error.not_owner'), 'error'); return
    end

    -- Proximity gate
    local cop = GetPlayerPed(src); if not cop or cop == 0 then return end
    local copPos = GetEntityCoords(cop)
    local vehPos = GetEntityCoords(veh)
    if #(copPos - vehPos) > (Config.PoliceImpound.radius or 5.0) then
        Garage.Notify(src, Locale('error.no_permission'), 'error'); return
    end

    -- C6 fix: vehicle must be unoccupied
    local pedInside = GetPedInVehicleSeat(veh, -1)
    if pedInside and pedInside ~= 0 and DoesEntityExist(pedInside) then
        Garage.Notify(src, Locale('impound.occupied'), 'error'); return
    end

    -- C6 fix: vehicle must be stopped
    if Config.Impound.requireStopped then
        local speed = GetEntitySpeed(veh)
        if speed and speed > (Config.Impound.speedThreshold or 1.0) then
            Garage.Notify(src, Locale('impound.moving'), 'error'); return
        end
    end

    -- C7 fix: only impound vehicles currently in 'out' state
    local upd = MySQL.update.await([[
        UPDATE player_vehicles
        SET tx_garage_state = 'impound', tx_garage_impounded_at = NOW(), tx_garage_name = 'mrpd_impound'
        WHERE plate = ? AND tx_garage_state = 'out'
    ]], { plate })
    if not upd or upd == 0 then
        Garage.Notify(src, Locale('error.bad_state'), 'error'); return
    end

    -- Tell every client to delete the vehicle entity (the cop's client will too)
    TriggerClientEvent('tx_garage:deleteVehicle', -1, vehicleNetId)
    Garage.Notify(src, Locale('success.vehicle_stored'), 'success')

    -- Webhook
    TriggerEvent('tx_garage:internalImpound', plate, Garage.GetCid(p))
end)

-- ─────────────────────────────────────────────────────────────────────
-- Favorite/pin
-- ─────────────────────────────────────────────────────────────────────

RegisterNetEvent('tx_garage:favoriteVehicle', function(plate, fav)
    local src = source
    if isOnCooldown(src, 'fav', 1) then return end
    local p = Garage.GetPlayer(src); if not p then return end

    plate = Utils.normalizePlate(plate); if not plate then return end
    if not isFullOwner(Garage.GetCid(p), plate) then return end

    MySQL.update.await(
        'UPDATE player_vehicles SET tx_garage_fav = ? WHERE plate = ?',
        { (fav and 1 or 0), plate }
    )
end)
