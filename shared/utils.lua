-- tx_garage — Shared utilities (loaded on both client and server)

Utils = {}

---Format a number as currency.
---@param amount number
---@return string
function Utils.formatMoney(amount)
    local n = math.floor(amount or 0)
    -- thousands separator
    local formatted = tostring(n)
    while true do
        local k
        formatted, k = formatted:gsub('^(-?%d+)(%d%d%d)', '%1,%2')
        if k == 0 then break end
    end
    return ('%s%s'):format(Config.Currency or '$', formatted)
end

---Clamp a value between two bounds.
function Utils.clamp(v, lo, hi)
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
---@param ... any
---@return string
function Locale(key, ...)
    local lang = (Config and Config.Locale) or 'en'
    local table = Locales and Locales[lang] or {}
    local str = table[key] or key
    if select('#', ...) > 0 then
        local ok, formatted = pcall(string.format, str, ...)
        if ok then return formatted end
    end
    return str
end

---Distance between two vec3.
function Utils.dist(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

---Generate a vehicle plate (8 chars, uppercase alphanumeric).
function Utils.genPlate()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local plate = ''
    for _ = 1, 8 do
        local i = math.random(1, #chars)
        plate = plate .. chars:sub(i, i)
    end
    return plate
end

---Per-source rate limiter. Caller owns `state` (a table keyed by src).
---Returns true when the call should be REJECTED (still cooling down), false otherwise.
---On success, stamps the time so the next call within `seconds` returns true.
---@param state table  caller-owned table (e.g. local cooldowns = {})
---@param src number   server source id
---@param key string   action key (e.g. 'bid', 'retrieve')
---@param seconds number  cooldown window in seconds
---@return boolean rejected
function Utils.isOnCooldown(state, src, key, seconds)
    local now = os.time()
    state[src] = state[src] or {}
    local last = state[src][key]
    if last and (now - last) < seconds then return true end
    state[src][key] = now
    return false
end
