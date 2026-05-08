-- tx_garage — Spanish strings
Locales = Locales or {}

Locales.es = {
    -- Garage UI
    ['ui.garage.title']        = 'Garaje',
    ['ui.garage.empty']        = 'No hay vehículos guardados.',
    ['ui.garage.retrieve']     = 'Sacar',
    ['ui.garage.store']        = 'Guardar',
    ['ui.garage.transfer']     = 'Transferir',
    ['ui.garage.givekey']      = 'Dar Llave',
    ['ui.garage.fuel']         = 'Combustible',
    ['ui.garage.body']         = 'Carrocería',
    ['ui.garage.engine']       = 'Motor',

    -- Valet
    ['valet.call']             = 'Llamar al Valet',
    ['valet.requested']        = 'Valet en camino — ETA %ds.',
    ['valet.arrived']          = 'Tu valet ha llegado.',
    ['valet.cancelled']        = 'Valet cancelado. Reembolso %s.',
    ['valet.cooldown']         = 'Podrás llamar otro valet en %ds.',
    ['valet.too_far']          = 'Debes estar a menos de %dm de un garaje para llamar a un valet.',
    ['valet.not_enough_money'] = 'No puedes pagar el valet (costo: %s).',

    -- Impound / Auction
    ['impound.title']          = 'Depósito de Vehículos',
    ['impound.cost']           = 'Costo de Retiro',
    ['auction.title']          = 'Subasta de Depósito',
    ['auction.bid']            = 'Hacer Oferta',
    ['auction.current_bid']    = 'Oferta actual: %s',
    ['auction.min_bid']        = 'Oferta mínima siguiente: %s',
    ['auction.bid_too_low']    = 'La oferta debe ser al menos %s.',
    ['auction.outbid']         = 'Te superaron en %s. Nueva oferta: %s',
    ['auction.won']            = 'Ganaste la subasta de %s por %s.',
    ['auction.retrieve_window'] = 'Retira en %d horas o pierdes el vehículo.',
    ['auction.no_money']       = 'No puedes cubrir esta oferta.',

    -- General
    ['error.no_permission']    = 'No tienes permiso.',
    ['error.no_money']         = 'No puedes pagar esto.',
    ['error.cooldown']         = 'Necesitas esperar antes de hacer eso.',
    ['error.not_owner']        = 'No eres el dueño de este vehículo.',
    ['success.vehicle_stored'] = 'Vehículo guardado.',
    ['success.vehicle_taken']  = 'Vehículo retirado.',
    ['success.payment']        = 'Pagaste %s.',
}
