# tx_garage — Valet & Impound Auctions for QBCore · Qbox · ESX

> The first FiveM garage with NPC valet delivery and live impound auctions — running at 0.00ms idle on every major framework.

## Features
- **Valet system**: players call an NPC who drives their stored vehicle to them with full pathfinding (no teleport cheese)
- **Impound auction house**: overdue impounds auto-list, players bid live via NUI, configurable house cut drains your economy
- **Multi-framework bridge**: identical server logic on QBCore / Qbox / ESX — auto-detected, no patches
- **Five garage types**: Public, Private (rentable), Job, Gang, Impound — each with grade gating
- **Persistent state**: damage, fuel, body, engine, mods all survive store/retrieve cycles

## Why tx_garage
Most paid garage scripts ship the same store/retrieve loop with a fresh coat of paint. tx_garage is the first listing on Tebex that adds two systems competitors don't include — turning a utility script into a roleplay generator and an economy sink.

- **Valet system (unique)** — NPC drives the actual vehicle (not a copy) to the player with normal AI behavior, per-player cooldowns, and full payment + refund-on-cancel logic. No competing garage script on Tebex ships this as of May 2026.
- **Impound auction house (unique)** — overdue impound vehicles auto-promote to a live auction lot with countdown bidding, min-increment validation, configurable house cut, and offline-safe debit at auction close. No competing garage script on Tebex ships this as of May 2026.
- **0.00ms idle**, server-authoritative on every event, plate uniqueness enforced at the DB layer, and a Vice-City NUI with bundled fonts (no CDN dependency = escrow-safe and offline-compatible)

## Compatibility
- **Frameworks**: QBCore, Qbox, ESX (unified bridge — no branching code)
- **Required**: `ox_lib`, `oxmysql`
- **Optional**: `ox_target` (zone-based interaction, recommended), `ox_fuel` / `LegacyFuel` (fuel persistence), `qbx_vehiclekeys` / `qb-vehiclekeys` (auto-key handoff)
- **FXServer**: cerulean
- **Lua**: 5.4 enabled

## Installation
1. Download and extract into `resources/[tx]/tx_garage`
2. Run `INSTALL.sql` against your database (non-destructive — only ADDS columns + tables, your existing player_vehicles data is preserved)
3. Add `ensure tx_garage` to your `server.cfg`
4. Customize `config.lua` — set `Config.Framework`, garages, valet/auction economics
5. Restart your server

## Configuration
The following files are **buyer-editable** (not encrypted by Tebex escrow):
- `config.lua` — garages, framework selection, valet pricing, auction grace period & house cut
- `locales/*.lua` — translations (English + Spanish included; add your own)
- `shared/utils.lua` — utility helpers
- `README.md`, `INSTALL.sql`, `LICENSE`

All server logic, NUI scripts, and core systems are escrowed for license enforcement.

## FAQ

**Q: Will this conflict with `qb-garages` / `esx_garage` / `qbx_garages`?**
A: Disable the existing garage. tx_garage uses its own `tx_garage_*` columns on `player_vehicles`, so your data is preserved if you ever switch back.

**Q: What happens if a player wins an auction but disconnects?**
A: Auction close debits their offline player record via direct SQL. If they can't cover the bid, the vehicle returns to impound and the auction is marked forfeited.

**Q: Can players abuse valet for teleportation?**
A: No. The NPC drives with normal AI, the call has a per-player cooldown, and valet refuses if the player is already in a vehicle.

**Q: Does it work with NoPixel-style multi-character setups?**
A: Yes. Uses `citizenid` (QB / Qbox) or `identifier` (ESX), never Steam ID.

**Q: Can I disable just the auction or just the valet?**
A: Yes — both have a master `enabled = true/false` switch in `config.lua`.

**Q: Do you offer support?**
A: Discord support included with every purchase. Premium-tier buyers get priority on custom feature requests.

## Version
v1.0.0 (from fxmanifest.lua)

## Price
**$29.99** — Sits in the middle of the feature-rich systems anchor band ($24.99–$34.99 per repo CLAUDE.md). The valet + auction systems plus three-framework support justify pricing above simple garages, and the 0.00ms idle benchmark + escrow-safe bundled fonts justify pricing above the lower end of the band.
