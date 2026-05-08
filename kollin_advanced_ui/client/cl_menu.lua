-- kollin_advanced_ui — Main menu (F9)

local menuOpen = false

local function setFocus(state)
    SetNuiFocus(state, state)
    menuOpen = state
end

function ToggleMenu()
    if menuOpen then
        setFocus(false)
        nuiSend('menu/close', {})
        return
    end

    -- Build server-side player info then open
    local info = lib.callback.await('kollin_ui:getPlayerInfo', false)
    if not info then return end

    -- Vehicle info (client-side — no sensitive data)
    local ped         = PlayerPedId()
    local veh         = GetVehiclePedIsIn(ped, false)
    local vehicleData = nil
    if veh ~= 0 then
        local model = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
        local plate = string.upper(string.gsub(GetVehicleNumberPlateText(veh), '%s+', ''))
        vehicleData = {
            model  = model,
            plate  = plate,
            engine = math.floor(GetVehicleEngineHealth(veh) / 10),
            body   = math.floor(GetVehicleBodyHealth(veh)   / 10),
            fuel   = math.floor(GetVehicleFuelLevel(veh)),
        }
    end

    nuiSend('menu/open', {
        player  = info,
        vehicle = vehicleData,
        emotes  = Config.Menu.emotes,
        settings = GetSettings(),
        animation = Config.Menu.animation,
    })
    setFocus(true)
end

-- Close from NUI (close button or Escape)
RegisterNUICallback('menu/close', function(_, cb)
    setFocus(false)
    cb({ ok = true })
end)

-- Emote triggered from menu
RegisterNUICallback('menu/emote', function(data, cb)
    setFocus(false)
    nuiSend('menu/close', {})
    if data and data.cmd then
        -- Small delay so menu closes cleanly before the animation fires
        SetTimeout(150, function()
            ExecuteCommand(data.cmd:gsub('^/', ''))
        end)
    end
    cb({ ok = true })
end)

-- Vehicle actions from menu
RegisterNUICallback('menu/vehicle', function(data, cb)
    if not data then cb({ ok = false }) return end

    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if data.action == 'engine' and veh ~= 0 then
        SetVehicleEngineOn(veh, not GetIsVehicleEngineRunning(veh), false, true)
    elseif data.action == 'lock' and veh ~= 0 then
        -- Delegate to keys resource if configured
        TriggerServerEvent('kollin_ui:vehicleLock', GetVehicleNumberPlateText(veh))
    elseif data.action == 'lights' and veh ~= 0 then
        local on = not AreLowBeamLightsOn(veh)
        SetVehicleLights(veh, on and 2 or 0)
    end
    cb({ ok = true })
end)
