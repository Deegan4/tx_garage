-- tx_garage v2.0 — Misc server events
-- ────────────────────────────────────────────────────────────────────────────
-- Transfer-consent flow (C2 fix), give-key proximity (C3 fix), plate change,
-- sub-owners, boss menu deposit/withdraw.

local cooldowns = {}
local function isOnCooldown(src, key, seconds)
    return Utils.isOnCooldown(cooldowns, src, key, seconds)
end
AddEventHandler('playerDropped', function() cooldowns[source] = nil end)

-- ─────────────────────────────────────────────────────────────────────
-- Give Key — C3 fix: proximity + accept dialog (asynchronous)
-- ─────────────────────────────────────────────────────────────────────

RegisterNetEvent('tx_garage:giveKey', function(plate, targetServerId)
    local src = source
    if isOnCooldown(src, 'giveKey', 3) then return end

    local p = Garage.GetPlayer(src); if not p then return end
    targetServerId = tonumber(targetServerId); if not targetServerId then return end
    local target = Garage.GetPlayer(targetServerId); if not target then return end
    plate = Utils.normalizePlate(plate); if not plate then return end

    -- Caller must be a full owner
    if not MySQL.scalar.await(
        'SELECT 1 FROM player_vehicles WHERE citizenid = ? AND plate = ? LIMIT 1',
        { Garage.GetCid(p), plate }
    ) then
        Garage.Notify(src, Locale('error.not_owner'), 'error'); return
    end

    -- C3: Proximity gate
    if Garage.SrcDistance(src, targetServerId) > 5.0 then
        Garage.Notify(src, Locale('transfer.too_far'), 'error'); return
    end

    -- Hand off to keys resource
    if Config.Storage.keysResource == 'qbx_vehiclekeys' then
        TriggerClientEvent('qbx_vehiclekeys:client:GiveKeys', targetServerId, plate)
    elseif Config.Storage.keysResource == 'qb-vehiclekeys' then
        TriggerClientEvent('qb-vehiclekeys:client:GiveKeys', targetServerId, plate)
    elseif Config.Storage.keysResource == 'qs-vehiclekeys' then
        local ok, _ = pcall(function() return exports['qs-vehiclekeys']:GiveKeys(targetServerId, plate) end)
        if not ok then
            TriggerClientEvent('vehiclekeys:client:SetOwner', targetServerId, plate)
        end
    else
        TriggerClientEvent('vehiclekeys:client:SetOwner', targetServerId, plate)
    end

    Garage.Notify(src, Locale('ui.garage.givekey'), 'success')
    Garage.Notify(targetServerId, Locale('ui.garage.givekey'), 'success')
end)

-- ─────────────────────────────────────────────────────────────────────
-- Transfer ownership — C2 fix: consent flow with timed expiry
-- ─────────────────────────────────────────────────────────────────────

RegisterNetEvent('tx_garage:transferRequest', function(plate, targetServerId, price)
    local src = source
    if isOnCooldown(src, 'transferReq', 5) then return end
    if not Config.Transfer.enabled then return end

    local p = Garage.GetPlayer(src); if not p then return end
    targetServerId = tonumber(targetServerId); if not targetServerId then return end
    local target = Garage.GetPlayer(targetServerId); if not target then return end
    plate = Utils.normalizePlate(plate); if not plate then return end

    -- Validate price
    price = tonumber(price) or 0
    if price < (Config.Transfer.minPrice or 0) or price > (Config.Transfer.maxPrice or 5000000) then
        Garage.Notify(src, Locale('error.no_permission'), 'error'); return
    end

    -- Caller must be the full owner
    local fromCid = Garage.GetCid(p)
    if not MySQL.scalar.await(
        'SELECT 1 FROM player_vehicles WHERE citizenid = ? AND plate = ? LIMIT 1',
        { fromCid, plate }
    ) then
        Garage.Notify(src, Locale('error.not_owner'), 'error'); return
    end

    -- Proximity
    if Garage.SrcDistance(src, targetServerId) > (Config.Transfer.requireProximity or 5.0) then
        Garage.Notify(src, Locale('transfer.too_far'), 'error'); return
    end

    local toCid = Garage.GetCid(target)
    local timeout = Config.Transfer.requestTimeout or 30
    local expiresAt = os.date('%Y-%m-%d %H:%M:%S', os.time() + timeout)

    -- Insert pending request (used for replay protection / audit)
    local reqId = MySQL.insert.await([[
        INSERT INTO tx_garage_transfer_requests (plate, from_citizenid, to_citizenid, price, expires_at)
        VALUES (?, ?, ?, ?, ?)
    ]], { plate, fromCid, toCid, price, expiresAt })

    -- Get vehicle display name for the prompt
    local vrow = MySQL.query.await(
        'SELECT vehicle FROM player_vehicles WHERE plate = ? LIMIT 1', { plate }
    )
    local model = (vrow and vrow[1] and vrow[1].vehicle) or 'Vehicle'

    -- Push to target — they'll see a lib.alertDialog client-side
    TriggerClientEvent('tx_garage:transferIncoming', targetServerId, {
        reqId    = reqId,
        plate    = plate,
        model    = model,
        fromName = (p.PlayerData.charinfo and (p.PlayerData.charinfo.firstname..' '..p.PlayerData.charinfo.lastname)) or 'Unknown',
        price    = price,
        timeout  = timeout,
    })
    Garage.Notify(src, Locale('transfer.requested',
        (target.PlayerData.charinfo and (target.PlayerData.charinfo.firstname..' '..target.PlayerData.charinfo.lastname)) or 'them'),
        'inform')
end)

RegisterNetEvent('tx_garage:transferRespond', function(reqId, accept)
    local src = source
    if isOnCooldown(src, 'transferResp', 1) then return end

    local p = Garage.GetPlayer(src); if not p then return end
    reqId = tonumber(reqId); if not reqId then return end

    local toCid = Garage.GetCid(p)
    local row = MySQL.query.await([[
        SELECT plate, from_citizenid, to_citizenid, price, status,
               UNIX_TIMESTAMP(expires_at) AS expires_ts
        FROM tx_garage_transfer_requests WHERE id = ? LIMIT 1
    ]], { reqId })
    if not row or not row[1] then return end
    local r = row[1]
    if r.to_citizenid ~= toCid then return end
    if r.status ~= 'pending' then return end
    if (tonumber(r.expires_ts) or 0) < os.time() then
        MySQL.update.await(
            "UPDATE tx_garage_transfer_requests SET status = 'expired' WHERE id = ?", { reqId }
        )
        Garage.Notify(src, Locale('transfer.expired'), 'error'); return
    end

    if not accept then
        MySQL.update.await(
            "UPDATE tx_garage_transfer_requests SET status = 'rejected' WHERE id = ?", { reqId }
        )
        Garage.Notify(src, Locale('transfer.rejected'), 'inform')
        local fromSrc = Garage.GetSrcByCid(r.from_citizenid)
        if fromSrc then Garage.Notify(fromSrc, Locale('transfer.rejected'), 'error') end
        return
    end

    -- Accept path. Order is critical to prevent dupes:
    --   1. Debit buyer (refundable if anything below fails)
    --   2. ATOMIC ownership flip — single source of truth for "transfer happened"
    --   3. Pay seller ONLY after flip succeeds
    -- If we paid the seller before step 2 and step 2 lost a race, we'd have to
    -- claw back from the seller via RemoveMoneyOffline, which silently fails if
    -- they spent the funds — money would dupe. Pay-after-flip is dupe-proof.
    if r.price > 0 and not Garage.RemoveMoney(src, 'bank', r.price) then
        Garage.Notify(src, Locale('transfer.cannot_afford'), 'error')
        MySQL.update.await(
            "UPDATE tx_garage_transfer_requests SET status = 'rejected' WHERE id = ?", { reqId }
        )
        return
    end

    local upd = MySQL.update.await([[
        UPDATE player_vehicles SET citizenid = ?, tx_garage_sub_owners = NULL
        WHERE plate = ? AND citizenid = ?
    ]], { toCid, r.plate, r.from_citizenid })

    if not upd or upd == 0 then
        -- Race lost — refund buyer; seller was never paid so nothing to claw back.
        if r.price > 0 then Garage.AddMoney(src, 'bank', r.price) end
        Garage.Notify(src, Locale('error.bad_state'), 'error')
        return
    end

    -- Flip succeeded — now pay the seller. Online-aware to avoid clobbering
    -- their auto-save state if they're currently logged in.
    if r.price > 0 then
        local sellerSrc = Garage.GetSrcByCid(r.from_citizenid)
        if sellerSrc then
            Garage.AddMoney(sellerSrc, 'bank', r.price)
        else
            Garage.AddMoneyOffline(r.from_citizenid, 'bank', r.price)
        end
    end

    MySQL.update.await(
        "UPDATE tx_garage_transfer_requests SET status = 'accepted' WHERE id = ?", { reqId }
    )

    -- Get model for friendly message
    local vrow = MySQL.query.await(
        'SELECT vehicle FROM player_vehicles WHERE plate = ? LIMIT 1', { r.plate }
    )
    local model = (vrow and vrow[1] and vrow[1].vehicle) or r.plate

    Garage.Notify(src, Locale('transfer.completed', model), 'success')
    local fromSrc = Garage.GetSrcByCid(r.from_citizenid)
    if fromSrc then Garage.Notify(fromSrc, Locale('transfer.accepted'), 'success') end

    TriggerEvent('tx_garage:internalTransfer', r.plate, r.from_citizenid, toCid, r.price)
end)

-- Cleanup expired transfer requests every 5 minutes
CreateThread(function()
    while true do
        Wait(300000)
        MySQL.update(
            "UPDATE tx_garage_transfer_requests SET status = 'expired' WHERE status = 'pending' AND expires_at <= NOW()"
        )
    end
end)

-- ─────────────────────────────────────────────────────────────────────
-- Plate change
-- ─────────────────────────────────────────────────────────────────────

RegisterNetEvent('tx_garage:changePlate', function(oldPlate, newPlate)
    local src = source
    if isOnCooldown(src, 'platechange', 3) then return end
    if not Config.PlateChange.enabled then return end

    local p = Garage.GetPlayer(src); if not p then return end
    oldPlate = Utils.normalizePlate(oldPlate)
    newPlate = Utils.normalizePlate(newPlate)
    if not oldPlate or not newPlate then
        Garage.Notify(src, Locale('plate.invalid'), 'error'); return
    end

    -- Length + pattern validation
    if #newPlate < (Config.PlateChange.minLen or 2) or #newPlate > (Config.PlateChange.maxLen or 8)
       or not newPlate:match(Config.PlateChange.pattern or '^[A-Z0-9]+$') then
        Garage.Notify(src, Locale('plate.invalid'), 'error'); return
    end

    local cid = Garage.GetCid(p)

    -- Caller must own oldPlate; also pull the last plate-change timestamp.
    local row = MySQL.query.await([[
        SELECT tx_garage_plate_changed_at AS last_change
        FROM player_vehicles WHERE citizenid = ? AND plate = ? LIMIT 1
    ]], { cid, oldPlate })
    if not row or not row[1] then
        Garage.Notify(src, Locale('error.not_owner'), 'error'); return
    end

    -- Per-vehicle cooldown (Config.PlateChange.cooldown, seconds)
    if row[1].last_change then
        local elapsed = MySQL.scalar.await(
            'SELECT TIMESTAMPDIFF(SECOND, ?, NOW())', { row[1].last_change }
        ) or math.huge
        local cooldown = tonumber(Config.PlateChange.cooldown) or 86400
        if elapsed < cooldown then
            local remaining = cooldown - elapsed
            local hrs = math.floor(remaining / 3600)
            local mins = math.floor((remaining % 3600) / 60)
            Garage.Notify(src,
                Locale('plate.cooldown', ('%dh %dm'):format(hrs, mins)),
                'error')
            return
        end
    end

    -- newPlate must not already exist
    if MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ? LIMIT 1', { newPlate }) then
        Garage.Notify(src, Locale('plate.taken'), 'error'); return
    end

    -- Charge fee
    if not Garage.RemoveMoney(src, Config.PlateChange.account or 'bank', Config.PlateChange.cost or 5000) then
        Garage.Notify(src, Locale('error.no_money'), 'error'); return
    end

    -- Atomic plate flip + cooldown stamp; only succeeds if old still owned by caller.
    local upd = MySQL.update.await([[
        UPDATE player_vehicles
        SET plate = ?, tx_garage_plate_changed_at = NOW()
        WHERE plate = ? AND citizenid = ?
    ]], { newPlate, oldPlate, cid })
    if not upd or upd == 0 then
        -- Race lost — refund
        Garage.AddMoney(src, Config.PlateChange.account or 'bank', Config.PlateChange.cost or 5000)
        Garage.Notify(src, Locale('error.bad_state'), 'error'); return
    end
    Garage.Notify(src, Locale('plate.changed', newPlate), 'success')
end)

-- ─────────────────────────────────────────────────────────────────────
-- Sub-owners (key sharing)
-- ─────────────────────────────────────────────────────────────────────

RegisterNetEvent('tx_garage:addSubOwner', function(plate, targetServerId)
    local src = source
    if isOnCooldown(src, 'subAdd', 2) then return end
    if not Config.SubOwners.enabled then return end

    local p = Garage.GetPlayer(src); if not p then return end
    targetServerId = tonumber(targetServerId); if not targetServerId then return end
    local target = Garage.GetPlayer(targetServerId); if not target then return end
    plate = Utils.normalizePlate(plate); if not plate then return end

    -- Owner only
    local cid = Garage.GetCid(p)
    local row = MySQL.query.await(
        'SELECT tx_garage_sub_owners FROM player_vehicles WHERE citizenid = ? AND plate = ? LIMIT 1',
        { cid, plate }
    )
    if not row or not row[1] then
        Garage.Notify(src, Locale('error.not_owner'), 'error'); return
    end

    -- Proximity
    if Garage.SrcDistance(src, targetServerId) > (Config.SubOwners.requireProximity or 5.0) then
        Garage.Notify(src, Locale('sub.too_far'), 'error'); return
    end

    local list = json.decode(row[1].tx_garage_sub_owners or '[]') or {}
    local targetCid = Garage.GetCid(target)

    if #list >= (Config.SubOwners.maxPerVehicle or 4) then
        Garage.Notify(src, Locale('sub.max_reached', Config.SubOwners.maxPerVehicle), 'error'); return
    end
    for _, c in ipairs(list) do
        if c == targetCid then
            Garage.Notify(src, Locale('sub.already'), 'error'); return
        end
    end

    list[#list+1] = targetCid
    MySQL.update.await(
        'UPDATE player_vehicles SET tx_garage_sub_owners = ? WHERE plate = ? AND citizenid = ?',
        { json.encode(list), plate, cid }
    )

    local targetName = (target.PlayerData.charinfo and (target.PlayerData.charinfo.firstname..' '..target.PlayerData.charinfo.lastname)) or targetCid
    Garage.Notify(src, Locale('sub.added', targetName), 'success')
end)

RegisterNetEvent('tx_garage:removeSubOwner', function(plate, targetCid)
    local src = source
    if isOnCooldown(src, 'subRemove', 2) then return end

    local p = Garage.GetPlayer(src); if not p then return end
    plate = Utils.normalizePlate(plate); if not plate then return end
    if type(targetCid) ~= 'string' or #targetCid == 0 or #targetCid > 64 then return end

    local cid = Garage.GetCid(p)
    local row = MySQL.query.await(
        'SELECT tx_garage_sub_owners FROM player_vehicles WHERE citizenid = ? AND plate = ? LIMIT 1',
        { cid, plate }
    )
    if not row or not row[1] then
        Garage.Notify(src, Locale('error.not_owner'), 'error'); return
    end

    local list = json.decode(row[1].tx_garage_sub_owners or '[]') or {}
    local newList = {}
    for _, c in ipairs(list) do if c ~= targetCid then newList[#newList+1] = c end end

    MySQL.update.await(
        'UPDATE player_vehicles SET tx_garage_sub_owners = ? WHERE plate = ? AND citizenid = ?',
        { (#newList > 0 and json.encode(newList) or nil), plate, cid }
    )
    Garage.Notify(src, Locale('sub.removed'), 'success')
end)

-- ─────────────────────────────────────────────────────────────────────
-- Boss menu (society deposit/withdraw)
-- ─────────────────────────────────────────────────────────────────────

local function bossGate(src)
    local p = Garage.GetPlayer(src)
    if not p or not Garage.IsBoss(p) then
        Garage.Notify(src, Locale('error.no_permission'), 'error'); return nil
    end
    return p
end

RegisterNetEvent('tx_garage:bossDeposit', function(amount)
    local src = source
    if isOnCooldown(src, 'bossDep', 2) then return end
    local p = bossGate(src); if not p then return end
    amount = tonumber(amount); if not amount or amount <= 0 then return end

    if not Garage.RemoveMoney(src, 'bank', amount) then
        Garage.Notify(src, Locale('error.no_money'), 'error'); return
    end
    local society = Garage.GetJob(p)
    Garage.LogSociety(society, Garage.GetCid(p), 'deposit', amount, 'boss menu')
    Garage.Notify(src, Locale('boss.deposited', Utils.formatMoney(amount)), 'success')
end)

RegisterNetEvent('tx_garage:bossWithdraw', function(amount)
    local src = source
    if isOnCooldown(src, 'bossWdr', 2) then return end
    local p = bossGate(src); if not p then return end
    amount = tonumber(amount); if not amount or amount <= 0 then return end

    local society = Garage.GetJob(p)

    -- Atomic balance check + ledger insert in one statement.
    -- INSERT...SELECT only inserts when the balance subquery returns >= amount.
    -- Two concurrent withdraws racing here will both compute the same balance
    -- on read, but only the first INSERT actually appears in the ledger; the
    -- second sees the new balance and the affectedRows result tells us.
    local insertId = MySQL.insert.await([[
        INSERT INTO tx_garage_society_log (society, citizenid, action, amount, note)
        SELECT ?, ?, 'withdraw', ?, 'boss menu'
        FROM (SELECT
            COALESCE(SUM(CASE WHEN action IN ('deposit','auction_cut') THEN amount ELSE 0 END), 0)
          - COALESCE(SUM(CASE WHEN action = 'withdraw' THEN amount ELSE 0 END), 0)
            AS balance
            FROM tx_garage_society_log WHERE society = ?
        ) AS bal
        WHERE bal.balance >= ?
    ]], { society, Garage.GetCid(p), amount, society, amount })

    if not insertId or insertId == 0 then
        Garage.Notify(src, Locale('boss.no_funds'), 'error'); return
    end

    Garage.AddMoney(src, 'bank', amount)
    Garage.Notify(src, Locale('boss.withdrew', Utils.formatMoney(amount)), 'success')
end)
