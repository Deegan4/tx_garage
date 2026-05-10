-- tx_garage v2.0 — Shared utilities (loaded on both client and server)

Utils = {}

---Format a number as currency.
---@param amount number
---@return string
function Utils.formatMoney(amount)
    local n = math.floor(tonumber(amount) or 0)
    local sign = n < 0 and '-' or ''
    local abs  = math.abs(n)
    local s    = tostring(abs)
    while true do
        local k
        s, k = s:gsub('^(%d+)(%d%d%d)', '%1,%2')
        if k == 0 then break end
    end
    return ('%s%s%s'):format(sign, Config.Currency or '$', s)
end

---Clamp a value between two bounds.
function Utils.clamp(v, lo, hi)
    if v == nil then return lo end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

---Random integer between lo and hi inclusive.
function Utils.randint(lo, hi)
    return math.random(lo, hi)
end

---Debug print, only fires when Config.Debug is true.
function Utils.dbg(...)
    if Config and Config.Debug then
        print('[tx_garage]', ...)
    end
end

---Localized string lookup with fallback.
---@param key string
function Locale(key, ...)
    local lang = (Config and Config.Locale) or 'en'
    local table_ = Locales and Locales[lang] or {}
    local str = table_[key] or key
    if select('#', ...) > 0 then
        local ok, formatted = pcall(string.format, str, ...)
        if ok then return formatted end
    end
    return str
end

---Distance between two vec3.
function Utils.dist(a, b)
    if not a or not b then return math.huge end
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

---Generate a vehicle plate (uppercase alphanumeric).
function Utils.genPlate(len)
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local plate = ''
    for _ = 1, (len or 8) do
        local i = math.random(1, #chars)
        plate = plate .. chars:sub(i, i)
    end
    return plate
end

---Trim & uppercase a plate exactly the way GTA presents it.
function Utils.normalizePlate(p)
    if type(p) ~= 'string' then return nil end
    p = p:gsub('%s+$', ''):gsub('^%s+', ''):upper()
    return #p > 0 and p or nil
end

---Per-source rate limiter.
---@return boolean rejected  true → caller should bail
function Utils.isOnCooldown(state, src, key, seconds)
    local now = os.time()
    state[src] = state[src] or {}
    local last = state[src][key]
    if last and (now - last) < seconds then return true end
    state[src][key] = now
    return false
end

---Determine vehicle "class bucket" by model hash for NUI gradient/preview.
---Used both server-side (for webhook color) and client-side (for thumb).
local SUPER = { 'adder','zentorno','t20','osiris','reaper','prototipe','tyrus','xa21','vagner','italigtb','sc1','tezeract','infernus','cheetah','entityxf','turismo','furiagt' }
local SPORTS = { 'sultan','futo','jester','massacro','rapidgt','elegy','elegy2','feltzer','9f','9f2','banshee','buffalo','buffalo2','carbonizzare' }
local SUV = { 'baller','baller2','baller3','baller4','baller5','baller6','radi','seminole','rocoto','dubsta','huntley' }
local MOTO = { 'akuma','bati','bati2','double','faggio','faggio2','hakuchou','hakuchou2','vader','pcj','sanchez','sanchez2','daemon' }
local TRUCK = { 'bison','bison2','bison3','bobcatxl','rebel','rebel2','sandking','sandking2','blade','dukes','dukes2' }
local SEDAN = { 'asea','asterope','cognoscenti','cognoscenti2','emperor','fugitive','glendale','intruder','premier','primo','regina','schafter2','stratum','stanier','superd','warrener','washington' }

local function inList(model, list)
    model = (model or ''):lower()
    for _, m in ipairs(list) do if m == model then return true end end
    return false
end

function Utils.classifyModel(model)
    if inList(model, SUPER)  then return 'super' end
    if inList(model, SPORTS) then return 'sports' end
    if inList(model, SUV)    then return 'suv' end
    if inList(model, MOTO)   then return 'motorcycle' end
    if inList(model, TRUCK)  then return 'truck' end
    if inList(model, SEDAN)  then return 'sedan' end
    return 'compact'
end
