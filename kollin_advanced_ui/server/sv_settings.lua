-- kollin_advanced_ui — Player settings persistence

local defaultSettings = {
    theme       = Config.DefaultTheme,
    scale       = Config.DefaultScale,
    speedUnit   = Config.Speedometer.unit,
    notifPos    = Config.Notifications.position,
    hud         = {
        bars = {
            health  = true,
            armor   = true,
            hunger  = true,
            thirst  = true,
            stamina = true,
            stress  = false,
            oxygen  = false,
        },
        showMoney    = Config.HUD.showMoney,
        showLocation = Config.HUD.showLocation,
        showTime     = Config.HUD.showTime,
    },
    speedo = {
        enabled          = Config.Speedometer.enabled,
        showFuel         = Config.Speedometer.showFuel,
        showRPM          = Config.Speedometer.showRPM,
        showGear         = Config.Speedometer.showGear,
        showSeatbelt     = Config.Speedometer.showSeatbelt,
        showEngineHealth = Config.Speedometer.showEngineHealth,
        showBodyHealth   = Config.Speedometer.showBodyHealth,
    },
}

lib.callback.register('kollin_ui:loadSettings', function(src)
    if not Config.SaveSettings then return defaultSettings end

    local p = Bridge.GetPlayer(src)
    if not p then return defaultSettings end
    local id = Bridge.GetIdentifier(p)
    if not id then return defaultSettings end

    local row = MySQL.scalar.await(
        'SELECT settings FROM kollin_ui_settings WHERE citizenid = ? LIMIT 1',
        { id }
    )

    if row then
        local ok, parsed = pcall(json.decode, row)
        if ok and parsed then
            -- Deep-merge persisted over defaults so new keys get defaults
            for k, v in pairs(defaultSettings) do
                if parsed[k] == nil then parsed[k] = v end
            end
            return parsed
        end
    end

    -- First time — insert defaults
    MySQL.insert(
        'INSERT IGNORE INTO kollin_ui_settings (citizenid, settings) VALUES (?, ?)',
        { id, json.encode(defaultSettings) }
    )
    return defaultSettings
end)

RegisterNetEvent('kollin_ui:saveSettings', function(settings)
    local src = source
    if not Config.SaveSettings then return end
    if not settings or type(settings) ~= 'table' then return end

    local p = Bridge.GetPlayer(src)
    if not p then return end
    local id = Bridge.GetIdentifier(p)
    if not id then return end

    -- Strip any server-sensitive keys the client might have injected
    local safe = {
        theme     = tostring(settings.theme     or defaultSettings.theme),
        scale     = tonumber(settings.scale     or defaultSettings.scale),
        speedUnit = tostring(settings.speedUnit or defaultSettings.speedUnit),
        notifPos  = tostring(settings.notifPos  or defaultSettings.notifPos),
        hud       = type(settings.hud)   == 'table' and settings.hud   or defaultSettings.hud,
        speedo    = type(settings.speedo) == 'table' and settings.speedo or defaultSettings.speedo,
    }
    safe.scale = math.max(0.5, math.min(2.0, safe.scale))

    MySQL.update(
        'INSERT INTO kollin_ui_settings (citizenid, settings) VALUES (?, ?) ON DUPLICATE KEY UPDATE settings = ?',
        { id, json.encode(safe), json.encode(safe) }
    )
    Utils.dbg('Settings saved for', id)
end)
