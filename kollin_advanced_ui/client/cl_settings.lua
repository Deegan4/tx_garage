-- kollin_advanced_ui — Client settings application

-- Called from main.lua after settings are loaded; also called when NUI saves.
-- Applies theme, scale, notification position, etc. to the NUI immediately.
function ApplySettings(settings)
    if not settings then return end
    nuiSend('applySettings', settings)
end

-- When the NUI settings panel sends a change, we apply it immediately (live preview)
-- then persist via the settings/save NUI callback in main.lua.
RegisterNUICallback('settings/preview', function(data, cb)
    if data then ApplySettings(data) end
    cb({ ok = true })
end)
