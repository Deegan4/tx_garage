-- tx_garage v2.0 — Server entry & QBox helpers
-- ────────────────────────────────────────────────────────────────────────────
-- Replaces the v1 multi-framework Bridge with thin QBox-direct helpers. Other
-- server files (sv_garage, sv_valet, sv_auction, etc.) call these wrappers
-- rather than touching exports.qbx_core directly, so swapping framework versions
-- in the future is one-file-deep.

local QBX_EXPORT = exports.qbx_core

Garage = {}     -- shared module table; used by every other sv_*.lua file

---@param src number  server source id (player index)
---@return table|nil
function Garage.GetPlayer(src)
    if not src or src <= 0 then return nil end
    return QBX_EXPORT:GetPlayer(src)
end

---@param player table
---@return string|nil  citizenid
function Garage.GetCid(player)
    if not player then return nil end
    return player.PlayerData and player.PlayerData.citizenid
end

---@param player table
---@return string|nil
function Garage.GetJob(player)
    return player and player.PlayerData and player.PlayerData.job and player.PlayerData.job.name
end

---@param player table
---@return number  job grade level (0 if unknown)
function Garage.GetJobGrade(player)
    if not player then return 0 end
    local g = player.PlayerData and player.PlayerData.job and player.PlayerData.job.grade
    return tonumber(g and g.level) or 0
end

---@param player table
---@return boolean
function Garage.IsBoss(player)
    if not player then return false end
    local g = player.PlayerData and player.PlayerData.job and player.PlayerData.job.grade
    return g and (g.isboss == true or g.is_boss == true) or false
end

---@param player table
---@return string|nil
function Garage.GetGang(player)
    return player and player.PlayerData and player.PlayerData.gang and player.PlayerData.gang.name
end

---@param player table
---@param jobs table  list of job names
---@return boolean
function Garage.HasJob(player, jobs)
    local job = Garage.GetJob(player)
    if not job then return false end
    for _, j in ipairs(jobs) do if j == job then return true end end
    return false
end

---@param player table
---@param gangs table
---@return boolean
function Garage.HasGang(player, gangs)
    local gang = Garage.GetGang(player)
    if not gang then return false end
    for _, g in ipairs(gangs) do if g == gang then return true end end
    return false
end

---@param src number
---@param account 'cash'|'bank'
---@param amount number
---@return boolean ok
function Garage.RemoveMoney(src, account, amount)
    local p = Garage.GetPlayer(src); if not p then return false end
    return p.Functions.RemoveMoney(account, amount, Config.ResourceName)
end

---@param src number
---@param account 'cash'|'bank'
---@param amount number
function Garage.AddMoney(src, account, amount)
    local p = Garage.GetPlayer(src); if not p then return false end
    p.Functions.AddMoney(account, amount, Config.ResourceName)
    return true
end

---Online-aware money mutation. If the citizenid is currently online, route
---through qbx_core's player API (so events fire and auto-save uses the new
---value). Otherwise mutate the players row directly via SQL.
---Used by auction outbid refunds, auction-close payouts, and transfer settlement.
function Garage.RemoveMoneyOffline(citizenid, account, amount)
    if not citizenid or not amount or amount <= 0 then return false end
    local onlineSrc = Garage.GetSrcByCid(citizenid)
    if onlineSrc then
        return Garage.RemoveMoney(onlineSrc, account, amount)
    end
    local row = MySQL.query.await('SELECT money FROM players WHERE citizenid = ? LIMIT 1', { citizenid })
    if not row or not row[1] then return false end
    local money = json.decode(row[1].money) or {}
    if (money[account] or 0) < amount then return false end
    money[account] = money[account] - amount
    MySQL.update.await('UPDATE players SET money = ? WHERE citizenid = ?', { json.encode(money), citizenid })
    return true
end

function Garage.AddMoneyOffline(citizenid, account, amount)
    if not citizenid or not amount or amount <= 0 then return false end
    local onlineSrc = Garage.GetSrcByCid(citizenid)
    if onlineSrc then
        return Garage.AddMoney(onlineSrc, account, amount)
    end
    local row = MySQL.query.await('SELECT money FROM players WHERE citizenid = ? LIMIT 1', { citizenid })
    if not row or not row[1] then return false end
    local money = json.decode(row[1].money) or {}
    money[account] = (money[account] or 0) + amount
    MySQL.update.await('UPDATE players SET money = ? WHERE citizenid = ?', { json.encode(money), citizenid })
    return true
end

---ACE permission check. Cheaper than IsPlayerAceAllowed when called at command time
---because it only consults the in-memory ACL.
function Garage.HasAce(src, ace)
    return ace and IsPlayerAceAllowed(src, ace) or false
end

---Notify a player.
function Garage.Notify(src, msg, type_)
    TriggerClientEvent('tx_garage:notify', src, msg, type_ or 'inform')
end

---Find a player's source by citizenid (online only). Used to push outbid/transfer notifs.
function Garage.GetSrcByCid(cid)
    if not cid then return nil end
    for _, src in ipairs(GetPlayers()) do
        local p = Garage.GetPlayer(tonumber(src))
        if p and Garage.GetCid(p) == cid then return tonumber(src) end
    end
    return nil
end

---Distance between two server sources (their peds).
function Garage.SrcDistance(srcA, srcB)
    local pedA = GetPlayerPed(srcA)
    local pedB = GetPlayerPed(srcB)
    if not pedA or not pedB or pedA == 0 or pedB == 0 then return math.huge end
    local a = GetEntityCoords(pedA)
    local b = GetEntityCoords(pedB)
    return #(a - b)
end

---Resolve a configured garage by name.
function Garage.FindGarage(name)
    for _, g in ipairs(Config.Garages) do
        if g.name == name then return g end
    end
    return nil
end

---Server-side log helper for ledger writes (used by auction & boss menu).
function Garage.LogSociety(society, citizenid, action, amount, note)
    MySQL.insert(
        'INSERT INTO tx_garage_society_log (society, citizenid, action, amount, note) VALUES (?, ?, ?, ?, ?)',
        { society, citizenid or 'system', action, amount, note }
    )
end

CreateThread(function()
    Wait(500)
    Utils.dbg('tx_garage v2 — server bridge loaded (QBox-native)')
end)
