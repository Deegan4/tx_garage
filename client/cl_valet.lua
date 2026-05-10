-- tx_garage v2.0 — Valet client behavior
-- ────────────────────────────────────────────────────────────────────────────
-- Anti-stuck logic: try the player's location, then fallback offsets. If all
-- fail, tell the server (via valetPathFailed) to refund the player.

RegisterNUICallback('garage/valet', function(data, cb)
    cb({ ok = true })
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    TriggerServerEvent('tx_garage:requestValet', data.garageName, {
        x = coords.x, y = coords.y, z = coords.z,
    })
    SetNuiOpen(false)
    SendNUIMessage({ action = 'closeUI' })
end)

RegisterNUICallback('valet/cancel', function(_, cb)
    TriggerServerEvent('tx_garage:cancelValet')
    cb({ ok = true })
end)

-- ─────────────────────────────────────────────────────────────────────
-- Anti-stuck path resolver — tries the closest road node to the player,
-- then each fallback offset until one resolves.
-- ─────────────────────────────────────────────────────────────────────

local function findValetSpawn(px, py, pz)
    -- 1. Try a point ~25m N/E of the player
    local primary = vec3(px + 25.0, py + 25.0, pz)
    local sx, sy, sz, sh = GetClosestVehicleNodeWithHeading(primary.x, primary.y, primary.z, 0, 3.0, 0)
    if sx ~= 0.0 and sy ~= 0.0 then
        return vec4(sx, sy, sz, sh), 'primary'
    end

    -- 2. Walk through configured fallback offsets
    local fallbacks = (GetClientConfig().Valet and GetClientConfig().Valet.fallbackOffsets)
        or {
            vec3( 25.0,  25.0, 0.0),
            vec3(-25.0,  25.0, 0.0),
            vec3( 25.0, -25.0, 0.0),
            vec3(-25.0, -25.0, 0.0),
        }
    for _, off in ipairs(fallbacks) do
        local fx, fy, fz, fh = GetClosestVehicleNodeWithHeading(px + off.x, py + off.y, pz, 0, 3.0, 0)
        if fx ~= 0.0 and fy ~= 0.0 then
            return vec4(fx, fy, fz, fh), 'fallback'
        end
    end

    return nil, 'no_path'
end

-- ─────────────────────────────────────────────────────────────────────
-- Server signals delivery — spawn the vehicle with a valet NPC, drive to player
-- ─────────────────────────────────────────────────────────────────────

RegisterNetEvent('tx_garage:valetDeliver', function(plate, model, fromCoords, fuelDeduction)
    local px, py, pz = fromCoords.x, fromCoords.y, fromCoords.z

    local spawn, tag = findValetSpawn(px, py, pz)
    if not spawn then
        TriggerServerEvent('tx_garage:valetPathFailed')
        return
    end

    if not lib.requestModel(model, 5000) then
        TriggerServerEvent('tx_garage:valetPathFailed')
        return
    end

    local hash = GetHashKey(model)
    local veh = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w or 0.0, true, false)
    SetVehicleNumberPlateText(veh, plate)
    SetVehicleEngineOn(veh, true, true, false)
    SetModelAsNoLongerNeeded(hash)

    -- Apply fuel deduction (premium feel — valet charged you for the trip)
    if fuelDeduction and fuelDeduction > 0 then
        local current = GetVehicleFuelLevel(veh)
        local newLevel = math.max(0.0, current - fuelDeduction)
        if Config.Storage.fuelResource == 'ox_fuel' then
            Entity(veh).state.fuel = newLevel
        else
            SetVehicleFuelLevel(veh, newLevel)
        end
    end

    -- Spawn the valet NPC behind the wheel
    local valetPed = (GetClientConfig().Valet and GetClientConfig().Valet.valetPed) or 'a_m_y_business_03'
    if not lib.requestModel(valetPed, 5000) then
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
        TriggerServerEvent('tx_garage:valetPathFailed')
        return
    end
    local pedHash = GetHashKey(valetPed)
    local npc = CreatePedInsideVehicle(veh, 4, pedHash, -1, true, false)
    SetBlockingOfNonTemporaryEvents(npc, true)
    SetDriverAbility(npc, 1.0)
    SetDriverAggressiveness(npc, 0.0)
    SetModelAsNoLongerNeeded(pedHash)

    -- Drive to player
    -- Flags: 786603 = normal driving (avoid traffic, stop at lights, etc.)
    TaskVehicleDriveToCoordLongrange(npc, veh, px, py, pz, 12.0, 786603, 5.0)

    -- Watch for arrival
    CreateThread(function()
        local timeout = 0
        while DoesEntityExist(veh) and DoesEntityExist(npc) and timeout < 180 do
            local d = #(GetEntityCoords(veh) - vector3(px, py, pz))
            if d < 6.0 then
                ClearPedTasks(npc)
                TaskLeaveVehicle(npc, veh, 0)
                Wait(2500)
                TaskWanderStandard(npc, 10.0, 10)
                SetEntityAsNoLongerNeeded(npc)
                return
            end
            Wait(1000)
            timeout = timeout + 1
        end
        -- Stuck — clean up valet npc, leave the vehicle
        if DoesEntityExist(npc) then
            ClearPedTasks(npc)
            TaskLeaveVehicle(npc, veh, 0)
            SetEntityAsNoLongerNeeded(npc)
        end
    end)
end)
