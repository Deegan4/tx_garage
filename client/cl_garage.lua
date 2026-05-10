-- tx_garage v2.0 — Garage UI: open / store / retrieve / transfer / plate / sub-owners
-- ────────────────────────────────────────────────────────────────────────────
-- C5 fix: store/retrieve are now lib.callback round-trips. Vehicle entity is
-- only deleted AFTER the server confirms storage. If server rejects, the
-- vehicle stays intact.

local odometer = {}   -- plate → last-known position vec3 (for mileage tracking)
local odometerThread = nil

-- ─────────────────────────────────────────────────────────────────────
-- Mileage tracking (per-vehicle while driven)
-- ─────────────────────────────────────────────────────────────────────

local function startOdometerLoop()
    if odometerThread then return end
    odometerThread = true
    CreateThread(function()
        while true do
            Wait(2000)
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
                local plate = Utils.normalizePlate(GetVehicleNumberPlateText(veh))
                if plate then
                    local pos = GetEntityCoords(veh)
                    local last = odometer[plate]
                    if last then
                        local d = #(pos - last)
                        if d < 100.0 then  -- ignore teleports
                            odometer[plate] = pos
                            -- Accumulate in a sidecar field; flushed on store
                            odometer[plate.."_total"] = (odometer[plate.."_total"] or 0) + d
                        else
                            odometer[plate] = pos
                        end
                    else
                        odometer[plate] = pos
                    end
                end
            end
        end
    end)
end
startOdometerLoop()

-- ─────────────────────────────────────────────────────────────────────
-- Open garage UI
-- ─────────────────────────────────────────────────────────────────────

function OpenGarageUI(garageName)
    if IsNuiOpen() then return end
    local cfg = GetClientConfig(); if not cfg then return end

    local garage
    for _, g in ipairs(cfg.Garages) do
        if g.name == garageName then garage = g; break end
    end
    if not garage then return end

    local vehicles = lib.callback.await('tx_garage:listVehicles', false, garageName) or {}

    -- Enrich each vehicle with classifyModel for NUI gradient/icon
    for _, v in ipairs(vehicles) do
        v.modelClass = Utils.classifyModel(v.vehicle)
    end

    SendNUIMessage({
        action   = 'openGarage',
        garage   = garage,
        vehicles = vehicles,
        valet    = cfg.Valet,
        plateChange = cfg.PlateChange,
        subOwners   = cfg.SubOwners,
        transfer    = cfg.Transfer,
        currency    = cfg.Currency,
    })
    SetNuiOpen(true)
end

-- ─────────────────────────────────────────────────────────────────────
-- Retrieve (server returns spawn payload — client spawns it)
-- ─────────────────────────────────────────────────────────────────────

local function spawnVehicle(spawn, model, plate, modsJson, fuel, engine, body, fuelDeduction)
    if not lib.requestModel(model, 5000) then return nil end
    local hash = GetHashKey(model)
    local veh = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w or spawn.heading or 0.0, true, false)
    SetVehicleNumberPlateText(veh, plate)
    SetVehicleEngineHealth(veh, engine or 1000.0)
    SetVehicleBodyHealth(veh, body or 1000.0)

    local fuelLevel = fuel or 100.0
    if fuelDeduction and fuelDeduction > 0 then
        fuelLevel = math.max(0.0, fuelLevel - fuelDeduction)
    end

    -- Set fuel via configured resource
    if Config.Storage.fuelResource == 'ox_fuel' then
        Entity(veh).state.fuel = fuelLevel
    elseif Config.Storage.fuelResource == 'LegacyFuel' then
        local ok, _ = pcall(function() exports['LegacyFuel']:SetFuel(veh, fuelLevel) end)
        if not ok then SetVehicleFuelLevel(veh, fuelLevel) end
    else
        SetVehicleFuelLevel(veh, fuelLevel)
    end

    if modsJson and type(modsJson) == 'string' then
        local ok, parsed = pcall(json.decode, modsJson)
        if ok and parsed then
            local ok2, _ = pcall(lib.setVehicleProperties, veh, parsed)
            if not ok2 then Utils.dbg('mod restore failed:', plate) end
        end
    end

    SetPedIntoVehicle(PlayerPedId(), veh, -1)
    SetVehicleEngineOn(veh, true, true, false)
    SetModelAsNoLongerNeeded(hash)
    return veh
end

RegisterNUICallback('garage/retrieve', function(data, cb)
    local result, err = lib.callback.await('tx_garage:retrieveVehicle', false, data.garageName, data.plate)
    if not result then
        cb({ ok = false, error = err })
        return
    end

    spawnVehicle(result.spawn, result.model, result.plate,
                 result.mods, result.fuel, result.engine, result.body, 0)

    -- Initialize odometer for mileage tracking
    odometer[result.plate] = GetEntityCoords(GetVehiclePedIsIn(PlayerPedId(), false))
    odometer[result.plate.."_total"] = tonumber(result.mileage) or 0

    cb({ ok = true })
    SetNuiOpen(false)
    SendNUIMessage({ action = 'closeUI' })
end)

-- ─────────────────────────────────────────────────────────────────────
-- Store (C5 fix — only delete entity after server confirms)
-- ─────────────────────────────────────────────────────────────────────

RegisterNUICallback('garage/store', function(data, cb)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then
        notify and notify(Locale('error.not_in_vehicle'), 'error')
        cb({ ok = false, error = 'not_driver' })
        return
    end

    local plate = Utils.normalizePlate(GetVehicleNumberPlateText(veh))
    if not plate then cb({ ok = false, error = 'bad_plate' }); return end

    local props = lib.getVehicleProperties(veh)
    -- Read fuel from configured resource
    local fuel
    if Config.Storage.fuelResource == 'ox_fuel' then
        fuel = Entity(veh).state.fuel or 100
    elseif Config.Storage.fuelResource == 'LegacyFuel' then
        local ok, val = pcall(function() return exports['LegacyFuel']:GetFuel(veh) end)
        fuel = ok and val or GetVehicleFuelLevel(veh)
    else
        fuel = GetVehicleFuelLevel(veh)
    end

    local ok, err = lib.callback.await('tx_garage:storeVehicle', false, data.garageName, plate, {
        mods    = props,
        fuel    = fuel,
        engine  = GetVehicleEngineHealth(veh),
        body    = GetVehicleBodyHealth(veh),
        mileage = math.floor(odometer[plate.."_total"] or 0),
    })
    if not ok then cb({ ok = false, error = err }); return end

    -- C5 fix: only NOW do we delete
    SetEntityAsMissionEntity(veh, true, true)
    DeleteVehicle(veh)
    odometer[plate] = nil
    odometer[plate.."_total"] = nil
    cb({ ok = true })
    SetNuiOpen(false)
    SendNUIMessage({ action = 'closeUI' })
end)

-- ─────────────────────────────────────────────────────────────────────
-- Transfer (uses lib.inputDialog instead of browser prompt)
-- ─────────────────────────────────────────────────────────────────────

RegisterNUICallback('garage/transfer', function(data, cb)
    cb({ ok = true })
    SetNuiOpen(false)

    local input = lib.inputDialog(Locale('ui.garage.transfer'), {
        { type = 'number', label = 'Target Player Server ID', required = true, min = 1 },
        { type = 'number', label = 'Sale Price', default = 0, min = 0, step = 100 },
    })
    if not input then SetNuiOpen(true); return end

    TriggerServerEvent('tx_garage:transferRequest', data.plate, input[1], input[2] or 0)
end)

-- ─────────────────────────────────────────────────────────────────────
-- Give Key (proximity-gated server-side)
-- ─────────────────────────────────────────────────────────────────────

RegisterNUICallback('garage/giveKey', function(data, cb)
    cb({ ok = true })
    SetNuiOpen(false)

    local input = lib.inputDialog(Locale('ui.garage.givekey'), {
        { type = 'number', label = 'Target Player Server ID', required = true, min = 1 },
    })
    if not input then SetNuiOpen(true); return end

    TriggerServerEvent('tx_garage:giveKey', data.plate, input[1])
end)

-- ─────────────────────────────────────────────────────────────────────
-- Favorite/pin
-- ─────────────────────────────────────────────────────────────────────

RegisterNUICallback('garage/favorite', function(data, cb)
    TriggerServerEvent('tx_garage:favoriteVehicle', data.plate, data.fav)
    cb({ ok = true })
end)

-- ─────────────────────────────────────────────────────────────────────
-- Plate change
-- ─────────────────────────────────────────────────────────────────────

RegisterNUICallback('garage/changePlate', function(data, cb)
    cb({ ok = true })
    local cfg = GetClientConfig().PlateChange
    if not cfg or not cfg.enabled then return end
    SetNuiOpen(false)

    local input = lib.inputDialog(Locale('ui.garage.changeplate'), {
        {
            type = 'input', label = 'New Plate',
            description = ('%d-%d chars, A-Z 0-9. Cost: %s'):format(
                cfg.minLen, cfg.maxLen,
                Utils.formatMoney(cfg.cost)
            ),
            required = true, min = cfg.minLen, max = cfg.maxLen,
        },
    })
    if not input then SetNuiOpen(true); return end

    TriggerServerEvent('tx_garage:changePlate', data.plate, input[1])
end)

-- ─────────────────────────────────────────────────────────────────────
-- Sub-owners
-- ─────────────────────────────────────────────────────────────────────

RegisterNUICallback('garage/subOwners/list', function(data, cb)
    local list = lib.callback.await('tx_garage:getSubOwners', false, data.plate) or {}
    cb({ ok = true, list = list })
end)

RegisterNUICallback('garage/subOwners/add', function(data, cb)
    cb({ ok = true })
    SetNuiOpen(false)

    local input = lib.inputDialog(Locale('ui.garage.subowners'), {
        { type = 'number', label = 'Target Player Server ID', required = true, min = 1 },
    })
    if not input then SetNuiOpen(true); return end

    TriggerServerEvent('tx_garage:addSubOwner', data.plate, input[1])
end)

RegisterNUICallback('garage/subOwners/remove', function(data, cb)
    TriggerServerEvent('tx_garage:removeSubOwner', data.plate, data.targetCid)
    cb({ ok = true })
end)

-- ─────────────────────────────────────────────────────────────────────
-- Boss menu (deposit/withdraw)
-- ─────────────────────────────────────────────────────────────────────

RegisterNUICallback('garage/boss/balance', function(data, cb)
    local bal = lib.callback.await('tx_garage:getSocietyBalance', false, data.society) or 0
    cb({ ok = true, balance = bal })
end)

RegisterNUICallback('garage/boss/deposit', function(data, cb)
    cb({ ok = true })
    local input = lib.inputDialog(Locale('boss.deposit'), {
        { type = 'number', label = 'Amount', required = true, min = 1 },
    })
    if input then TriggerServerEvent('tx_garage:bossDeposit', input[1]) end
end)

RegisterNUICallback('garage/boss/withdraw', function(data, cb)
    cb({ ok = true })
    local input = lib.inputDialog(Locale('boss.withdraw'), {
        { type = 'number', label = 'Amount', required = true, min = 1 },
    })
    if input then TriggerServerEvent('tx_garage:bossWithdraw', input[1]) end
end)

-- ─────────────────────────────────────────────────────────────────────
-- UI close
-- ─────────────────────────────────────────────────────────────────────

RegisterNUICallback('ui/close', function(_, cb)
    SetNuiOpen(false)
    cb({ ok = true })
end)

-- ─────────────────────────────────────────────────────────────────────
-- Police impound (called by tow/impound resources)
-- ─────────────────────────────────────────────────────────────────────

exports('PoliceImpound', function(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if not netId or netId == 0 then return end
    TriggerServerEvent('tx_garage:policeImpound', netId)
end)

-- Server tells everyone to delete a vehicle (after police impound)
RegisterNetEvent('tx_garage:deleteVehicle', function(netId)
    if NetworkDoesEntityExistWithNetworkId(netId) then
        local ent = NetworkGetEntityFromNetworkId(netId)
        if DoesEntityExist(ent) and NetworkHasControlOfEntity(ent) then
            SetEntityAsMissionEntity(ent, true, true)
            DeleteVehicle(ent)
        end
    end
end)
