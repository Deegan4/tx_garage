--[[
    tx_garage v2.0 — Configuration
    ───────────────────────────────────────────────────────────────────────────
    All gameplay-affecting values live here. Server owners should never need to
    touch the client/ or server/ folders to tune the resource.

    QBox-native build. Requires:
      • qbx_core
      • ox_lib
      • oxmysql
      • ox_target  (or qb-target via Config.Interaction.targetResource)

    For ACE permissions in server.cfg:
      add_ace group.admin tx_garage.admin allow
      add_ace group.mod   tx_garage.mod   allow
]]

Config = {}

-- ─────────────────────────────────────────────────────────────────────
-- General
-- ─────────────────────────────────────────────────────────────────────
Config.Locale         = 'en'
Config.Debug          = false
Config.Currency       = '$'
Config.ResourceName   = 'tx_garage'  -- used for NUI fetch URL & money sources

-- ─────────────────────────────────────────────────────────────────────
-- Garage types — defines behavior, not locations
-- ─────────────────────────────────────────────────────────────────────
Config.GarageTypes = {
    public = {
        label    = 'Public Garage',
        canStore = true,
        cost     = 0,
    },
    private = {
        label    = 'Private Garage',
        canStore = true,
        cost     = 50,           -- weekly rental, billed once per 7d
        rentDays = 7,
    },
    job = {
        label    = 'Job Garage',
        canStore = true,
        cost     = 0,
        jobOnly  = true,
        bossMenu = true,         -- show boss menu for job grade.isboss
    },
    gang = {
        label    = 'Gang Garage',
        canStore = true,
        cost     = 0,
        gangOnly = true,
    },
    impound = {
        label    = 'Impound Lot',
        canStore = false,
        cost     = 0,            -- handled by Config.Impound below
    },
    vip = {
        label    = 'VIP Garage',
        canStore = true,
        cost     = 0,
        aceCheck = 'tx_garage.vip',  -- requires ACE permission
    },
}

-- ─────────────────────────────────────────────────────────────────────
-- Garage locations
-- ─────────────────────────────────────────────────────────────────────
-- Each entry:
--   name     unique string id (referenced in DB)
--   type     key in Config.GarageTypes
--   label    UI label
--   coords   vec3  ped interaction point
--   spawn    vec4  vehicle spawn (x, y, z, heading)
--   blip     { sprite, color, scale } or nil
--   jobs     { 'police', ... }  required for type='job'
--   gangs    { 'ballas', ... }  required for type='gang'
--   society  string  job/gang society account name (e.g. 'police')
-- ─────────────────────────────────────────────────────────────────────
Config.Garages = {
    {
        name   = 'legion',
        type   = 'public',
        label  = 'Legion Square Garage',
        coords = vec3(215.74, -810.45, 30.73),
        spawn  = vec4(229.50, -802.13, 30.34, 158.0),
        blip   = { sprite = 357, color = 3, scale = 0.7 },
    },
    {
        name   = 'pillbox',
        type   = 'public',
        label  = 'Pillbox South Garage',
        coords = vec3(214.55, -797.61, 30.91),
        spawn  = vec4(217.84, -796.74, 30.61, 162.0),
        blip   = { sprite = 357, color = 3, scale = 0.7 },
    },
    {
        name   = 'sandy_pd_garage',
        type   = 'job',
        label  = 'Sandy Shores PD Garage',
        coords = vec3(1854.79, 3683.60, 34.27),
        spawn  = vec4(1862.75, 3680.19, 33.74, 209.0),
        blip   = { sprite = 357, color = 38, scale = 0.7 },
        jobs   = { 'police', 'sheriff' },
        society = 'police',
    },
    {
        name    = 'mrpd_impound',
        type    = 'impound',
        label   = 'MRPD Impound Lot',
        coords  = vec3(409.52, -1623.27, 29.29),
        spawn   = vec4(404.71, -1622.94, 29.29, 230.0),
        blip    = { sprite = 68, color = 1, scale = 0.7 },
    },
}

-- ─────────────────────────────────────────────────────────────────────
-- Valet system — call your vehicle from anywhere within range
-- ─────────────────────────────────────────────────────────────────────
Config.Valet = {
    enabled        = true,
    callCost       = 250,                       -- base fee
    pricePerKm     = 25,                        -- distance surcharge
    deliveryTime   = { min = 60, max = 120 },   -- seconds, randomized
    maxDistance    = 500.0,                     -- meters from any garage
    cooldown       = 600,                       -- seconds between calls
    valetPed       = 'a_m_y_business_03',
    cancelRefund   = 0.5,                       -- 50% refund if cancelled before delivery
    fuelDeduction  = 5.0,                       -- fuel % consumed during delivery
    -- If the valet path is blocked, retry from these candidate offsets (relative to player)
    fallbackOffsets = {
        vec3(25.0, 25.0, 0.0),
        vec3(-25.0, 25.0, 0.0),
        vec3(25.0, -25.0, 0.0),
        vec3(-25.0, -25.0, 0.0),
    },
}

-- ─────────────────────────────────────────────────────────────────────
-- Impound auction — unclaimed impounds go to live bid auction
-- ─────────────────────────────────────────────────────────────────────
Config.Auction = {
    enabled             = true,
    impoundDays         = 7,                                              -- days before unclaimed impound auctions
    auctionLength       = 86400,                                          -- seconds an auction stays open (24h)
    minBidIncrement     = 100,
    startingBidPercent  = 0.10,                                           -- starting bid = 10% of vehicle value
    auctionLot          = vec3(-310.43, -1486.87, 27.69),
    auctionBlip         = { sprite = 524, color = 5, scale = 0.8 },
    fallbackValue       = 25000,                                          -- when DB has no value column
    valueColumn         = 'depvalue',                                     -- column on player_vehicles for vehicle value
    retrieveWindowHours = 48,                                             -- hours winner has to retrieve before forfeit

    -- Where the winning bid money goes. Must sum to 1.0 (100%).
    -- Default: 50% to original owner (tempers grief), 30% to society sink, 20% gov tax.
    payoutSplit = {
        originalOwner = 0.50,
        society       = 0.30,    -- deposited into Config.Auction.societyAccount
        government    = 0.20,    -- consumed by sink (no recipient — money out of economy)
    },
    societyAccount   = 'police',     -- who gets the society cut

    -- Anti-snipe: if a bid lands in the last `antiSnipeSeconds` seconds, extend by `antiSnipeExtend`.
    antiSnipeSeconds = 60,
    antiSnipeExtend  = 60,
}

-- ─────────────────────────────────────────────────────────────────────
-- Vehicle storage
-- ─────────────────────────────────────────────────────────────────────
Config.Storage = {
    saveOnExit       = true,        -- save damage/fuel/mods/mileage on store
    restoreOnSpawn   = true,
    requireKey       = true,
    fuelResource     = 'ox_fuel',
    keysResource     = 'qbx_vehiclekeys',
    -- Hard cap on stored vehicle health (prevents NUI tamper from "healing" a wreck)
    maxStoreFuel     = 100,
    maxStoreEngine   = 1000,
    maxStoreBody     = 1000,
}

-- ─────────────────────────────────────────────────────────────────────
-- Plate change service
-- ─────────────────────────────────────────────────────────────────────
Config.PlateChange = {
    enabled  = true,
    cost     = 5000,
    account  = 'bank',
    cooldown = 86400,        -- seconds; once per day per vehicle
    -- Plate format: 8 chars, A-Z 0-9. Server validates server-side.
    pattern  = '^[A-Z0-9]+$',
    minLen   = 2,
    maxLen   = 8,
}

-- ─────────────────────────────────────────────────────────────────────
-- Sub-owner / key sharing
-- ─────────────────────────────────────────────────────────────────────
Config.SubOwners = {
    enabled        = true,
    maxPerVehicle  = 4,
    requireProximity = 5.0,   -- target must be within X meters to add as sub-owner
    -- Sub-owners can: retrieve, store, valet. Cannot: transfer, change plate, remove other sub-owners.
}

-- ─────────────────────────────────────────────────────────────────────
-- Vehicle transfer (consent-required ownership change)
-- ─────────────────────────────────────────────────────────────────────
Config.Transfer = {
    enabled         = true,
    requireProximity = 5.0,   -- meters
    requestTimeout   = 30,    -- seconds the target has to accept
    minPrice        = 0,
    maxPrice        = 5000000,
}

-- ─────────────────────────────────────────────────────────────────────
-- Regular impound (police-issued, not auction)
-- ─────────────────────────────────────────────────────────────────────
Config.Impound = {
    baseCost       = 500,
    perDayCost     = 100,
    paymentAccount = 'cash',
    -- Vehicle must be unoccupied & stationary (speed < threshold) to be impounded
    speedThreshold = 1.0,         -- m/s
    requireStopped = true,
}

Config.PoliceImpound = {
    jobs     = { 'police', 'sheriff', 'sasp' },
    minGrade = 0,
    radius   = 5.0,
}

-- ─────────────────────────────────────────────────────────────────────
-- Notifications (uses ox_lib by default — recommended for QBox)
-- ─────────────────────────────────────────────────────────────────────
Config.Notify = {
    style    = 'ox',          -- 'ox' | 'native'
    duration = 5000,
    position = 'top-right',
}

-- ─────────────────────────────────────────────────────────────────────
-- Interaction
-- ─────────────────────────────────────────────────────────────────────
Config.Interaction = {
    method         = 'target',          -- 'target' | 'textui'
    targetResource = 'ox_target',       -- 'ox_target' | 'qb-target'
    drawDistance   = 6.0,
}

-- ─────────────────────────────────────────────────────────────────────
-- Discord webhooks (optional — leave url empty to disable)
-- ─────────────────────────────────────────────────────────────────────
Config.Webhooks = {
    enabled = false,
    auctionStart = { url = '', minValue = 50000 },   -- only post if vehicle value >= minValue
    auctionWon   = { url = '', minBid = 100000 },
    bigImpound   = { url = '', minValue = 100000 },
    transfers    = { url = '', minPrice = 50000 },
    botName      = 'tx_garage',
    botAvatar    = 'https://i.imgur.com/8MpDJBh.png',
    color        = 16722283,            -- Vice City pink in decimal
}

-- ─────────────────────────────────────────────────────────────────────
-- Admin commands (gated by ACE permissions)
-- ─────────────────────────────────────────────────────────────────────
Config.Admin = {
    -- ACE permission keys
    aceAdmin = 'tx_garage.admin',     -- spawn/delete/teleport vehicles
    aceMod   = 'tx_garage.mod',       -- view-only / debug
    -- Commands
    enableSpawnCommand    = true,     -- /tx_spawnveh <model>
    enableDeleteCommand   = true,     -- /tx_delveh
    enableTeleportCommand = true,     -- /tx_tpveh <plate>
    enableImpoundCommand  = true,     -- /tx_impound <plate>
    enableReleaseCommand  = true,     -- /tx_release <plate>
}
