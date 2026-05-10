# Changelog

All notable changes to tx_garage are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning follows [SemVer](https://semver.org/).

---

## [2.0.0] — 2026-05-10

### ⚠ Breaking changes
- **Framework support narrowed to QBox-native.** The multi-framework `Bridge` table was removed. For QBCore/ESX, use the `1.x` branch (still receiving security backports).
- `Config` shape rewritten — server owners must re-edit `config.lua` after upgrade. The new keys are not backwards-compatible with v1.x configs.
- Net event names retained (`tx_garage:*`); resources listening on them keep working.
- DB schema is **additive only** — v1 data (vehicles, auctions, bids) survives the upgrade. Run `INSTALL.sql` to add the new columns/tables.

### Security audit — 16 fixes
**Critical (production dupe / grief paths):**
- **C1** Auction concurrent-bid race could let two players both pay; loser wasn't refunded. Fixed via optimistic concurrency (`UPDATE … WHERE current_bid = expectedPrev`).
- **C2** Vehicle transfer worked without target consent (grief vector: junker-then-call-cops). Fixed via pending-request table + `lib.alertDialog` accept/reject + 30s expiry.
- **C3** `giveKey` worked from any distance. Fixed with 5m proximity gate.
- **C4** Store-without-state-check could clone vehicles. Fixed with `WHERE state='out'` on every UPDATE; checks `affectedRows`.
- **C5** Client deleted vehicle entity before server confirmed storage. Fixed by converting store/retrieve to `lib.callback.await` round-trips; entity only deleted on `{ok=true}`.
- **C6** Police could impound moving / occupied vehicles. Fixed with seat occupancy check + speed threshold.
- **C7** `TIMESTAMPDIFF DAY` had a 1-day rounding edge band. Fixed by switching to `SECOND` math throughout.

**High (logic / money):**
- **H1** Private garage charged rent on every retrieve. Fixed with `tx_garage_rent_paid_at` column + N-day cooldown.
- **H2** NUI tamper could "heal" a wreck on store. Fixed by clamping health values against previous DB values; mileage made monotonic.
- **H3** Re-promote of duplicate plate threw on unique constraint. Fixed by dropping the legacy `ux_plate` constraint on `tx_garage_auctions`.
- **H4** Auction money split was hardcoded. Fixed with configurable `Config.Auction.payoutSplit`.

**From pre-listing review:**
- **F1** *(BLOCK)* Transfer claw-back duped money — seller was credited before the atomic ownership flip. Fixed by reordering: debit buyer → atomic flip → pay seller only on success. Also made online-aware so seller payout fires `qbx_core` events when they're connected.
- **F2** `RemoveMoneyOffline` / `AddMoneyOffline` could race a connected player's auto-save. Fixed by routing through `Garage.RemoveMoney`/`AddMoney` when `GetSrcByCid` resolves.
- **F3** `Config.PlateChange.cooldown` (24h) was declared but unenforced. Fixed by adding `tx_garage_plate_changed_at` column and per-vehicle TIMESTAMPDIFF gate.
- **F4** Boss withdraw read-then-write race could double-spend society funds. Fixed with single atomic `INSERT...SELECT WHERE balance >= ?` statement.
- **F5** Debug `print()` left in client/main.lua. Replaced with `Utils.dbg`.

### Added
- **Sub-owners** — up to 4 per vehicle; can retrieve/store/valet but not transfer/plate-change. Proximity-gated add. JSON column on `player_vehicles`.
- **Plate change** — in-game, configurable cost (default $5,000) + 24h per-vehicle cooldown + format validation (2–8 chars, A–Z 0–9).
- **Transfer with price** — sale flow with seller-set price, target accepts/rejects via `lib.alertDialog`, atomic ownership flip with refund-on-race.
- **Boss menu** — society balance from a transparent SQL ledger (`tx_garage_society_log`), deposit/withdraw with atomic balance check.
- **Admin commands** — `/tx_spawnveh`, `/tx_delveh`, `/tx_tpveh`, `/tx_impound`, `/tx_release` — all ACE-gated (`tx_garage.admin`), all auto-suggested in chat.
- **Discord webhooks** — auction start, auction won, big impound, big transfers — with configurable minimum thresholds. Empty URL disables.
- **Mileage tracking** — odometer thread samples vehicle position every 2s while driven; flushes on store; server clamps monotonic so values can never decrease.
- **Anti-snipe** — bids in the final `Config.Auction.antiSnipeSeconds` extend `ends_at` by `antiSnipeExtend` seconds. Atomic with the bid (single UPDATE).
- **Vehicle search** — live filter by model or plate in the garage NUI.
- **Live ticking auction timers** — single client thread pumps `auctionTick` messages; NUI updates every visible card per second in one DOM pass.
- **"You are leading" banner** — server tags `is_leader` per auction without leaking the bidder's citizenid to other clients.
- **VIP garage type** — gated by ACE permission (`Config.GarageTypes.vip.aceCheck`).
- **Anti-stuck valet** — primary spawn + 4 fallback offsets; if all fail, the player is auto-refunded.
- **Vehicle preview gradients** — per class (super/sports/suv/motorcycle/truck/sedan/compact) via pure CSS conic + linear gradients. Zero asset shipping.
- **Focus trap** in NUI modals (Tab/Shift+Tab cycle within the open modal).

### Changed
- `fxmanifest.lua` — drops QB/ESX deps; requires `qbx_core`, `ox_lib`, `oxmysql`. Adds `provide 'tx_garage'` and `use_experimental_fxv2_oal 'yes'`.
- Auction tick now **adaptive** — sleeps until next `ends_at` or 5min, whichever sooner. Idle servers no longer run useless queries (was every 60s flat).
- Auction listing strips `leading_bidder` identifier before sending to clients; replaced with a per-client `is_leader` boolean.
- All buttons in NUI now have `type="button"` (prevents phantom form submission).
- Backdrop-filter has webkit prefix for older CEF builds.
- All offline-money paths route through QBox player API when target is online.
- `onResourceStop` cleans up blips and target zones (was orphaning them on reload).

### Fixed
- `textui` interaction method now actually works (was stubbed in v1).
- Plate normalization (trailing-space stripping) applied at every server entry point — closes a subtle plate-collision vector.
- Vehicle mileage no longer rolls backwards when the client supplies a lower value.

---

## [1.1.0] — 2026-05-09

### Added
- Vehicle condition colors in NUI (engine/body/fuel green/yellow/red).
- Favorite/pin vehicles — `tx_garage_fav` column, sort to top.
- Auction watchlist — `tx_garage:watchAuction` net event, ~5 min pre-close warning.

### Fixed
- 4 pre-listing critical findings (security tightening pre-1.0 patch).

---

## [1.0.0] — Initial release

### Added
- Core garage: store / retrieve / transfer / give-key.
- Public, Private, Job, Gang, Impound garage types.
- Valet system with NPC delivery.
- Impound auction house with bid escrow.
- QBCore + Qbox + ESX bridge.
- English and Spanish locales.
- Vice City NUI (initial design).

[2.0.0]: https://github.com/Deegan4/tx_garage/compare/v1.1.0...v2.0.0
[1.1.0]: https://github.com/Deegan4/tx_garage/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Deegan4/tx_garage/releases/tag/v1.0.0
