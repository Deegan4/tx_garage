-- kollin_advanced_ui — Client entry point

local PlayerLoaded   = false
local ClientSettings = nil
local Framework      = nil   -- 'qbcore' | 'qbox' | 'esx' | 'standalone'

-- ── Exported accessor ────────────────────────────────────────────────
function GetSettings() return ClientSettings end
function IsPlayerLoaded() return PlayerLoaded end

-- ── NUI helpers ──────────────────────────────────────────────────────
function nuiPost(action, data)
    return fetch(('https://kollin_advanced_ui/%s'):format(action), {
        method  = 'POST',
        headers = { ['Content-Type'] = 'application/json' },
        body    = json.encode(data or {}),
    })
end

function nuiSend(action, data)
    SendNUIMessage({ action = action, data = data or {} })
end

-- ── Initialisation ──────────────────────────────────────────────────
CreateThread(function()
    Framework = lib.callback.await('kollin_ui:getFramework', false)

    ClientSettings = lib.callback.await('kollin_ui:loadSettings', false) or {
        theme     = Config.DefaultTheme,
        scale     = Config.DefaultScale,
        speedUnit = Config.Speedometer.unit,
        notifPos  = Config.Notifications.position,
    }

    -- Apply initial theme + scale
    nuiSend('init', {
        settings  = ClientSettings,
        framework = Framework,
        locale    = Config.Locale,
    })

    -- Key bind: open menu
    if Config.Menu.enabled then
        RegisterKeyMapping(
            'kollin_menu_toggle',
            'Open/Close kollin_advanced_ui menu',
            'keyboard',
            Config.Menu.openKey
        )
        RegisterCommand('kollin_menu_toggle', function()
            ToggleMenu()
        end, false)
        if Config.Menu.openCommand and Config.Menu.openCommand ~= '' then
            RegisterCommand(Config.Menu.openCommand, function()
                ToggleMenu()
            end, false)
        end
    end

    PlayerLoaded = true
    Utils.dbg('Client ready, framework:', Framework)
end)

-- ── Framework player-loaded events ──────────────────────────────────
if Config.Framework == 'qbcore' or Config.Framework == 'auto' then
    AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
        PlayerLoaded = true
    end)
    AddEventHandler('QBCore:Client:OnPlayerUnload', function()
        PlayerLoaded = false
    end)
end

AddEventHandler('esx:playerLoaded', function()
    PlayerLoaded = true
end)

-- ── Notification relay from server ──────────────────────────────────
RegisterNetEvent('kollin_ui:notify', function(msg, ntype)
    Notify(msg, ntype)
end)

-- ── NUI closed callback ──────────────────────────────────────────────
RegisterNUICallback('ui/close', function(_, cb)
    SetNuiFocus(false, false)
    cb({ ok = true })
end)

-- ── Persist settings when client changes them ────────────────────────
RegisterNUICallback('settings/save', function(data, cb)
    ClientSettings = data
    TriggerServerEvent('kollin_ui:saveSettings', data)
    nuiSend('notify', { msg = Locale('settings.saved'), type = 'success', duration = 2500 })
    cb({ ok = true })
end)

RegisterNUICallback('settings/reset', function(_, cb)
    ClientSettings = {
        theme     = Config.DefaultTheme,
        scale     = Config.DefaultScale,
        speedUnit = Config.Speedometer.unit,
        notifPos  = Config.Notifications.position,
    }
    nuiSend('applySettings', ClientSettings)
    TriggerServerEvent('kollin_ui:saveSettings', ClientSettings)
    cb({ ok = true })
end)

-- ── Auto-save interval ────────────────────────────────────────────────
if Config.SaveSettings and Config.SaveInterval > 0 then
    CreateThread(function()
        while true do
            Wait(Config.SaveInterval * 1000)
            if ClientSettings and PlayerLoaded then
                TriggerServerEvent('kollin_ui:saveSettings', ClientSettings)
            end
        end
    end)
end
