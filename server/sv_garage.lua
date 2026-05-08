-- tx_garage — Core garage logic (store / retrieve / transfer / give key)

local cooldowns = {}

local function isOnCooldown(src, key, seconds)
    return Utils.isOnCooldown(cooldowns, src, key, seconds)
end

AddEventHandler('playerDropped', function() cooldowns[source] = nil end)

---Find the garage config by name.
local function findGarage(name)
    for _, g in ipairs(Config.Garages) do
        if g.name == name then return g end
    end
    return nil
end

---List vehicles a player can retrieve from a given garage.
local function listVehiclesForGarage(identifier, garage)
    local isEsx = Config.Framework == 'esx'

    if garage.type == 'impound' then
        local sql = isEsx
            and [[SELECT plate,vehicle,mods,fuel,engine,body,tx_garage_state AS state,tx_garage_impounded_at AS impounded_at FROM player_vehicles WHERE owner=? AND tx_garage_state='impound']]
            or  [[SELECT plate,vehicle,mods,fuel,engine,body,tx_garage_state AS state,tx_garage_impounded_at AS impounded_at FROM player_vehicles WHERE citizenid=? AND tx_garage_state='impound']]
        return MySQL.query.await(sql, { identifier })
    end

    local sql = isEsx
        and [[SELECT plate,vehicle,mods,fuel,engine,body,tx_garage_name AS at_garage,tx_garage_state AS state FROM player_vehicles WHERE owner=? AND tx_garage_state='stored' AND (tx_garage_name=? OR tx_garage_name IS NULL)]]
        or  [[SELECT plate,vehicle,mods,fuel,engine,body,tx_garage_name AS at_garage,tx_garage_state AS state FROM player_vehicles WHERE citizenid=? AND tx_garage_state='stored' AND (tx_garage_name=? OR tx_garage_name IS NULL)]]
    return MySQL.query.await(sql, { identifier, garage.name })
end

lib.callback.register('tx_garage:listVehicles', function(src, garageName)
    local p = Bridge.GetPlayer(src)
    if not p then return {} end

    local garage = findGarage(garageName)
    if not garage then return {} end

    -- Permission gate for job/gang garages
    if garage.type == 'job' and garage.jobs and not Bridge.HasJob(p, garage.jobs) then
        return {}
    end
    if garage.type == 'gang' and garage.gangs then
        local g = Bridge.GetGang(p)
        local ok = false
        for _, gg in ipairs(garage.gangs) do if gg == g then ok = true break end end
        if not ok then return {} end
    end

    local id = Bridge.GetIdentifier(p)
    return listVehiclesForGarage(id, garage)
end)

RegisterNetEvent('tx_garage:retrieveVehicle', function(garageName, plate)
    local src = source
    if isOnCooldown(src, 'retrieve', 3) then return end

    local p = Bridge.GetPlayer(src)
    if not p then return end

    local garage = findGarage(garageName)
    if not garage then return end

    local id = Bridge.GetIdentifier(p)
    local isEsx = Config.Framework == 'esx'

    -- Verify ownership and state
    local ownerSql = isEsx
        and [[SELECT vehicle,mods,fuel,engine,body,tx_garage_state AS state,tx_garage_impounded_at AS impounded_at FROM player_vehicles WHERE owner=? AND plate=? LIMIT 1]]
        or  [[SELECT vehicle,mods,fuel,engine,body,tx_garage_state AS state,tx_garage_impounded_at AS impounded_at FROM player_vehicles WHERE citizenid=? AND plate=? LIMIT 1]]
    local row = MySQL.query.await(ownerSql, { id, plate })

    if not row or not row[1] then
        Bridge.Notify(src, Locale('error.not_owner'), 'error')
        return
    end
    local v = row[1]

    -- Impound retrieval costs money
    if garage.type == 'impound' then
        local days = 1
        if v.impounded_at then
            local ts = MySQL.scalar.await('SELECT TIMESTAMPDIFF(DAY, ?, NOW())', { v.impounded_at }) or 0
            days = math.max(1, ts)
        end
        local cost = Config.Impound.baseCost + (days * Config.Impound.perDayCost)
        if not Bridge.RemoveMoney(src, Config.Impound.paymentAccount, cost) then
            Bridge.Notify(src, Locale('error.no_money'), 'error')
            return
        end
        Bridge.Notify(src, Locale('success.payment', Utils.formatMoney(cost)), 'success')
    elseif garage.type == 'private' and Config.GarageTypes.private.cost > 0 then
        -- Weekly rental — simplified: charge once per retrieve
        Bridge.RemoveMoney(src, 'bank', Config.GarageTypes.private.cost)
    end

    -- Mark vehicle out
    MySQL.update.await([[
        UPDATE player_vehicles
        SET tx_garage_state = 'out', tx_garage_name = NULL, tx_garage_impounded_at = NULL
        WHERE plate = ?
    ]], { plate })

    TriggerClientEvent('tx_garage:spawnVehicle', src, garage.spawn, v.vehicle, plate, v.mods, v.fuel, v.engine, v.body)
    TriggerEvent('qb-vehiclekeys:server:GiveKeys', src, plate)
    Bridge.Notify(src, Locale('success.vehicle_taken'), 'success')
end)

RegisterNetEvent('tx_garage:storeVehicle', function(garageName, plate, props)
    local src = source
    if isOnCooldown(src, 'store', 2) then return end

    local p = Bridge.GetPlayer(src)
    if not p then return end

    local garage = findGarage(garageName)
    if not garage or not Config.GarageTypes[garage.type].canStore then return end

    local id = Bridge.GetIdentifier(p)
    local isEsx = Config.Framework == 'esx'

    -- Validate ownership
    local ownSql = isEsx
        and 'SELECT 1 FROM player_vehicles WHERE owner=? AND plate=? LIMIT 1'
        or  'SELECT 1 FROM player_vehicles WHERE citizenid=? AND plate=? LIMIT 1'
    local owns = MySQL.scalar.await(ownSql, { id, plate })
    if not owns then
        Bridge.Notify(src, Locale('error.not_owner'), 'error')
        return
    end

    -- Save vehicle state
    MySQL.update.await([[
        UPDATE player_vehicles
        SET tx_garage_state = 'stored', tx_garage_name = ?,
            mods = ?, fuel = ?, engine = ?, body = ?
        WHERE plate = ?
    ]], {
        garage.name,
        json.encode(props.mods or {}),
        props.fuel or 100,
        props.engine or 1000,
        props.body or 1000,
        plate,
    })

    TriggerEvent('qb-vehiclekeys:server:RemoveKeys', src, plate)
    Bridge.Notify(src, Locale('success.vehicle_stored'), 'success')
end)

-- Transfer ownership to another player (server-ID only — never accept raw identifiers from client)
RegisterNetEvent('tx_garage:transferVehicle', function(plate, targetServerId)
    local src = source
    if isOnCooldown(src, 'transfer', 5) then return end

    local p = Bridge.GetPlayer(src)
    if not p then return end

    -- Reject non-numeric input; never trust a raw identifier string from the client
    if not tonumber(targetServerId) then
        Bridge.Notify(src, Locale('error.no_permission'), 'error')
        return
    end

    local target = Bridge.GetPlayer(tonumber(targetServerId))
    if not target then return end

    local id       = Bridge.GetIdentifier(p)
    local targetId = Bridge.GetIdentifier(target)
    local isEsx    = Config.Framework == 'esx'

    -- Verify caller owns the vehicle
    local ownSql = isEsx
        and 'SELECT 1 FROM player_vehicles WHERE owner=? AND plate=? LIMIT 1'
        or  'SELECT 1 FROM player_vehicles WHERE citizenid=? AND plate=? LIMIT 1'
    if not MySQL.scalar.await(ownSql, { id, plate }) then
        Bridge.Notify(src, Locale('error.not_owner'), 'error')
        return
    end

    local updSql = isEsx
        and 'UPDATE player_vehicles SET owner=? WHERE plate=?'
        or  'UPDATE player_vehicles SET citizenid=? WHERE plate=?'
    MySQL.update.await(updSql, { targetId, plate })
    Bridge.Notify(src, Locale('success.vehicle_stored'), 'success')
end)

-- Police-only impound (drops a vehicle into impound).
--
-- Security model: the caller MUST be a job-matched, grade-qualified player
-- physically near the vehicle they are impounding. The vehicleNetId proves
-- the vehicle exists in the world (it has a network entity); we read its
-- plate server-side rather than trusting the client. The cop's server-tracked
-- ped coords are compared against the vehicle's coords (Config.PoliceImpound.radius).
--
-- Calling resources (tow-truck scripts, /impound commands) should pass the
-- vehicle's NetworkGetNetworkIdFromEntity(veh) as `vehicleNetId`.
RegisterNetEvent('tx_garage:policeImpound', function(vehicleNetId)
    local src = source
    if isOnCooldown(src, 'policeImpound', 3) then return end

    local p = Bridge.GetPlayer(src)
    if not p then return end

    -- 1. Job + grade gate
    if not Bridge.HasJob(p, Config.PoliceImpound.jobs) then
        Bridge.Notify(src, Locale('error.no_permission'), 'error')
        return
    end
    if Bridge.GetJobGrade(p) < (Config.PoliceImpound.minGrade or 0) then
        Bridge.Notify(src, Locale('error.no_permission'), 'error')
        return
    end

    -- 2. Resolve the vehicle entity from its network ID
    if type(vehicleNetId) ~= 'number' or vehicleNetId <= 0 then return end
    local veh = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then
        Bridge.Notify(src, Locale('error.not_owner'), 'error')
        return
    end

    -- 3. Read plate from the actual entity (not from client)
    local plate = GetVehicleNumberPlateText(veh)
    if not plate then return end
    plate = plate:gsub('%s+$', '')  -- vehicle plates are right-padded with spaces

    -- 4. Validate plate is in player_vehicles (no impounding NPC/spawned vehicles)
    local known = MySQL.scalar.await(
        'SELECT 1 FROM player_vehicles WHERE plate = ? LIMIT 1', { plate }
    )
    if not known then
        Bridge.Notify(src, Locale('error.not_owner'), 'error')
        return
    end

    -- 5. Proximity gate: cop's ped must be within radius of the vehicle
    local copPed = GetPlayerPed(src)
    if not copPed or copPed == 0 then return end
    local cx, cy, cz = table.unpack(GetEntityCoords(copPed))
    local vx, vy, vz = table.unpack(GetEntityCoords(veh))
    local dx, dy, dz = cx - vx, cy - vy, cz - vz
    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
    if distance > (Config.PoliceImpound.radius or 5.0) then
        Bridge.Notify(src, Locale('error.no_permission'), 'error')
        return
    end

    -- 6. All checks passed — impound
    MySQL.update.await([[
        UPDATE player_vehicles
        SET tx_garage_state = 'impound', tx_garage_impounded_at = NOW(), tx_garage_name = 'mrpd_impound'
        WHERE plate = ?
    ]], { plate })

    Bridge.Notify(src, Locale('success.vehicle_stored'), 'success')
end)
