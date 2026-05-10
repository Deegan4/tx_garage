-- tx_garage v2.0 — Admin client handlers
-- ────────────────────────────────────────────────────────────────────────────
-- Server commands (sv_admin.lua) trigger these client events to do entity work.
-- Server has already validated ACE permission.

RegisterNetEvent('tx_garage:adminSpawnVehicle', function(model)
    if not lib.requestModel(model, 5000) then
        notify and notify(Locale('admin.not_found'), 'error'); return
    end
    local hash = GetHashKey(model)
    local ped  = PlayerPedId()
    local pos  = GetEntityCoords(ped)
    local h    = GetEntityHeading(ped)
    -- Spawn ahead of player
    local fwd = GetEntityForwardVector(ped)
    local sp  = pos + fwd * 4.0
    local veh = CreateVehicle(hash, sp.x, sp.y, sp.z, h, true, false)
    SetVehicleNumberPlateText(veh, 'ADMIN')
    SetPedIntoVehicle(ped, veh, -1)
    SetVehicleEngineOn(veh, true, true, false)
    SetEntityAsNoLongerNeeded(veh)
    SetModelAsNoLongerNeeded(hash)
end)

RegisterNetEvent('tx_garage:adminDeleteCurrent', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        -- If not in a vehicle, delete the one being aimed at
        local hit, ent = GetEntityPlayerIsFreeAimingAt(PlayerId())
        if hit and ent and ent ~= 0 and IsEntityAVehicle(ent) then
            veh = ent
        end
    end
    if veh == 0 or not DoesEntityExist(veh) then
        notify and notify(Locale('admin.not_found'), 'error'); return
    end
    SetEntityAsMissionEntity(veh, true, true)
    DeleteVehicle(veh)
    notify and notify(Locale('admin.deleted'), 'success')
end)

RegisterNetEvent('tx_garage:adminTeleportToPlate', function(plate)
    -- Search nearby vehicles for a plate match
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local found
    -- Iterate active vehicles
    local handle, veh = FindFirstVehicle()
    local ok = handle ~= -1
    if ok then
        repeat
            local p = Utils.normalizePlate(GetVehicleNumberPlateText(veh))
            if p == plate then
                found = veh; break
            end
            ok, veh = FindNextVehicle(handle)
        until not ok
        EndFindVehicle(handle)
    end

    if not found or not DoesEntityExist(found) then
        notify and notify(Locale('admin.not_found'), 'error'); return
    end

    local target = GetEntityCoords(found)
    SetEntityCoords(ped, target.x + 2.0, target.y, target.z, false, false, false, true)
    notify and notify(Locale('admin.tp_done'), 'success')
end)
