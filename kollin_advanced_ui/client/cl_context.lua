-- kollin_advanced_ui — Context / interaction menu

local contextOpen = false
local contextCallbacks = {}

---Open a context menu.
---@param items table[] { label, description?, icon?, disabled?, callback? }
---@param title string?
function OpenContext(items, title)
    contextCallbacks = {}
    local nuiItems = {}

    for i, item in ipairs(items) do
        contextCallbacks[i] = item.callback
        nuiItems[i] = {
            id          = i,
            label       = item.label or '',
            description = item.description,
            icon        = item.icon,
            disabled    = item.disabled,
            color       = item.color,
        }
    end

    nuiSend('context/open', { title = title or '', items = nuiItems })
    SetNuiFocus(true, true)
    contextOpen = true
end

function CloseContext()
    if not contextOpen then return end
    nuiSend('context/close', {})
    SetNuiFocus(false, false)
    contextOpen = false
    contextCallbacks = {}
end

exports('OpenContext',  OpenContext)
exports('CloseContext', CloseContext)

RegisterNUICallback('context/select', function(data, cb)
    local id = tonumber(data and data.id)
    local fn = id and contextCallbacks[id]
    CloseContext()
    cb({ ok = true })
    if fn then
        SetTimeout(50, fn)
    end
end)

RegisterNUICallback('context/close', function(_, cb)
    CloseContext()
    cb({ ok = true })
end)
