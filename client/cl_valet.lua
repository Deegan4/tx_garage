-- tx_garage — Valet client behavior
-- When server tells us "valet delivered", spawn the vehicle near the player with a valet ped driving it.

-- NOTE: NUI posts `garage/valet` with { garageName }. The server resolves the
-- caller's most-recently-stored vehicle in that garage and dispatches the valet.
-- We never accept a client-supplied plate here — server picks the vehicle.
RegisterNUICallback('garage/valet', function(data, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    TriggerServerEvent('tx_garage:requestValet', data.garageName, { x = coords.x, y = coords.y, z = coords.z })
    cb({ ok = true })
end)

RegisterNUICallback('valet/cancel', function(_, cb)
    TriggerServerEvent('tx_garage:cancelValet')
    cb({ ok = true })
end)

RegisterNetEvent('tx_garage:valetDeliver', function(plate, model, fromCoords)
    -- Spawn the vehicle nearby with a valet NPC at the wheel
    local px, py, pz = fromCoords.x, fromCoords.y, fromCoords.z
    -- Pick a streetside point ~30m from the player
    local sx, sy, sz, sh = GetClosestVehicleNodeWithHeading(px + 25.0, py + 25.0, pz, 0, 3.0, 0)
    if sx == 0.0 then sx, sy, sz, sh = px + 10.0, py, pz, 0.0 end

    lib.requestModel(model, 5000)
    local veh = CreateVehicle(GetHashKey(model), sx, sy, sz, sh, true, false)
    SetVehicleNumberPlateText(veh, plate)
    SetVehicleEngineOn(veh, true, true, false)

    local valetPed = GetClientConfig().Valet.valetPed or 'a_m_y_business_03'
    lib.requestModel(valetPed, 5000)
    local npc = CreatePedInsideVehicle(veh, 4, GetHashKey(valetPed), -1, true, false)
    SetBlockingOfNonTemporaryEvents(npc, true)
    SetDriverAbility(npc, 1.0)

    -- Drive to player
    TaskVehicleDriveToCoordLongrange(npc, veh, px, py, pz, 12.0, 786603, 5.0)

    -- Watch for arrival
    CreateThread(function()
        while DoesEntityExist(veh) and DoesEntityExist(npc) do
            local d = #(GetEntityCoords(veh) - vector3(px, py, pz))
            if d < 6.0 then
                ClearPedTasks(npc)
                TaskLeaveVehicle(npc, veh, 0)
                Wait(2000)
                TaskWanderStandard(npc, 10.0, 10)
                SetEntityAsNoLongerNeeded(npc)
                break
            end
            Wait(1000)
        end
    end)
end)
