-- kollin_advanced_ui — Notification system

---Core notify function used by all other modules.
---@param msg string
---@param ntype string 'success'|'error'|'info'|'warning'|'announce'
---@param duration number? milliseconds
function Notify(msg, ntype, duration)
    ntype    = ntype    or 'info'
    duration = duration or Config.Notifications.defaultDuration

    nuiSend('notify', {
        msg      = tostring(msg),
        type     = ntype,
        duration = duration,
        position = (GetSettings() or {}).notifPos or Config.Notifications.position,
    })
end

-- Export for other resources
exports('Notify', Notify)

-- Replace default QBCore / ESX notifications if configured
if Config.Notifications.replaceDefault then
    -- QBCore
    AddEventHandler('QBCore:Notify', function(msg, ntype, duration)
        local t = ntype
        if t == 'primary' then t = 'info' end
        Notify(msg, t, duration)
    end)

    -- ESX
    AddEventHandler('esx:showNotification', function(msg)
        Notify(msg, 'info')
    end)
    AddEventHandler('esx:showAdvancedNotification', function(sender, subject, msg)
        Notify(('[%s] %s: %s'):format(sender, subject, msg), 'info')
    end)

    -- ox_lib passthrough (ox_lib routes through lib.notify which fires its own NUI)
    -- Override only when this resource is loaded AFTER ox_lib; use exports instead.
end

-- Server-pushed notifications already handled in main.lua (kollin_ui:notify event).

RegisterNUICallback('notify/dismissed', function(_, cb)
    cb({ ok = true })
end)
