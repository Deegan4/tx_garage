-- kollin_advanced_ui — Server entry & framework bridge

Bridge = {}
local Framework = nil

local function detectFramework()
    if Config.Framework ~= 'auto' then return Config.Framework end
    if GetResourceState('qb-core') == 'started' then return 'qbcore' end
    if GetResourceState('qbx_core') == 'started' then return 'qbox' end
    if GetResourceState('es_extended') == 'started' then return 'esx' end
    return 'standalone'
end

CreateThread(function()
    local fw = detectFramework()
    Config.Framework = fw

    if fw == 'qbcore' then
        Framework = exports['qb-core']:GetCoreObject()
    elseif fw == 'qbox' then
        Framework = exports.qbx_core
    elseif fw == 'esx' then
        Framework = exports['es_extended']:getSharedObject()
    end
    Utils.dbg('Bridge loaded:', fw)
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
    return nil
end

---@param player table
---@return string|nil
function Bridge.GetIdentifier(player)
    if not player then return nil end
    if Config.Framework == 'qbcore' or Config.Framework == 'qbox' then
        return player.PlayerData and player.PlayerData.citizenid
    elseif Config.Framework == 'esx' then
        return player.identifier
    end
    return nil
end

---@param player table
---@return string|nil
function Bridge.GetJob(player)
    if not player then return nil end
    if Config.Framework == 'qbcore' or Config.Framework == 'qbox' then
        return player.PlayerData and player.PlayerData.job and player.PlayerData.job.name
    elseif Config.Framework == 'esx' then
        return player.job and player.job.name
    end
    return nil
end

---@param src number
---@param msg string
---@param ntype string
function Bridge.Notify(src, msg, ntype)
    TriggerClientEvent('kollin_ui:notify', src, msg, ntype or 'inform')
end

---Returns true if player has the given ACE permission.
---@param src number
---@param ace string
---@return boolean
function Bridge.HasPermission(src, ace)
    return IsPlayerAceAllowed(tostring(src), ace)
end

---Returns job name + label for menu display.
---@param player table
---@return string, string
function Bridge.GetJobInfo(player)
    if not player then return 'none', 'Unemployed' end
    if Config.Framework == 'qbcore' or Config.Framework == 'qbox' then
        local job = player.PlayerData and player.PlayerData.job
        if job then return job.name or 'none', job.label or 'Unemployed' end
    elseif Config.Framework == 'esx' then
        return (player.job and player.job.name) or 'none',
               (player.job and player.job.label) or 'Unemployed'
    end
    return 'none', 'Unemployed'
end

---Returns gang name for QB/QBox (nil for ESX).
---@param player table
---@return string|nil
function Bridge.GetGang(player)
    if Config.Framework == 'qbcore' or Config.Framework == 'qbox' then
        local gang = player.PlayerData and player.PlayerData.gang
        return gang and gang.name ~= 'none' and gang.label or nil
    end
    return nil
end

---Returns cash + bank for menu display.
---@param player table
---@return number, number
function Bridge.GetMoney(player)
    if not player then return 0, 0 end
    if Config.Framework == 'qbcore' or Config.Framework == 'qbox' then
        local m = player.PlayerData and player.PlayerData.money
        if m then return m.cash or 0, m.bank or 0 end
    elseif Config.Framework == 'esx' then
        local cash = (player.getMoney and player.getMoney()) or 0
        local bank = (player.getAccount and player.getAccount('bank') and player.getAccount('bank').money) or 0
        return cash, bank
    end
    return 0, 0
end

-- Expose framework name to clients (safe subset).
lib.callback.register('kollin_ui:getFramework', function(src)
    return Config.Framework
end)

-- Player info for the menu Player tab (server-assembled — client gets no raw data access).
lib.callback.register('kollin_ui:getPlayerInfo', function(src)
    local p = Bridge.GetPlayer(src)
    if not p then return nil end
    local jobName, jobLabel = Bridge.GetJobInfo(p)
    local cash, bank        = Bridge.GetMoney(p)
    local gang              = Bridge.GetGang(p)
    return {
        id       = src,
        name     = GetPlayerName(tostring(src)) or 'Unknown',
        job      = { name = jobName, label = jobLabel },
        gang     = gang,
        cash     = cash,
        bank     = bank,
        isAdmin  = Bridge.HasPermission(src, Config.Menu.adminAce),
    }
end)
