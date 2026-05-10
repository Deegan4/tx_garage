-- tx_garage v2.0 — Discord webhooks
-- ────────────────────────────────────────────────────────────────────────────
-- Listens to internal events fired by sv_garage / sv_auction / sv_events.
-- Configure URLs in Config.Webhooks. Empty url disables that hook.

local function post(url, embed)
    if not url or url == '' then return end
    PerformHttpRequest(url, function(_, _, _) end, 'POST',
        json.encode({
            username   = Config.Webhooks.botName or 'tx_garage',
            avatar_url = Config.Webhooks.botAvatar or '',
            embeds     = { embed },
        }),
        { ['Content-Type'] = 'application/json' }
    )
end

local function makeEmbed(title, fields, color)
    return {
        title       = title,
        color       = color or Config.Webhooks.color or 16722283,
        fields      = fields,
        timestamp   = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        footer      = { text = 'tx_garage' },
    }
end

AddEventHandler('tx_garage:internalAuctionStart', function(plate, model, value, startingBid)
    if not Config.Webhooks.enabled then return end
    local cfg = Config.Webhooks.auctionStart
    if not cfg or value < (cfg.minValue or 0) then return end
    post(cfg.url, makeEmbed('🔨 Auction Opened', {
        { name = 'Vehicle', value = model, inline = true },
        { name = 'Plate',   value = plate, inline = true },
        { name = 'Value',   value = Utils.formatMoney(value), inline = true },
        { name = 'Starting Bid', value = Utils.formatMoney(startingBid), inline = true },
    }))
end)

AddEventHandler('tx_garage:internalAuctionWon', function(plate, model, winnerCid, finalBid)
    if not Config.Webhooks.enabled then return end
    local cfg = Config.Webhooks.auctionWon
    if not cfg or finalBid < (cfg.minBid or 0) then return end
    post(cfg.url, makeEmbed('🏆 Auction Won', {
        { name = 'Vehicle', value = model, inline = true },
        { name = 'Plate',   value = plate, inline = true },
        { name = 'Winner',  value = winnerCid, inline = true },
        { name = 'Final Bid', value = Utils.formatMoney(finalBid), inline = true },
    }))
end)

AddEventHandler('tx_garage:internalImpound', function(plate, copCid)
    if not Config.Webhooks.enabled then return end
    local cfg = Config.Webhooks.bigImpound
    if not cfg or cfg.url == '' then return end
    -- Resolve vehicle value
    local valueRow = MySQL.query.await(
        ('SELECT vehicle, %s AS v FROM player_vehicles WHERE plate = ? LIMIT 1'):format(
            Config.Auction.valueColumn or 'depvalue'
        ), { plate }
    )
    local model = valueRow and valueRow[1] and valueRow[1].vehicle or plate
    local value = (valueRow and valueRow[1] and tonumber(valueRow[1].v)) or 0
    if value < (cfg.minValue or 0) then return end
    post(cfg.url, makeEmbed('🚓 Vehicle Impounded', {
        { name = 'Vehicle',  value = model, inline = true },
        { name = 'Plate',    value = plate, inline = true },
        { name = 'Officer',  value = copCid or 'system', inline = true },
        { name = 'Value',    value = Utils.formatMoney(value), inline = true },
    }))
end)

AddEventHandler('tx_garage:internalTransfer', function(plate, fromCid, toCid, price)
    if not Config.Webhooks.enabled then return end
    local cfg = Config.Webhooks.transfers
    if not cfg or price < (cfg.minPrice or 0) then return end
    post(cfg.url, makeEmbed('🔁 Vehicle Transferred', {
        { name = 'Plate', value = plate, inline = true },
        { name = 'From',  value = fromCid, inline = true },
        { name = 'To',    value = toCid, inline = true },
        { name = 'Price', value = Utils.formatMoney(price), inline = true },
    }))
end)
