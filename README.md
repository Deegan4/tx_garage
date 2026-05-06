# tx_garage — Modern Garage 2.0

> **The first FiveM garage with valet & impound auctions.** QBCore / QBox / ESX. Multi-language. 0.00ms idle.

![Framework](https://img.shields.io/badge/QBCore%20%7C%20QBox%20%7C%20ESX-supported-ff2d6b)
![Performance](https://img.shields.io/badge/idle-0.00ms-00ffa3)
![Locales](https://img.shields.io/badge/locales-EN%20%7C%20ES-00f0ff)

## ✨ Highlights
- 🛎 **Valet system** — players call a valet, NPC drives their stored vehicle to them
- 🔨 **Impound auction house** — unclaimed impounds go up for player bidding
- 🎨 **Modern Vice-City NUI** — neon, clean, mobile-aware
- 🔒 **Server-authoritative** — every transaction validated, rate-limited
- 🌐 **Multi-language** — English + Spanish out of the box, easy to add more
- ⚡ **0.00ms idle** — no `Wait(0)` loops, uses `ox_target` zones

## 🔥 Features

### Garage core
- Public, Private (rentable), Job, Gang, and Impound garages
- Store / Retrieve / Transfer / Give Key actions
- Persistent vehicle damage, fuel, body, engine, and mods
- Configurable per-garage spawn points and labels
- Map blips with custom sprites/colors

### Valet (unique 🆕)
- Players call a valet from anywhere within configurable range
- Cost, ETA range, cooldown, cancel-with-refund — all configurable
- Valet NPC actually drives the car to the player
- Full database log for analytics & abuse-prevention

### Impound auction (unique 🆕)
- Vehicles unclaimed past `Config.Auction.impoundDays` auto-promote to auction
- Live bidding NUI with min-increment validation
- House cut on every winning bid (configurable economy sink)
- Offline-safe payment — winners debited at auction close, even if disconnected
- Forfeit logic if winner can't cover the bid

### Police integration
- Server event `tx_garage:policeImpound` for tow-truck / cuff-and-tow flows
- Job + grade gated, jobs configurable

## ⚙️ Configurable
Everything ships in `config.lua`. Highlights:
- Garage list (locations, types, spawn points, blips)
- Valet cost, ETA range, cooldown, ped model, max distance
- Auction: impound days, length, increments, house cut %
- Impound costs (base + per-day)
- Notification style (`ox` / `qb` / `esx` / `native`)
- Interaction method (`target` / `marker` / `textui`)

## 📦 Dependencies
- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)
- One of: QBCore, QBox, or ESX
- Optional: `ox_target` (recommended), `LegacyFuel` / `ox_fuel`, `qb-vehiclekeys`

## 🚀 Installation

1. Drop the `tx_garage` folder into `resources/[tx]/`
2. Run `INSTALL.sql` against your server's database (adds 3 columns to `player_vehicles` + 3 new tables — non-destructive)
3. Add to `server.cfg`:
   ```cfg
   ensure tx_garage
   ```
4. Edit `config.lua`:
   - Set `Config.Framework`
   - Customize `Config.Garages` with your map's locations
   - Tune valet/auction economics to your server
5. Restart — done.

## 🛡 Performance
- **Idle resmon**: 0.00ms (no client tick loops)
- **Active resmon (10 players)**: <0.10ms
- Auction processing runs server-side every 60s (configurable)

## 🌐 Languages
- English (`en.lua`)
- Spanish (`es.lua`)
- Drop in `locales/<code>.lua` and set `Config.Locale`

## ❓ FAQ

**Will it conflict with `qb-garages` / `esx_garage`?**
You should disable existing garages. tx_garage uses its own `tx_garage_*` columns on `player_vehicles` so your data is preserved if you switch back.

**What happens if a player wins an auction but disconnects?**
At auction close, we debit them via offline-safe SQL update. If they can't cover, vehicle returns to impound and the auction is marked forfeited.

**Can players abuse the valet for teleportation?**
No. The valet drives the car to your current coordinates with normal driving AI, and the call has a per-player cooldown.

**Does it work with NoPixel-style multi-character?**
Yes — uses `citizenid` (QB) or `identifier` (ESX), not Steam ID.

**Is it escrow-protected?**
Yes. `config.lua`, `locales/`, and `README.md` are escrow-ignored so you can edit those freely. Core logic is locked per Tebex policy.

## 💬 Support
- Discord: [your-discord-invite]
- Tebex tickets on the listing page
- Custom feature requests welcome (priority for premium-tier buyers)

## 📝 Changelog
### 1.0.0 — Initial release
- Core garage system (store/retrieve/transfer/keys)
- Valet system with NPC delivery
- Impound auction house with live bidding
- QBCore + QBox + ESX bridge
- English + Spanish locales
- Modern NUI (Vice City aesthetic)
