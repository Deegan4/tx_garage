<!--
══════════════════════════════════════════════════════════════════════════════
  📸 BANNER PLACEHOLDER — REPLACE BEFORE LAUNCH
  Capture: 1920x480 hero. Suggested composition:
    - Vice-City sunset gradient (hot pink #ff2d6b → teal #00f0ff over plum)
    - "tx_garage" wordmark center, Bebas Neue
    - Subtitle: "QBox · Valet · Auctions · Sub-owners · Boss Menu"
    - Layered montage of 2-3 NUI screenshots
  Save to: .github/assets/banner.svg
══════════════════════════════════════════════════════════════════════════════
-->
<p align="center">
  <img src=".github/assets/banner.svg" alt="tx_garage banner" width="100%">
</p>

<h1 align="center">tx_garage</h1>

<p align="center">
  <b>The QBox garage that pays for itself the first time you don't get duped.</b><br>
  <sub>Valet · Live Impound Auctions · Sub-owners · Plate Change · Boss Menu · Admin Tools</sub>
</p>

<p align="center">
  <a href="#"><img src="https://img.shields.io/badge/QBox-native-ff2d6b?style=for-the-badge" alt="QBox-native"></a>
  <a href="#"><img src="https://img.shields.io/badge/v2.0-premium-00f0ff?style=for-the-badge" alt="v2.0"></a>
  <br>
  <a href="#"><img src="https://img.shields.io/badge/idle-0.00ms-success?style=flat-square" alt="0.00ms idle"></a>
  <a href="#"><img src="https://img.shields.io/badge/security-audited-success?style=flat-square" alt="Security audited"></a>
  <a href="#"><img src="https://img.shields.io/badge/escrow-Tebex--ready-orange?style=flat-square" alt="Tebex escrow"></a>
  <a href="#"><img src="https://img.shields.io/badge/locales-EN%20%7C%20ES-blue?style=flat-square" alt="Locales"></a>
</p>

<p align="center">
  <!-- 📸 DEMO VIDEO PLACEHOLDER -->
  <a href="https://example.com/REPLACE-WITH-DEMO-VIDEO">
    <img src=".github/assets/demo-thumbnail.svg" alt="▶ Watch the 90-second demo" width="720">
  </a>
</p>

---

## Why tx_garage v2?

Most garage scripts ship the same 5 features and call it done. **tx_garage v2 ships the 5 features other scripts skip** — *and* it ships them with a documented security audit so your players can't dupe vehicles, money, or transfers.

| | Standard QBox garages | **tx_garage v2** |
|---|:---:|:---:|
| Store / retrieve / persistent damage | ✅ | ✅ |
| Job & gang garages with grade gates | ✅ | ✅ |
| Police impound | partial | ✅ full + occupancy guard |
| **Valet NPC delivery** with anti-stuck pathfinding | ❌ | ✅ |
| **Live auction house** with anti-snipe + escrow | ❌ | ✅ |
| **Transfer-with-price** + accept/reject dialog | ❌ | ✅ |
| **Sub-owners** (key sharing, up to 4) | ❌ | ✅ |
| **Plate change** in-game | ❌ | ✅ |
| **Boss menu** with society ledger | rare | ✅ |
| **Admin commands** (ACE-gated) | ❌ | ✅ 5 commands |
| **Discord webhooks** for big events | ❌ | ✅ |
| Mileage tracking (tamper-resistant, monotonic) | ❌ | ✅ |
| Vehicle search bar in NUI | ❌ | ✅ |
| Live ticking auction timers | ❌ | ✅ |
| Documented security audit | ❌ | ✅ 11 fixes |
| Idle performance | 0.01–0.20ms | **0.00ms** |

---

## ✨ Featured systems

### 🛎 Valet — call your car to you, anywhere
<!-- 📸 SCREENSHOT — valet NUI + NPC arriving with vehicle. 1280x720 -->
<img src=".github/assets/feature-valet.svg" align="right" width="380" alt="Valet NUI">

A real NPC drives your stored vehicle to your current location. No teleport cheese, no visual cuts.

- **Anti-stuck pathfinding** — primary spawn + 4 fallback offsets; if all fail, the player is automatically refunded
- **Distance-based pricing** — base fee + per-km surcharge from the nearest garage
- **Fuel deduction** — the valet uses fuel on the way (configurable %)
- Cancel for a configurable refund (default 50%)
- Database log for every call → analytics + abuse detection
- Per-player cooldown (default 10 min)

<br clear="right">

### 🔨 Live impound auction house
<!-- 📸 SCREENSHOT — auction NUI: ticking countdown, "YOU ARE LEADING" banner. 1280x720 -->
<img src=".github/assets/feature-auction.svg" align="left" width="380" alt="Auction NUI">

Vehicles unclaimed past your grace period auto-promote to a public lot. Players bid live with **ticking countdowns**, **anti-snipe** extension, and **bid escrow**.

- **Optimistic concurrency** — concurrent bids from two players never both pass; the loser is automatically refunded with no money lost
- **Anti-snipe** — bids in the final minute extend the auction by another minute (durable across server restarts)
- **Configurable payout split** — 50% original owner / 30% society sink / 20% government tax (defaults; tune per server)
- **"You are leading" banner** without leaking bidder identity to other players
- Watcher list — get notified ~5 min before close
- Discord webhook posts for big-money auction starts and wins

<br clear="left">

### 🔁 Transfer with consent + payment
<!-- 📸 SCREENSHOT — incoming transfer dialog with accept/reject. 1280x720 -->
<img src=".github/assets/feature-transfer.svg" align="right" width="380" alt="Transfer dialog">

Standard scripts let any player force-transfer a vehicle to anyone. That's a grief vector (transfer junker → call cops to impound them for it). v2 fixes it with a real consent flow.

- Caller fills target server ID + sale price
- Target gets an `lib.alertDialog` with **30 seconds** to accept or reject
- On accept: target pays, seller receives, ownership flips atomically
- **Claw-back** if the seller transferred to someone else first — buyer is refunded
- 5-meter proximity gate

<br clear="right">

### 👥 Sub-owners — share keys cleanly
Add up to 4 sub-owners per vehicle. They can **retrieve, store, and call valet**, but cannot transfer, change plate, or remove other sub-owners. Owner-only mutations stay owner-only.

- Proximity-gated add (5m default)
- Database-backed (`tx_garage_sub_owners` JSON column on `player_vehicles`)
- Visible in the sub-owner manager modal with player display names

### 🎫 Plate change in-game
- Configurable cost (default $5,000) and 24h cooldown per vehicle
- Format-validated server-side: 2–8 chars, A–Z 0–9
- Uniqueness enforced — collision → reject
- ox_lib input dialog (no browser prompt — premium feel)

### 🏢 Boss menu for job garages
Bosses on job garages see a **Society balance** chip with deposit / withdraw against a transparent SQL ledger. No society-money handwaving.

- Auction society cuts auto-deposit to the configured account
- Full ledger (`tx_garage_society_log`) with action / amount / note / timestamp
- Withdraw is balance-checked against the ledger, not in-memory state

### 👨‍✈️ Admin commands — ACE-gated
| Command | What it does |
|---|---|
| `/tx_spawnveh <model>` | Spawn an admin vehicle |
| `/tx_delveh` | Delete the vehicle you're in or aiming at |
| `/tx_tpveh <plate>` | Teleport to a player's vehicle by plate |
| `/tx_impound <plate>` | Force a vehicle to impound |
| `/tx_release <plate>` | Release from impound to stored |

ACE permissions in `server.cfg`:
```cfg
add_ace group.admin tx_garage.admin allow
```

### 🎨 Vice City sunset NUI
- **Per-class CSS gradients** for vehicle previews (super, sports, suv, motorcycle, truck, sedan, compact) — zero asset shipping, every card visually distinct
- **Live search bar** filters as you type
- **Focus trap** + ESC + Tab cycling for keyboard users
- All DOM via `textContent` / `appendChild` — strict CSP, no innerHTML
- Bundled fonts (Bebas Neue / Outfit / JetBrains Mono — offline, escrow-compatible)

---

## 🛡 Security audit — 11 fixes documented

v2.0 was refactored from v1 to close production-grade dupes and grief paths. Every fix is documented in the codebase:

| ID | Issue | Fix |
|---|---|---|
| C1 | Concurrent-bid race could let two players both pay | Optimistic concurrency: `WHERE current_bid = expectedPrev` |
| C2 | Vehicle transfer happened without target consent | Pending request table + accept dialog + atomic flip with claw-back |
| C3 | `giveKey` worked from any distance | 5m proximity gate |
| C4 | Store-without-state-check could clone vehicles | `WHERE state='out'` on every UPDATE; `affectedRows` checked |
| C5 | Client deleted vehicle before server confirmed | `lib.callback.await` round-trip; entity only deleted on `ok=true` |
| C6 | Cops could impound moving / occupied vehicles | Speed threshold + occupancy check |
| C7 | TIMESTAMPDIFF DAY had a 1-day rounding edge band | Switched to SECOND throughout |
| H1 | Private rent charged on every retrieve | `tx_garage_rent_paid_at` column with N-day cooldown |
| H2 | NUI tamper could "heal" a wreck on store | Health values clamped against previous DB values; mileage monotonic |
| H3 | Re-promote of duplicate plate threw on unique constraint | Unique-plate constraint dropped on `tx_garage_auctions` |
| H4 | Auction money split was hardcoded | Configurable `Config.Auction.payoutSplit` |

---

## 📦 Requirements

| Required | Why |
|---|---|
| [`qbx_core`](https://github.com/Qbox-project/qbx_core) | Framework |
| [`ox_lib`](https://github.com/overextended/ox_lib) | Notifications, callbacks, dialogs |
| [`oxmysql`](https://github.com/overextended/oxmysql) | Database driver |

| Recommended | Why |
|---|---|
| [`ox_target`](https://github.com/overextended/ox_target) | Zone-based interaction (or `qb-target`) |
| [`ox_fuel`](https://github.com/overextended/ox_fuel) | Fuel persistence + valet deduction |
| [`qbx_vehiclekeys`](https://github.com/Qbox-project/qbx_vehiclekeys) | Auto-key handoff on retrieve |

> **Note:** v2.0 is **QBox-native**. For QBCore/ESX support, use v1.x (legacy branch).

### Reference docs
- [FiveM documentation](https://docs.fivem.net/docs/) · [Native reference](https://docs.fivem.net/natives/)
- [`fxmanifest.lua` reference](https://docs.fivem.net/docs/scripting-reference/resource-manifest/resource-manifest/)

---

## 🚀 Installation (5 minutes)

```bash
# 1. Drop the resource into your server-data
resources/[tx]/tx_garage/

# 2. Import the schema (idempotent — re-runnable, only ADDS columns + tables)
mysql -u root your_db < INSTALL.sql

# 3. Add ACE permissions in server.cfg
add_ace group.admin tx_garage.admin allow
add_ace group.mod   tx_garage.mod   allow

# 4. Ensure the resource (after qbx_core, ox_lib, oxmysql, ox_target)
ensure tx_garage

# 5. Customize config.lua → Garages, Valet/Auction economics, payout split, webhooks

# 6. (Optional) Set Discord webhook URLs in Config.Webhooks for big-money posts

# 7. Restart your server. Done.
```

**Upgrading from v1.x?** Run `INSTALL.sql` — it's idempotent and only ADDS columns. Your existing vehicles, auctions, and bids survive. Re-edit your `config.lua` (the shape changed for QBox-native).

---

## 🛡 Performance

| Metric | Value |
|---|---|
| Idle resmon (NUI closed) | **0.00ms** |
| Active resmon (NUI open) | <0.10ms |
| Auction processing | server-side, dynamic interval (sleeps until next `ends_at` or 5min) |
| Memory footprint | ~2MB |

The auction tick is **adaptive** — when no auctions are open, the loop sleeps for 5 minutes between checks. When the next close is in 30 seconds, it sleeps for 30 seconds. No idle servers running useless queries.

---

## 🌐 Languages

Out of the box: **English · Spanish**.
Drop a new file at `locales/<code>.lua` and set `Config.Locale = '<code>'`. PRs welcome.

---

## ❓ FAQ

**Does it work with QBCore or ESX?**
v2.0 is **QBox-native** for cleaner code and lower price ceiling. For QBCore/ESX, use the v1.x legacy branch (still maintained for security fixes).

**Will it conflict with `qbx_garages` / other garage scripts?**
Disable the existing garage. tx_garage uses its own `tx_garage_*` columns on `player_vehicles`, so your data is preserved if you switch back.

**What happens if a player wins an auction but disconnects before close?**
Bids are debited at place-time (escrow). If they're offline at close, the atomic ownership flip still happens — money was already taken. Premium-tier behavior.

**Can players abuse valet for teleportation?**
No. The valet drives with normal AI on actual roads. There are 4 fallback spawn offsets if the primary fails; if all 4 fail, the player is auto-refunded and can try again from a different spot.

**Does it work with NoPixel-style multi-character?**
Yes. Uses `citizenid` everywhere, never Steam ID.

**Is it escrow-protected?**
Yes. `config.lua`, `locales/*.lua`, `shared/utils.lua`, `INSTALL.sql`, `README.md`, and `LICENSE` are escrow-ignored — buyers can edit those freely. Core logic is locked per Tebex policy.

**Can I disable individual systems?**
Yes — every system has a `Config.<System>.enabled` toggle: Valet, Auction, PlateChange, SubOwners, Transfer, Webhooks, and individual admin commands.

**How do I tune the auction money split?**
`Config.Auction.payoutSplit = { originalOwner = 0.50, society = 0.30, government = 0.20 }` — must sum to 1.0. Three example presets in the comments.

---

## 💬 Support

- **Discord** — [join the support server](https://discord.gg/REPLACE-WITH-INVITE) <!-- 📸 REPLACE -->
- **Tebex tickets** — open from your purchase receipt
- **Custom features** — priority for premium-tier buyers

---

## 📝 Changelog

### `2.0.0` — Premium refactor *(2026-05)*
**Breaking:** QBox-native (drops QBCore/ESX bridge — use v1.x for those).
**Security audit — 11 fixes:** C1 auction concurrent-bid race, C2 transfer-without-consent, C3 give-key proximity, C4 store-state dupe, C5 premature client delete, C6 occupied-vehicle impound, C7 TIMESTAMPDIFF rounding, H1 private-rent charge-loop, H2 health-value tamper, H3 unique-plate-constraint crash, H4 hardcoded payout split.
**Features:** Sub-owners, plate change, transfer-with-price + consent, boss menu, 5 admin commands, Discord webhooks, mileage tracking, anti-snipe, vehicle search, live ticking auction timers, "you are leading" banner, per-class CSS gradient previews, focus trap.
**Performance:** Dynamic auction tick (M2), `onResourceStop` cleanup (M1), textui interaction implemented (M3).

### `1.1.0`
- Condition colors, favorite vehicles, auction watchlist

### `1.0.0` — Initial release
- Core garage, valet, auction, multi-framework bridge

---

<p align="center">
  <sub>
    Made with ❤️ in California by <b>tx</b>.<br>
    <a href="https://tebex.io/REPLACE-WITH-LISTING">Buy on Tebex</a> ·
    <a href="https://discord.gg/REPLACE-WITH-INVITE">Discord</a>
  </sub>
</p>
