-- kollin_advanced_ui — Shared utilities

Utils = {}

function Utils.dbg(...)
    if Config and Config.Debug then
        print('[kollin_ui]', ...)
    end
end

function Utils.clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function Utils.formatMoney(amount)
    local n = math.floor(amount or 0)
    local s = tostring(n)
    while true do
        local k
        s, k = s:gsub('^(-?%d+)(%d%d%d)', '%1,%2')
        if k == 0 then break end
    end
    return (Config.Currency or '$') .. s
end

function Locale(key, ...)
    local lang  = (Config and Config.Locale) or 'en'
    local tbl   = (Locales and Locales[lang]) or {}
    local str   = tbl[key] or key
    if select('#', ...) > 0 then
        local ok, res = pcall(string.format, str, ...)
        if ok then return res end
    end
    return str
end
