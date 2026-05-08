-- kollin_advanced_ui — Speedometer (vehicle only)

local inVehicle    = false
local seatbeltOn   = false
local speedoVisible = true

-- Toggle seatbelt with key (B by default — matches QBCore)
RegisterCommand('kollin_seatbelt', function()
    if not inVehicle then return end
    seatbeltOn = not seatbeltOn
    nuiSend('speedo/seatbelt', { on = seatbeltOn })
    Notify(seatbeltOn and 'Seatbelt fastened.' or 'Seatbelt removed.', 'inform')
end, false)

RegisterKeyMapping('kollin_seatbelt', 'Toggle seatbelt', 'keyboard', 'B')

local function mpsToUnit(mps, unit)
    if unit == 'kph' then return mps * 3.6 end
    return mps * 2.23694  -- mph
end

local function getFuelLevel(veh)
    -- Support LegacyFuel, ox_fuel, ps-fuel, or native
    local fuelRes = Config.Storage and Config.Storage.fuelResource
    if fuelRes == 'LegacyFuel' then
        local ok, lvl = pcall(function() return exports['LegacyFuel']:GetFuel(veh) end)
        if ok and lvl then return lvl end
    elseif fuelRes == 'ox_fuel' then
        local ok, lvl = pcall(function() return exports.ox_fuel:GetFuel(veh) end)
        if ok and lvl then return lvl end
    end
    return GetVehicleFuelLevel(veh)
end

CreateThread(function()
    while true do
        local interval = Config.Speedometer.updateInterval or 100
        Wait(interval)

        if not Config.Speedometer.enabled or not speedoVisible then
            if inVehicle then
                inVehicle = false
                nuiSend('speedo/hide', {})
            end
            goto continue
        end

        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if veh == 0 then
            if inVehicle then
                inVehicle  = false
                seatbeltOn = false
                nuiSend('speedo/hide', {})
            end
            goto continue
        end

        -- First frame in vehicle
        if not inVehicle then
            inVehicle = true
            nuiSend('speedo/show', {})
        end

        local settings   = GetSettings() or {}
        local unit       = settings.speedUnit or Config.Speedometer.unit
        local speedRaw   = GetEntitySpeed(veh)
        local speed      = math.floor(mpsToUnit(speedRaw, unit))
        local rpm        = GetVehicleCurrentRpm(veh)
        local gear       = GetVehicleCurrentGear(veh)
        local maxGear    = GetVehicleHighGear(veh)
        local fuel       = math.floor(getFuelLevel(veh))
        local engineHP   = math.floor(GetVehicleEngineHealth(veh) / 10)   -- 0-100
        local bodyHP     = math.floor(GetVehicleBodyHealth(veh)   / 10)

        -- Headlights on / siren
        local lights = AreLowBeamLightsOn(veh)
        local siren  = IsVehicleSirenOn(veh)

        nuiSend('speedo/update', {
            speed    = speed,
            unit     = unit:upper(),
            rpm      = rpm,
            gear     = gear,
            maxGear  = maxGear,
            fuel     = fuel,
            engine   = math.max(0, math.min(100, engineHP)),
            body     = math.max(0, math.min(100, bodyHP)),
            seatbelt = seatbeltOn,
            lights   = lights,
            siren    = siren,
        })

        ::continue::
    end
end)

exports('SetSpeedoVisible', function(v)
    speedoVisible = v
    if not v then nuiSend('speedo/hide', {}) end
end)
