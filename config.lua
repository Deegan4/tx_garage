--[[
    tx_garage — Configuration
    All gameplay-affecting values live here. Server owners should never need
    to touch the client/ or server/ folders to tune the resource.
]]

Config = {}

-- ─────────────────────────────────────────────────────────────────────
-- General
-- ─────────────────────────────────────────────────────────────────────
Config.Framework      = 'qbcore'      -- 'qbcore' | 'qbox' | 'esx'
Config.Locale         = 'en'          -- see locales/ folder
Config.Debug          = false
Config.Currency       = '$'

-- ─────────────────────────────────────────────────────────────────────
-- Garage types
-- ─────────────────────────────────────────────────────────────────────
Config.GarageTypes = {
    public = {
        label    = 'Public Garage',
        canStore = true,
        cost     = 0,            -- per-store fee (0 = free)
    },
    private = {
        label    = 'Private Garage',
        canStore = true,
        cost     = 50,           -- weekly rental, billed on first use of the week
    },
    job = {
        label    = 'Job Garage',
        canStore = true,
        cost     = 0,
        jobOnly  = true,         -- requires player.PlayerData.job.name match
    },
    gang = {
        label    = 'Gang Garage',
        canStore = true,
        cost     = 0,
        gangOnly = true,
    },
    impound = {
        label    = 'Impound Lot',
        canStore = false,        -- can only retrieve, never store
        cost     = 0,            -- handled by impound logic, not garage cost
    },
}

-- ─────────────────────────────────────────────────────────────────────
-- Garage locations
-- Each entry: { name, type, label, coords, spawn, heading, jobs?, gangs? }
-- ─────────────────────────────────────────────────────────────────────
Config.Garages = {
    {
        name    = 'legion',
        type    = 'public',
        label   = 'Legion Square Garage',
        coords  = vec3(215.74, -810.45, 30.73),
        spawn   = vec4(229.50, -802.13, 30.34, 158.0),
        blip    = { sprite = 357, color = 3, scale = 0.7 },
    },
    {
        name    = 'pillbox',
        type    = 'public',
        label   = 'Pillbox South Garage',
        coords  = vec3(214.55, -797.61, 30.91),
        spawn   = vec4(217.84, -796.74, 30.61, 162.0),
        blip    = { sprite = 357, color = 3, scale = 0.7 },
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
-- Valet system (UNIQUE — not in any competing script as of May 2026)
-- ─────────────────────────────────────────────────────────────────────
Config.Valet = {
    enabled       = true,
    callCost      = 250,                       -- player pays valet to fetch vehicle
    deliveryTime  = { min = 60, max = 120 },   -- seconds, randomized
    maxDistance   = 500.0,                     -- meters from any garage to allow valet call
    cooldown      = 600,                       -- seconds between valet calls per player
    valetPed      = 'a_m_y_business_03',       -- ped model for the valet NPC
    notifyOnArrive = true,
    cancelRefund  = 0.5,                       -- 50% refund if cancelled before delivery
}

-- ─────────────────────────────────────────────────────────────────────
-- Impound auction (UNIQUE — not in any competing script as of May 2026)
-- Vehicles unclaimed after `impoundDays` go to auction, players bid via NUI.
-- ─────────────────────────────────────────────────────────────────────
Config.Auction = {
    enabled        = true,
    impoundDays    = 7,            -- days before unclaimed impound goes to auction
    auctionLength  = 86400,        -- seconds an auction stays open (default 24h)
    minBidIncrement = 100,
    startingBidPercent = 0.10,     -- starting bid = 10% of vehicle value
    auctionLot     = vec3(-310.43, -1486.87, 27.69),
    auctionBlip    = { sprite = 524, color = 5, scale = 0.8 },
    -- Vehicle value resolution: oxmysql players_vehicles.value, fallback to QB shared pricing, fallback to flat
    fallbackValue  = 25000,
    -- Auctioneer takes a cut (% of winning bid) — this is your "house" sink
    houseCutPercent = 0.05,
    -- How long winning bidder has to retrieve vehicle before forfeit
    retrieveWindowHours = 48,
}

-- ─────────────────────────────────────────────────────────────────────
-- Vehicle storage
-- ─────────────────────────────────────────────────────────────────────
Config.Storage = {
    saveOnExit          = true,    -- save vehicle damage/fuel/mods on store
    restoreOnSpawn      = true,    -- restore everything on spawn
    requireKey          = true,    -- only owners (or those given keys) can retrieve
    fuelResource        = 'LegacyFuel',  -- 'LegacyFuel' | 'ox_fuel' | 'ps-fuel' | nil
    keysResource        = nil,           -- nil = use framework default, or 'qb-vehiclekeys' / 'qs-vehiclekeys'
}

-- ─────────────────────────────────────────────────────────────────────
-- Impound cost (regular impound, not auction)
-- ─────────────────────────────────────────────────────────────────────
Config.Impound = {
    baseCost          = 500,
    perDayCost        = 100,           -- additional per day stored
    paymentAccount    = 'cash',        -- 'cash' | 'bank'
    autoImpoundCrash  = false,         -- impound abandoned/crashed vehicles automatically
}

-- ─────────────────────────────────────────────────────────────────────
-- Police-only impound permissions
-- ─────────────────────────────────────────────────────────────────────
Config.PoliceImpound = {
    jobs           = { 'police', 'sheriff', 'sasp' },
    minGrade       = 0,
    radius         = 5.0,
}

-- ─────────────────────────────────────────────────────────────────────
-- Notifications
-- ─────────────────────────────────────────────────────────────────────
Config.Notify = {
    style    = 'ox',          -- 'ox' | 'qb' | 'esx' | 'native'
    duration = 5000,
}

-- ─────────────────────────────────────────────────────────────────────
-- Interaction (how players open garages)
-- ─────────────────────────────────────────────────────────────────────
Config.Interaction = {
    method    = 'target',     -- 'target' | 'marker' | 'textui'
    targetResource = 'ox_target', -- 'ox_target' | 'qb-target'
    markerType = 1,
    markerColor = { r = 255, g = 45, b = 107, a = 100 },  -- Vice City pink
    markerSize = vec3(2.0, 2.0, 0.8),
}
