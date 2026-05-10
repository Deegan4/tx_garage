-- tx_garage v2.0 — Misc client net handlers
-- ────────────────────────────────────────────────────────────────────────────
-- Transfer-incoming consent dialog (C2 fix client side).

RegisterNetEvent('tx_garage:transferIncoming', function(req)
    if type(req) ~= 'table' then return end

    local title = Locale('transfer.received',
        req.fromName or 'Someone',
        req.model or 'Vehicle',
        Utils.formatMoney(req.price or 0))

    local accepted = lib.alertDialog({
        header  = Locale('ui.garage.transfer'),
        content = title,
        centered = true,
        cancel   = true,
        labels   = {
            confirm = Locale('transfer.accepted'),
            cancel  = Locale('transfer.rejected'),
        },
    })

    -- ox_lib returns 'confirm' on accept, 'cancel'/nil on reject.
    -- The server enforces the timeout — if the player ignores the dialog,
    -- the row expires and the response is rejected.
    TriggerServerEvent('tx_garage:transferRespond', req.reqId, accepted == 'confirm')
end)
