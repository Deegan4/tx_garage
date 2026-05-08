# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`tx_garage` is a **FiveM resource** — a server-side mod for GTA V multiplayer (CitizenFX/FiveM). It is written in Lua (server + client) and vanilla JS/HTML/CSS (NUI). There is no build step, no package manager, and no test runner. Files are loaded directly by FiveM's cfx runtime in the order declared in `fxmanifest.lua`.

## External docs

When looking up a FiveM/CitizenFX native, fxmanifest field, or scripting runtime behavior, consult the official docs:

- **FiveM documentation**: https://docs.fivem.net/docs/
- **Native reference** (search by name, e.g. `GetVehicleNumberPlateText`): https://docs.fivem.net/natives/
- **`fxmanifest.lua` reference**: https://docs.fivem.net/docs/scripting-reference/resource-manifest/resource-manifest/
- **NUI development**: https://docs.fivem.net/docs/scripting-manual/nui-development/

Prefer these over training-data recall — natives and runtime semantics change between FXServer artifacts.

## Development workflow

**Reload the resource on a live FiveM server:**
```
restart tx_garage
```

**Enable debug output** (prints via `Utils.dbg`):
```lua
-- config.lua
Config.Debug = true
```

**First-time database setup** — run once against the game server's MySQL database:
```
mysql -u <user> -p <db> < INSTALL.sql
```

There is no linter, formatter, or CI configured. Lua style follows the patterns already in the codebase (snake_case locals, PascalCase globals/tables, LuaDoc `---@param` annotations for public functions).

## Script load order

`fxmanifest.lua` controls load order. **Order matters** — later files depend on earlier ones.

**Shared** (both sides): `ox_lib/init.lua` → `shared/utils.lua` → `config.lua` → `locales/*.lua`

**Server**: `oxmysql/lib/MySQL.lua` → `server/main.lua` → `sv_garage.lua` → `sv_valet.lua` → `sv_auction.lua` → `sv_events.lua` → `sv_callbacks.lua`

**Client**: `client/main.lua` → `cl_garage.lua` → `cl_valet.lua` → `cl_auction.lua` → `cl_events.lua`

`server/main.lua` **must load first** on the server — it defines the `Bridge` table that all other server scripts depend on.

## Architecture

### Global tables

| Symbol | Scope | Defined in | Purpose |
|---|---|---|---|
| `Config` | shared | `config.lua` | All gameplay knobs. Server owners should only ever need to edit this file. |
| `Utils` | shared | `shared/utils.lua` | `formatMoney`, `clamp`, `randint`, `dbg`, `dist`, `genPlate` |
| `Locale(key, ...)` | shared | `shared/utils.lua` | Looks up `Locales[Config.Locale][key]`, falls back to key |
| `Locales` | shared | `locales/*.lua` | String tables keyed by locale code (`en`, `es`, …) |
| `Bridge` | server | `server/main.lua` | Framework abstraction — wraps QBCore / QBox / ESX |

### Framework bridge (`server/main.lua`)

All framework calls go through `Bridge.*`. Never call framework internals directly outside this file. Key functions:

- `Bridge.GetPlayer(src)` — returns framework player object
- `Bridge.GetIdentifier(player)` — returns `citizenid` (QB/QBox) or `identifier` (ESX)
- `Bridge.RemoveMoney(src, account, amount)` / `Bridge.AddMoney(...)`
- `Bridge.RemoveMoneyOffline(identifier, account, amount)` — used by auction close to debit disconnected winners
- `Bridge.HasJob(player, jobs)` — job-gate check
- `Bridge.Notify(src, msg, type)` — triggers `tx_garage:notify` client event

### Vehicle state machine

`player_vehicles.tx_garage_state` drives all logic:

```
out  ←──────────────────────────┐
 │  (retrieve/valet deliver)    │ (store)
 ▼                              │
stored ──────────────────────────┘
 │  (police impound)
 ▼
impound  ──(after Config.Auction.impoundDays days, server tick)──▶  auction
 ▲              │ (auction close — bidder pays)
 │              ▼
 └──────────  back to impound under new owner
```

Columns added to `player_vehicles`: `tx_garage_state`, `tx_garage_name` (which garage), `tx_garage_impounded_at`.

### Server-authoritative pattern

The server **always** re-validates ownership and funds before acting. The client sends plates and server IDs only — never raw identifiers. See the comment in `sv_garage.lua:transferVehicle` for why `targetServerId` is server-scoped.

Every sensitive net event has a per-player cooldown via the `isOnCooldown(src, key, seconds)` helper in `sv_garage.lua`. Valet has its own `valetCooldowns` table in `sv_valet.lua`.

### Config sent to clients

`sv_callbacks.lua` registers `tx_garage:getConfig` which strips server-only fields before returning config to the client. Client code calls this once on load and caches it via `GetClientConfig()` (defined in `client/main.lua`). Never read `Config.*` auction internals on the client — use `GetClientConfig().Auction`.

### NUI communication

- **Lua → NUI**: `SendNUIMessage({ action = '...', ... })`
- **NUI → Lua**: `nuiPost('namespace/action', data)` in JS calls `RegisterNUICallback('namespace/action', fn)` in Lua
- **Server → all clients** (auction bids): `TriggerClientEvent('tx_garage:auctionUpdate', -1, ...)` — only bid amount is broadcast, never the bidder's identifier

### Auction tick

`sv_auction.lua` runs a `CreateThread` loop every `AUCTION_TICK_SECONDS` (60s) that:
1. Promotes overdue impounds (`promoteOverdueImpounds`) into `tx_garage_auctions`
2. Closes expired auctions (`closeExpiredAuctions`), debiting winners offline-safe or forfeiting

### Interaction methods

`Config.Interaction.method` switches between three modes handled in `client/main.lua`:
- `'target'` — registers `ox_target` box zones (default, 0.00ms idle)
- `'marker'` — draws 3D markers each frame (**not yet implemented** — the switch case is a stub)
- `'textui'` — proximity text UI

## qb-vehiclekeys integration

`qb-vehiclekeys` runs alongside tx_garage on the server (ensured before tx_garage in `server.cfg`). When a player retrieves a vehicle from a garage or valet delivers one, tx_garage should trigger key handoff via:

```lua
TriggerEvent('qb-vehiclekeys:server:GiveKeys', src, plate)
```

Keys are automatically removed when a vehicle is stored back. Do not give keys on impound.

## NUI development

NUI-only changes (HTML/CSS/JS in `nui/`) do not require a resource restart. In-game, close and reopen the NUI panel. For faster iteration, open `nui/index.html` directly in a browser and mock `window.invokeNative` / the `message` event listener.

## Escrow policy

In production (Tebex), only these files are **not** escrow-locked:
- `config.lua`
- `locales/*.lua`
- `shared/utils.lua`
- `README.md`, `INSTALL.sql`

Core logic in `server/`, `client/`, and `nui/` is locked. Changes to those files work in development but won't ship through Tebex escrow without a new escrow submission.

## Adding a new locale

1. Copy `locales/en.lua` to `locales/<code>.lua`
2. Replace all string values (keep keys identical)
3. Set `Config.Locale = '<code>'` in `config.lua`

## Adding a new garage

Add an entry to `Config.Garages` in `config.lua`. No code changes needed — client/server iterate this table dynamically.
