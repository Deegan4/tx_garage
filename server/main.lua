-- tx_garage — Server entry & framework bridge

Bridge = {}
local Framework = nil

CreateThread(function()
    if Config.Framework == 'qbcore' then
        Framework = exports['qb-core']:GetCoreObject()
    elseif Config.Framework == 'qbox' then
        Framework = exports.qbx_core
    elseif Config.Framework == 'esx' then
        Framework = exports['es_extended']:getSharedObject()
    end
    Utils.dbg('Server bridge loaded for', Config.Framework)
end)

---@param src number
---@return table|nil
function Bridge.GetPlayer(src)
    if not src or src <= 0 or not Framework then return nil end
    if Config.Framework == 'qbcore' then
        return Framework.Functions.GetPlayer(src)
    elseif Config.Framework == 'qbox' then
        return exports.qbx_core:GetPlayer(src)
    elseif Config.Framework == 'esx' then
        return Framework.GetPlayerFromId(src)
    end
end

---@param player table
---@return string identifier (citizenid or esx identifier)
function Bridge.GetIdentifier(player)
    if not player then return nil end
    if Config.Framework == 'qbcore' or Config.Framework == 'qbox' then
        return player.PlayerData and player.PlayerData.citizenid
    elseif Config.Framework == 'esx' then
        return player.identifier
    end
end

---@param player table
---@return string job_name
function Bridge.GetJob(player)
    if not player then return nil end
    if Config.Framework == 'qbcore' or Config.Framework == 'qbox' then
        return player.PlayerData and player.PlayerData.job and player.PlayerData.job.name
    elseif Config.Framework == 'esx' then
        return player.job and player.job.name
    end
end

---@param player table
---@return string|nil gang_name (qb only)
function Bridge.GetGang(player)
    if Config.Framework == 'qbcore' or Config.Framework == 'qbox' then
        return player.PlayerData and player.PlayerData.gang and player.PlayerData.gang.name
    end
    return nil
end

---@param src number
---@param account string 'cash' | 'bank'
---@param amount number
---@return boolean ok
function Bridge.RemoveMoney(src, account, amount)
    local p = Bridge.GetPlayer(src)
    if not p then return false end
    if Config.Framework == 'qbcore' or Config.Framework == 'qbox' then
        return p.Functions.RemoveMoney(account, amount, 'tx_garage')
    elseif Config.Framework == 'esx' then
        if account == 'bank' then
            local ok = p.getAccount('bank').money >= amount
            if ok then p.removeAccountMoney('bank', amount) end
            return ok
        else
            local ok = p.getMoney() >= amount
            if ok then p.removeMoney(amount) end
            return ok
        end
    end
    return false
end

---@param src number
---@param account string
---@param amount number
function Bridge.AddMoney(src, account, amount)
    local p = Bridge.GetPlayer(src)
    if not p then return false end
    if Config.Framework == 'qbcore' or Config.Framework == 'qbox' then
        p.Functions.AddMoney(account, amount, 'tx_garage')
        return true
    elseif Config.Framework == 'esx' then
        if account == 'bank' then p.addAccountMoney('bank', amount)
        else p.addMoney(amount) end
        return true
    end
    return false
end

---Get money offline by identifier (used when bidder/seller is offline at auction close).
---@param identifier string
---@param account string
---@param amount number
---@return boolean
function Bridge.RemoveMoneyOffline(identifier, account, amount)
    if Config.Framework == 'qbcore' or Config.Framework == 'qbox' then
        local result = MySQL.query.await('SELECT money FROM players WHERE citizenid = ? LIMIT 1', { identifier })
        if not result or not result[1] then return false end
        local money = json.decode(result[1].money)
        if (money[account] or 0) < amount then return false end
        money[account] = money[account] - amount
        MySQL.update.await('UPDATE players SET money = ? WHERE citizenid = ?', { json.encode(money), identifier })
        return true
    elseif Config.Framework == 'esx' then
        local selectSql = (account == 'bank')
            and 'SELECT bank AS m FROM users WHERE identifier = ? LIMIT 1'
            or  'SELECT money AS m FROM users WHERE identifier = ? LIMIT 1'
        local result = MySQL.query.await(selectSql, { identifier })
        if not result or not result[1] or result[1].m < amount then return false end
        local updateSql = (account == 'bank')
            and 'UPDATE users SET bank = bank - ? WHERE identifier = ?'
            or  'UPDATE users SET money = money - ? WHERE identifier = ?'
        MySQL.update.await(updateSql, { amount, identifier })
        return true
    end
    return false
end

function Bridge.AddMoneyOffline(identifier, account, amount)
    if Config.Framework == 'qbcore' or Config.Framework == 'qbox' then
        local result = MySQL.query.await('SELECT money FROM players WHERE citizenid = ? LIMIT 1', { identifier })
        if not result or not result[1] then return false end
        local money = json.decode(result[1].money)
        money[account] = (money[account] or 0) + amount
        MySQL.update.await('UPDATE players SET money = ? WHERE citizenid = ?', { json.encode(money), identifier })
        return true
    elseif Config.Framework == 'esx' then
        local updateSql = (account == 'bank')
            and 'UPDATE users SET bank = bank + ? WHERE identifier = ?'
            or  'UPDATE users SET money = money + ? WHERE identifier = ?'
        MySQL.update.await(updateSql, { amount, identifier })
        return true
    end
    return false
end

---Notify a player using their framework's notification system.
function Bridge.Notify(src, msg, type)
    TriggerClientEvent('tx_garage:notify', src, msg, type or 'inform')
end

---Returns true if player.job.name is in jobs list.
function Bridge.HasJob(player, jobs)
    local jobName = Bridge.GetJob(player)
    if not jobName then return false end
    for _, j in ipairs(jobs) do
        if j == jobName then return true end
    end
    return false
end
