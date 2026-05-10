-- tx_garage v2.0 — English strings
Locales = Locales or {}

Locales.en = {
    -- ── Garage UI ──────────────────────────────────────────────────────
    ['ui.garage.title']         = 'Garage',
    ['ui.garage.empty']         = 'No vehicles stored here.',
    ['ui.garage.search']        = 'Search vehicles…',
    ['ui.garage.retrieve']      = 'Retrieve',
    ['ui.garage.store']         = 'Store Vehicle',
    ['ui.garage.transfer']      = 'Transfer',
    ['ui.garage.givekey']       = 'Give Key',
    ['ui.garage.changeplate']   = 'Change Plate',
    ['ui.garage.subowners']     = 'Sub-owners',
    ['ui.garage.fuel']          = 'Fuel',
    ['ui.garage.body']          = 'Body',
    ['ui.garage.engine']        = 'Engine',
    ['ui.garage.mileage']       = 'Mileage',
    ['ui.garage.boss']          = 'Boss Menu',
    ['ui.garage.km']            = 'km',

    -- ── Valet ──────────────────────────────────────────────────────────
    ['valet.call']              = 'Call Valet',
    ['valet.requested']         = 'Valet on the way — ETA %ds. Cost: %s',
    ['valet.arrived']           = 'Your valet has arrived.',
    ['valet.cancelled']         = 'Valet cancelled. Refunded %s.',
    ['valet.cooldown']          = 'You can call a valet again in %ds.',
    ['valet.too_far']           = 'You must be within %dm of a garage to call a valet.',
    ['valet.not_enough_money']  = 'You cannot afford the valet (cost: %s).',
    ['valet.no_vehicles']       = 'No stored vehicles in this garage to deliver.',
    ['valet.in_progress']       = 'A valet delivery is already in progress.',
    ['valet.path_blocked']      = 'No clear path for the valet. Try a different location.',

    -- ── Impound ────────────────────────────────────────────────────────
    ['impound.title']           = 'Impound Lot',
    ['impound.cost']            = 'Retrieval Cost',
    ['impound.released']        = 'Vehicle released from impound.',
    ['impound.occupied']        = 'Cannot impound: vehicle is occupied.',
    ['impound.moving']          = 'Cannot impound: vehicle is moving.',

    -- ── Auction ────────────────────────────────────────────────────────
    ['auction.title']           = 'Impound Auction House',
    ['auction.empty']           = 'No active auctions right now.',
    ['auction.bid']             = 'Place Bid',
    ['auction.current_bid']     = 'Current bid: %s',
    ['auction.starting_bid']    = 'Starting: %s',
    ['auction.min_bid']         = 'Min next bid: %s',
    ['auction.bid_too_low']     = 'Bid must be at least %s.',
    ['auction.bid_stale']       = 'Auction state changed — refresh and try again.',
    ['auction.outbid']          = 'You have been outbid on auction #%s. New bid: %s',
    ['auction.won']             = 'You won the auction for %s at %s.',
    ['auction.retrieve_window'] = 'Retrieve within %d hours or forfeit.',
    ['auction.no_money']        = 'You cannot cover this bid.',
    ['auction.closing_soon']    = 'Auction closing in ~5 minutes: %s',
    ['auction.extended']        = 'Bid in final seconds — auction extended by %ds.',
    ['auction.refunded']        = 'You were outbid — %s refunded.',
    ['auction.watch_on']        = 'Watching auction. You will be notified before it closes.',
    ['auction.watch_off']       = 'No longer watching this auction.',

    -- ── Plate change ───────────────────────────────────────────────────
    ['plate.changed']           = 'Plate changed to %s.',
    ['plate.invalid']           = 'Invalid plate format.',
    ['plate.taken']             = 'That plate is already in use.',
    ['plate.cooldown']          = 'You can change this plate again in %s.',

    -- ── Transfer (consent flow) ────────────────────────────────────────
    ['transfer.requested']      = 'Transfer request sent to %s.',
    ['transfer.received']       = '%s wants to transfer "%s" to you for %s. Accept?',
    ['transfer.accepted']       = 'Transfer accepted.',
    ['transfer.rejected']       = 'Transfer rejected.',
    ['transfer.expired']        = 'Transfer request expired.',
    ['transfer.completed']      = 'Vehicle "%s" is now yours.',
    ['transfer.too_far']        = 'Target player is too far away.',
    ['transfer.cannot_afford']  = 'You cannot afford the transfer fee.',

    -- ── Sub-owners ─────────────────────────────────────────────────────
    ['sub.added']               = 'Added %s as sub-owner.',
    ['sub.removed']             = 'Removed sub-owner.',
    ['sub.max_reached']         = 'Maximum %d sub-owners already added.',
    ['sub.already']             = 'That player is already a sub-owner.',
    ['sub.too_far']             = 'Target player is too far away.',

    -- ── Boss menu ──────────────────────────────────────────────────────
    ['boss.balance']            = 'Society balance: %s',
    ['boss.deposit']            = 'Deposit',
    ['boss.withdraw']           = 'Withdraw',
    ['boss.history']            = 'View History',
    ['boss.deposited']          = 'Deposited %s into the society.',
    ['boss.withdrew']           = 'Withdrew %s from the society.',
    ['boss.no_funds']           = 'Society lacks funds for that withdrawal.',

    -- ── Admin ──────────────────────────────────────────────────────────
    ['admin.no_perm']           = 'You lack permission for that command.',
    ['admin.spawned']           = 'Admin: spawned %s.',
    ['admin.deleted']           = 'Admin: vehicle deleted.',
    ['admin.tp_done']           = 'Admin: teleported to vehicle.',
    ['admin.not_found']         = 'No vehicle found for that plate.',

    -- ── General ────────────────────────────────────────────────────────
    ['error.no_permission']     = 'You do not have permission.',
    ['error.no_money']          = 'You cannot afford this.',
    ['error.cooldown']          = 'You need to wait before doing that.',
    ['error.not_owner']         = 'You do not own this vehicle.',
    ['error.bad_state']         = 'Vehicle is not in a state where that action is allowed.',
    ['error.not_in_vehicle']    = 'You must be in a vehicle.',
    ['error.cannot_store']      = 'This vehicle cannot be stored here.',
    ['success.vehicle_stored']  = 'Vehicle stored.',
    ['success.vehicle_taken']   = 'Vehicle retrieved.',
    ['success.payment']         = 'Paid %s.',
}
