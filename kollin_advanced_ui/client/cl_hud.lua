-- kollin_advanced_ui — HUD tick (status bars, money, location, time)

local hudVisible = true

-- Throttle: send NUI update only when a value changed by more than epsilon.
local lastHUD = {}
local function changed(key, val, epsilon)
    epsilon = epsilon or 1
    if not lastHUD[key] then lastHUD[key] = -999 end
    if math.abs(lastHUD[key] - val) >= epsilon then
        lastHUD[key] = val
        return true
    end
    return false
end

local function getMetadata(key, default)
    -- QBCore/QBox expose metadata on LocalPlayer.state
    local ok, val = pcall(function()
        return LocalPlayer.state[key]
    end)
    if ok and val ~= nil then return val end

    -- ESX/standalone fallback: use statebag or return default
    return default
end

local function getHUDData()
    local ped    = PlayerPedId()
    local health = math.max(0, math.floor((GetEntityHealth(ped) - 100) / 100 * 100))
    local armor  = math.floor(GetPedArmour(ped))

    -- Metadata (hunger/thirst/stress come from framework statebags)
    local hunger  = math.floor(getMetadata('hunger',  100))
    local thirst  = math.floor(getMetadata('thirst',  100))
    local stamina = math.floor(GetPlayerStamina(PlayerId()))
    local stress  = math.floor(getMetadata('stress',  0))
    local oxygen  = math.floor(getMetadata('oxygen',  100))

    -- Wanted
    local wanted = GetPlayerWantedLevel(PlayerId())

    -- Street name
    local streetHash, crossingHash = GetStreetNameAtCoord(
        GetEntityCoords(ped))
    local street   = GetStreetNameFromHashKey(streetHash)
    local crossing = crossingHash ~= 0 and GetStreetNameFromHashKey(crossingHash) or nil
    local zone     = GetNameOfZone(GetEntityCoords(ped))

    -- Game clock
    local hours   = GetClockHours()
    local minutes = GetClockMinutes()
    local timeStr = ('%02d:%02d'):format(hours, minutes)

    return {
        health = health, armor   = armor,  hunger = hunger,
        thirst = thirst, stamina = stamina, stress = stress,
        oxygen = oxygen, wanted  = wanted,
        street = street, crossing = crossing, zone = zone,
        time   = timeStr,
    }
end

-- Money update — triggered on framework events, not every tick.
local function sendMoneyUpdate(cash, bank)
    nuiSend('hud/money', { cash = cash, bank = bank })
end

-- QBCore money events
AddEventHandler('QBCore:Player:SetPlayerData', function(data)
    if data and data.money then
        sendMoneyUpdate(data.money.cash or 0, data.money.bank or 0)
    end
end)

-- ESX money events
AddEventHandler('esx:setPlayerData', function(key, val)
    if key == 'accounts' and val then
        local cash, bank = 0, 0
        for _, acc in ipairs(val) do
            if acc.name == 'money' then cash = acc.money or 0 end
            if acc.name == 'bank'  then bank = acc.money or 0 end
        end
        sendMoneyUpdate(cash, bank)
    end
end)

-- ── HUD tick ─────────────────────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(Config.HUD.updateInterval or 250)

        if not Config.HUD.enabled or not hudVisible then goto continue end
        if not IsPlayerLoaded() then goto continue end

        local d = getHUDData()
        nuiSend('hud/update', d)

        ::continue::
    end
end)

-- ── Exports ──────────────────────────────────────────────────────────
exports('SetHUDVisible', function(visible)
    hudVisible = visible
    nuiSend('hud/visible', { visible = visible })
end)

exports('GetHUDVisible', function() return hudVisible end)
