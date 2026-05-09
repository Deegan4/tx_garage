-- tx_garage — Garage UI open/store/retrieve

local nuiOpen = false

local function setNuiFocus(b)
    SetNuiFocus(b, b)
    nuiOpen = b
end

function OpenGarageUI(garageName)
    local vehicles = lib.callback.await('tx_garage:listVehicles', false, garageName) or {}
    local garage
    for _, g in ipairs(GetClientConfig().Garages) do if g.name == garageName then garage = g break end end
    if not garage then return end

    SendNUIMessage({
        action = 'openGarage',
        garage = garage,
        vehicles = vehicles,
        valet = GetClientConfig().Valet,
    })
    setNuiFocus(true)
end

RegisterNUICallback('garage/retrieve', function(data, cb)
    TriggerServerEvent('tx_garage:retrieveVehicle', data.garageName, data.plate)
    cb({ ok = true })
end)

RegisterNUICallback('garage/store', function(data, cb)
    -- Find player's current vehicle and serialize it
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then cb({ ok = false, error = 'not in vehicle' }) return end

    local plate = string.upper(string.gsub(GetVehicleNumberPlateText(veh), '%s+', ''))
    local props = lib.getVehicleProperties(veh)

    TriggerServerEvent('tx_garage:storeVehicle', data.garageName, plate, props)
    SetEntityAsMissionEntity(veh, true, true)
    DeleteVehicle(veh)
    cb({ ok = true })
end)

RegisterNUICallback('garage/transfer', function(data, cb)
    TriggerServerEvent('tx_garage:transferVehicle', data.plate, data.targetId)
    cb({ ok = true })
end)

RegisterNUICallback('garage/giveKey', function(data, cb)
    TriggerServerEvent('tx_garage:giveKey', data.plate, data.targetId)
    cb({ ok = true })
end)

RegisterNUICallback('garage/favorite', function(data, cb)
    TriggerServerEvent('tx_garage:favoriteVehicle', data.plate, data.fav)
    cb({ ok = true })
end)

RegisterNUICallback('ui/close', function(_, cb)
    setNuiFocus(false)
    cb({ ok = true })
end)

---Server tells us to spawn a vehicle (after retrieval validated).
RegisterNetEvent('tx_garage:spawnVehicle', function(spawn, model, plate, mods, fuel, engine, body)
    lib.requestModel(model, 5000)
    local veh = CreateVehicle(GetHashKey(model), spawn.x, spawn.y, spawn.z, spawn.w, true, false)
    SetVehicleNumberPlateText(veh, plate)
    SetVehicleEngineHealth(veh, engine or 1000.0)
    SetVehicleBodyHealth(veh, body or 1000.0)
    SetVehicleFuelLevel(veh, fuel or 100.0)

    if mods and type(mods) == 'string' then
        local ok, parsed = pcall(json.decode, mods)
        if ok and parsed then
            lib.setVehicleProperties(veh, parsed)
        end
    end

    SetPedIntoVehicle(PlayerPedId(), veh, -1)
    SetVehicleEngineOn(veh, true, true, false)
end)
