-- tx_garage — Centralized lib.callback registrations
-- (Most callbacks live with the feature in sv_garage / sv_valet / sv_auction.)
-- This file is intentionally thin — kept for the scaffold pattern and future expansion.

lib.callback.register('tx_garage:getConfig', function(src)
    -- Strip server-only fields, return only what the client needs to render UI
    return {
        Currency       = Config.Currency,
        GarageTypes    = Config.GarageTypes,
        Garages        = Config.Garages,
        Valet          = Config.Valet,
        Auction        = {
            enabled            = Config.Auction.enabled,
            minBidIncrement    = Config.Auction.minBidIncrement,
            retrieveWindowHours = Config.Auction.retrieveWindowHours,
        },
        Impound        = Config.Impound,
        Notify         = Config.Notify,
        Interaction    = Config.Interaction,
    }
end)
