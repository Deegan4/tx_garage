-- tx_garage — English strings
Locales = Locales or {}

Locales.en = {
    -- Garage UI
    ['ui.garage.title']        = 'Garage',
    ['ui.garage.empty']        = 'No vehicles stored.',
    ['ui.garage.retrieve']     = 'Retrieve',
    ['ui.garage.store']        = 'Store',
    ['ui.garage.transfer']     = 'Transfer',
    ['ui.garage.givekey']      = 'Give Key',
    ['ui.garage.fuel']         = 'Fuel',
    ['ui.garage.body']         = 'Body',
    ['ui.garage.engine']       = 'Engine',

    -- Valet
    ['valet.call']             = 'Call Valet',
    ['valet.requested']        = 'Valet on the way — ETA %ds.',
    ['valet.arrived']          = 'Your valet has arrived.',
    ['valet.cancelled']        = 'Valet cancelled. Refunded %s.',
    ['valet.cooldown']         = 'You can call a valet again in %ds.',
    ['valet.too_far']          = 'You must be within %dm of a garage to call a valet.',
    ['valet.not_enough_money'] = 'You cannot afford the valet (cost: %s).',

    -- Impound / Auction
    ['impound.title']          = 'Impound Lot',
    ['impound.cost']           = 'Retrieval Cost',
    ['auction.title']          = 'Impound Auction',
    ['auction.bid']            = 'Place Bid',
    ['auction.current_bid']    = 'Current bid: %s',
    ['auction.min_bid']        = 'Minimum next bid: %s',
    ['auction.bid_too_low']    = 'Bid must be at least %s.',
    ['auction.outbid']         = 'You have been outbid on %s. New bid: %s',
    ['auction.won']            = 'You won the auction for %s at %s.',
    ['auction.retrieve_window'] = 'Retrieve within %d hours or forfeit.',
    ['auction.no_money']       = 'You cannot cover this bid.',
    ['auction.closing_soon']   = 'Auction closing in ~5 minutes: %s',

    -- General
    ['error.no_permission']    = 'You do not have permission.',
    ['error.no_money']         = 'You cannot afford this.',
    ['error.cooldown']         = 'You need to wait before doing that.',
    ['error.not_owner']        = 'You do not own this vehicle.',
    ['success.vehicle_stored'] = 'Vehicle stored.',
    ['success.vehicle_taken']  = 'Vehicle retrieved.',
    ['success.payment']        = 'Paid %s.',
}
