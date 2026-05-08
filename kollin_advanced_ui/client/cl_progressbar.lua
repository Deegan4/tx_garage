-- kollin_advanced_ui — Progress bar system

local activeProgress = false
local cancelCallback = nil

---Show a progress bar.
---@param data table { label, duration, canCancel?, onCancel? }
---@param callback function called with true (completed) or false (cancelled)
function Progress(data, callback)
    if activeProgress then return false end
    if not data or not data.duration then return false end

    activeProgress = true
    cancelCallback = data.onCancel

    local cancelKey = Config.ProgressBar.cancelKey or 'BACKSPACE'
    local canCancel = Config.ProgressBar.cancellable and (data.canCancel ~= false)

    nuiSend('progress/start', {
        label     = data.label     or '',
        duration  = data.duration,
        canCancel = canCancel,
        cancelKey = cancelKey,
        color     = data.color,   -- optional accent color override
    })

    -- Watch for cancel key
    if canCancel then
        CreateThread(function()
            while activeProgress do
                Wait(0)
                if IsControlJustPressed(0, GetHashKey(cancelKey)) then
                    CancelProgress()
                    break
                end
            end
        end)
    end

    -- Timer
    SetTimeout(data.duration, function()
        if activeProgress then
            activeProgress = false
            cancelCallback = nil
            nuiSend('progress/stop', {})
            if callback then callback(true) end
        end
    end)

    return true
end

function CancelProgress()
    if not activeProgress then return end
    activeProgress = false
    nuiSend('progress/stop', {})
    if cancelCallback then cancelCallback() end
    cancelCallback = nil
end

exports('Progress',       Progress)
exports('CancelProgress', CancelProgress)
exports('IsProgressActive', function() return activeProgress end)

RegisterNUICallback('progress/cancel', function(_, cb)
    CancelProgress()
    cb({ ok = true })
end)
