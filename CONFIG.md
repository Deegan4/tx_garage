# Configuration reference

Every option in `config.lua`, with defaults, recommended values, and gotchas.

> All values shown are the v2.0.0 defaults. Re-read this doc after upgrading — the shape changes between major versions.

---

## General

```lua
Config.Locale       = 'en'      -- 'en' | 'es' | <your code>
Config.Debug        = false     -- prints Utils.dbg messages to console
Config.Currency     = '$'       -- prefix on every money display
Config.ResourceName = 'tx_garage'  -- used for NUI fetch URL & money sources
```

`Config.Debug = true` enables `Utils.dbg(...)` output. Production servers should leave this `false`.

---

## Garage types

`Config.GarageTypes` defines behaviors. Adding a new type here adds it everywhere — you can then reference it by name from `Config.Garages` entries.

```lua
Config.GarageTypes = {
    public  = { label = 'Public Garage',  canStore = true, cost = 0 },
    private = { label = 'Private Garage', canStore = true, cost = 50, rentDays = 7 },
    job     = { label = 'Job Garage',     canStore = true, cost = 0, jobOnly = true, bossMenu = true },
    gang    = { label = 'Gang Garage',    canStore = true, cost = 0, gangOnly = true },
    impound = { label = 'Impound Lot',    canStore = false, cost = 0 },
    vip     = { label = 'VIP Garage',     canStore = true, cost = 0, aceCheck = 'tx_garage.vip' },
}
```

| Field | Meaning |
|---|---|
| `canStore` | `false` for impound only — players can retrieve but not store |
| `cost` | Per-store fee, or weekly rent for private |
| `rentDays` | (private only) days between rent charges |
| `jobOnly` | Player's job must be in the garage's `jobs` list |
| `gangOnly` | Player's gang must be in the garage's `gangs` list |
| `bossMenu` | (job only) shows boss menu button if player has `job.grade.isboss` |
| `aceCheck` | (vip only) ACE permission required to access |

---

## Garage locations

Each entry in `Config.Garages` is a placed garage in the world.

```lua
{
    name    = 'legion',                          -- unique id, referenced in DB
    type    = 'public',                          -- key in Config.GarageTypes
    label   = 'Legion Square Garage',
    coords  = vec3(215.74, -810.45, 30.73),     -- ped interaction point
    spawn   = vec4(229.50, -802.13, 30.34, 158.0),  -- vehicle spawn (x, y, z, heading)
    blip    = { sprite = 357, color = 3, scale = 0.7 },  -- nil = no blip
    -- Optional, type-dependent:
    jobs    = { 'police', 'sheriff' },          -- type='job'
    gangs   = { 'ballas' },                      -- type='gang'
    society = 'police',                          -- which society account gets cuts
}
```

> **Tip:** add as many entries as you want. The blip + ox_target zone are auto-created on resource start, and cleaned up on resource stop.

---

## Valet

```lua
Config.Valet = {
    enabled        = true,
    callCost       = 250,                          -- base fee
    pricePerKm     = 25,                           -- + per-km surcharge from nearest garage
    deliveryTime   = { min = 60, max = 120 },     -- ETA range, randomized per call
    maxDistance    = 500.0,                        -- meters — must be within range of any garage
    cooldown       = 600,                          -- seconds between valet calls per player
    valetPed       = 'a_m_y_business_03',
    cancelRefund   = 0.5,                          -- 50% refund if cancelled before delivery
    fuelDeduction  = 5.0,                          -- fuel % consumed during delivery
    fallbackOffsets = { ... },                     -- vec3 list of retry spawn offsets
}
```

The valet drives an actual NPC-driven vehicle on roads. If pathfinding fails, `findValetSpawn` tries each fallback offset; if all fail, the player is auto-refunded via `tx_garage:valetPathFailed`.

---

## Auction

```lua
Config.Auction = {
    enabled             = true,
    impoundDays         = 7,            -- days before unclaimed impound auctions
    auctionLength       = 86400,        -- seconds (24h)
    minBidIncrement     = 100,
    startingBidPercent  = 0.10,         -- 10% of vehicle value
    auctionLot          = vec3(...),
    auctionBlip         = { sprite = 524, color = 5, scale = 0.8 },
    fallbackValue       = 25000,        -- when DB has no value column
    valueColumn         = 'depvalue',   -- column on player_vehicles for value
    retrieveWindowHours = 48,           -- hours winner has to retrieve

    -- Where the winning bid money goes. Must sum to 1.0.
    payoutSplit = {
        originalOwner = 0.50,
        society       = 0.30,
        government    = 0.20,           -- consumed by sink (no recipient)
    },
    societyAccount = 'police',          -- who gets the society cut

    -- Anti-snipe: if a bid lands in the last N seconds, extend by M seconds.
    antiSnipeSeconds = 60,
    antiSnipeExtend  = 60,
}
```

### Payout split presets

| Preset | Owner / Society / Sink | Vibe |
|---|---|---|
| **50 / 30 / 20** *(default)* | Tempered penalty — owner gets something back | Heavy-RP servers |
| **0 / 50 / 50** | Hard penalty — careless owners lose everything | PvP / hardcore |
| **0 / 0 / 100** | Pure money sink | Servers fighting inflation |

Must sum to 1.0. Floor-rounding leftovers go to the sink.

---

## Vehicle storage

```lua
Config.Storage = {
    saveOnExit       = true,
    restoreOnSpawn   = true,
    requireKey       = true,
    fuelResource     = 'ox_fuel',         -- 'ox_fuel' | 'LegacyFuel' | 'ps-fuel' | nil
    keysResource     = 'qbx_vehiclekeys', -- 'qbx_vehiclekeys' | 'qb-vehiclekeys' | 'qs-vehiclekeys' | nil
    maxStoreFuel     = 100,
    maxStoreEngine   = 1000,
    maxStoreBody     = 1000,
}
```

`maxStore*` values are the H2 fix — health values from the client are clamped against these AND against the previous DB value, whichever is lower. Players cannot heal a wreck by storing it.

---

## Plate change

```lua
Config.PlateChange = {
    enabled  = true,
    cost     = 5000,
    account  = 'bank',
    cooldown = 86400,                -- seconds (24h per vehicle)
    pattern  = '^[A-Z0-9]+$',
    minLen   = 2,
    maxLen   = 8,
}
```

The cooldown is enforced **per-vehicle** via the `tx_garage_plate_changed_at` column. A player who owns 5 cars can change all 5 plates simultaneously, but can't change the same plate twice in 24h.

---

## Sub-owners

```lua
Config.SubOwners = {
    enabled          = true,
    maxPerVehicle    = 4,
    requireProximity = 5.0,   -- meters
}
```

Sub-owners can: retrieve, store, valet.
Sub-owners cannot: transfer, change plate, remove other sub-owners.

---

## Transfer

```lua
Config.Transfer = {
    enabled          = true,
    requireProximity = 5.0,
    requestTimeout   = 30,    -- seconds the target has to accept
    minPrice         = 0,
    maxPrice         = 5000000,
}
```

Set `minPrice = 0` to allow gifts. Set `maxPrice` to whatever your economy can handle.

---

## Impound (regular, not auction)

```lua
Config.Impound = {
    baseCost       = 500,
    perDayCost     = 100,
    paymentAccount = 'cash',
    speedThreshold = 1.0,            -- m/s
    requireStopped = true,           -- C6 fix
}

Config.PoliceImpound = {
    jobs     = { 'police', 'sheriff', 'sasp' },
    minGrade = 0,
    radius   = 5.0,
}
```

`speedThreshold` is the C6 fix — cops can't impound moving vehicles. Also can't impound occupied ones (server checks the driver seat).

---

## Notifications

```lua
Config.Notify = {
    style    = 'ox',          -- 'ox' | 'native'
    duration = 5000,
    position = 'top-right',
}
```

QBox servers should leave `style = 'ox'`.

---

## Interaction

```lua
Config.Interaction = {
    method         = 'target',    -- 'target' | 'textui'
    targetResource = 'ox_target', -- 'ox_target' | 'qb-target'
    drawDistance   = 6.0,
}
```

`textui` shows a `[E] Open Garage` prompt when near a garage and triggers on E press. Use this if your server doesn't run a target script.

---

## Discord webhooks

```lua
Config.Webhooks = {
    enabled = false,
    auctionStart = { url = '', minValue = 50000 },
    auctionWon   = { url = '', minBid   = 100000 },
    bigImpound   = { url = '', minValue = 100000 },
    transfers    = { url = '', minPrice = 50000 },
    botName      = 'tx_garage',
    botAvatar    = 'https://i.imgur.com/8MpDJBh.png',
    color        = 16722283,         -- Vice City pink (decimal)
}
```

Empty `url` disables that hook silently. The min-value thresholds prevent webhook spam from low-value events.

---

## Admin

```lua
Config.Admin = {
    aceAdmin = 'tx_garage.admin',
    aceMod   = 'tx_garage.mod',
    enableSpawnCommand    = true,
    enableDeleteCommand   = true,
    enableTeleportCommand = true,
    enableImpoundCommand  = true,
    enableReleaseCommand  = true,
}
```

Toggle commands off if you don't want admins to have them. Available commands:

| Command | Required ACE |
|---|---|
| `/tx_spawnveh <model>` | `tx_garage.admin` |
| `/tx_delveh` | `tx_garage.admin` |
| `/tx_tpveh <plate>` | `tx_garage.admin` |
| `/tx_impound <plate>` | `tx_garage.admin` |
| `/tx_release <plate>` | `tx_garage.admin` |

---

## Adding a new garage at a fixed location

```lua
table.insert(Config.Garages, {
    name   = 'paleto_pd',
    type   = 'job',
    label  = 'Paleto Bay PD Garage',
    coords = vec3(-446.41, 6014.36, 31.71),
    spawn  = vec4(-453.61, 6014.16, 31.34, 250.0),
    blip   = { sprite = 357, color = 38 },
    jobs   = { 'police' },
    society = 'police',
})
```

No code changes needed. Restart `tx_garage` to pick up the new entry.

---

## Adding a new locale

1. Copy `locales/en.lua` to `locales/<code>.lua`.
2. Translate every value (keep the keys identical).
3. Set `Config.Locale = '<code>'`.
4. Restart.

The locale file is loaded by `fxmanifest.lua` via the `locales/*.lua` glob — no manifest edit required.

---

## Reading the current state from another resource

tx_garage exports:

```lua
exports.tx_garage:Notify(msg, type)        -- show a notification
exports.tx_garage:PoliceImpound(vehEntity) -- impound the given vehicle (job-gated server-side)
```

Server-side, you can also trigger events directly — but they all enforce ownership/permission server-side, so external callers must respect the same model.
