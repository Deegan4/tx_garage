# Installation guide

This guide covers fresh installs and upgrades from v1.x.

## Requirements

| Required | Why |
|---|---|
| FXServer (any recent artifact) | Game server |
| MySQL / MariaDB | `oxmysql` driver |
| [`qbx_core`](https://github.com/Qbox-project/qbx_core) | Framework |
| [`ox_lib`](https://github.com/overextended/ox_lib) | Notifications, callbacks, dialogs |
| [`oxmysql`](https://github.com/overextended/oxmysql) | Database driver |

| Recommended | Why |
|---|---|
| [`ox_target`](https://github.com/overextended/ox_target) | Zone-based interaction (or `qb-target`) |
| [`ox_fuel`](https://github.com/overextended/ox_fuel) | Fuel persistence + valet deduction |
| [`qbx_vehiclekeys`](https://github.com/Qbox-project/qbx_vehiclekeys) | Auto-key handoff on retrieve |

> v2.0 is **QBox-native**. For QBCore/ESX servers, use the v1.x branch.

---

## Fresh install (5 minutes)

### 1. Drop the resource

```
resources/[tx]/tx_garage/
```

(The `[tx]` bracket is a literal folder name — FiveM uses square brackets to group resources.)

### 2. Import the schema

Run once against your game database:

```bash
mysql -u <user> -p <db_name> < INSTALL.sql
```

The script is **idempotent** — re-running it is safe and only adds missing columns/tables. It never drops or rewrites your data.

What it adds:

| To `player_vehicles` (columns) | Why |
|---|---|
| `tx_garage_state` VARCHAR(16) | `'out'`, `'stored'`, `'impound'`, `'auction'` — drives the state machine |
| `tx_garage_name` VARCHAR(64) | Which garage the vehicle is stored at |
| `tx_garage_impounded_at` DATETIME | Impound start time (for fee calc + auction promotion) |
| `tx_garage_fav` TINYINT | Pinned/favorite flag |
| `tx_garage_mileage` BIGINT UNSIGNED | Total meters driven |
| `tx_garage_rent_paid_at` DATETIME | Last private-rent payment timestamp |
| `tx_garage_sub_owners` JSON | Array of citizenids with shared keys |
| `tx_garage_plate_changed_at` DATETIME | Last plate-change time (cooldown enforcement) |

| New tables | Why |
|---|---|
| `tx_garage_auctions` | Open / closed / forfeited auctions |
| `tx_garage_auction_bids` | Bid history per auction |
| `tx_garage_valet_log` | Valet calls (analytics + abuse) |
| `tx_garage_transfer_requests` | Pending transfer-with-consent requests |
| `tx_garage_society_log` | Society ledger (boss menu + auction cuts) |

### 3. Configure ACE permissions

Add to your `server.cfg`:

```cfg
add_ace group.admin tx_garage.admin allow
add_ace group.mod   tx_garage.mod   allow
```

(Or scope to specific identifiers — see [the ACE docs](https://docs.fivem.net/docs/server-manual/setting-up-a-server-vanity/) for advanced setups.)

### 4. Ensure the resource

```cfg
ensure qbx_core
ensure ox_lib
ensure oxmysql
ensure ox_target
ensure tx_garage
```

`tx_garage` must come **after** its dependencies.

### 5. Configure

Open `config.lua` and set at minimum:
- `Config.Garages` — your garage spawn locations
- `Config.Auction.auctionLot` — where the auction NPC interaction lives
- `Config.Auction.payoutSplit` — economy tuning (must sum to 1.0)

See [CONFIG.md](./CONFIG.md) for every option.

### 6. (Optional) Discord webhooks

In `config.lua`:

```lua
Config.Webhooks = {
    enabled = true,
    auctionStart = { url = 'https://discord.com/api/webhooks/...', minValue = 50000 },
    auctionWon   = { url = 'https://discord.com/api/webhooks/...', minBid   = 100000 },
    bigImpound   = { url = 'https://discord.com/api/webhooks/...', minValue = 100000 },
    transfers    = { url = 'https://discord.com/api/webhooks/...', minPrice = 50000 },
}
```

Empty URLs no-op safely. Threshold fields filter low-value posts to avoid spam.

### 7. Restart the server

```
restart tx_garage
```

If the server is running but tx_garage isn't, just `start tx_garage`.

---

## Upgrading from v1.x to v2.0

### What changes

- v2.0 is **QBox-only**. If your server runs QBCore or ESX, stay on v1.x (still maintained for security backports).
- The `Config` shape is rewritten — your old config will not work. Re-edit `config.lua` from scratch using the new defaults.
- DB columns are **additive only** — existing vehicles, auctions, and bids survive.
- Net event names are unchanged; resources listening on `tx_garage:*` keep working.

### Steps

1. **Backup your database.** Always.
2. Stop the server (or at least `stop tx_garage`).
3. Replace the resource folder with the v2.0 build.
4. Run `INSTALL.sql` again — it's idempotent and only adds missing columns/tables.
5. Add the ACE permissions to `server.cfg` (see step 3 above).
6. Re-edit `config.lua` from the new template — copy your garage locations, costs, and economy values into the new shape. See [CONFIG.md](./CONFIG.md) for the field-by-field reference.
7. Start the server.
8. Smoke-test: store a vehicle, retrieve it, place a bid on an existing auction, run an admin command. If all four work, you're upgraded.

### Rollback

If something goes wrong, the v1 resource folder + your DB backup will restore everything. v2's schema additions are inert when running v1 code.

---

## Troubleshooting

**"player_vehicles doesn't have a tx_garage_state column"**
You haven't run `INSTALL.sql` yet, or you ran it against the wrong database. Check `mysql -e "USE <db>; SHOW COLUMNS FROM player_vehicles LIKE 'tx_garage_%'"` — you should see 8 columns.

**"Auction lot blip doesn't appear"**
`Config.Auction.enabled = false`, or the player's character hasn't loaded yet. Check the F8 console for `tx_garage` errors.

**"qbx_vehiclekeys doesn't fire on retrieve"**
Ensure `Config.Storage.keysResource = 'qbx_vehiclekeys'`. tx_garage triggers `qbx_vehiclekeys:client:GiveKeys`. If you use a different keys resource, set its name and tx_garage will trigger the correct event.

**"Players say 'Bid stale, refresh' on a fresh auction"**
This is the optimistic-concurrency rejection — it means another bid arrived in the same window. The bidder's money was returned. They can re-bid against the new current bid.

**"Admin commands don't work"**
ACE not configured. Check `server.cfg` has `add_ace group.admin tx_garage.admin allow` and that the player is actually in `group.admin` (live admins, not principals).

**"NUI is blank"**
Open the F8 console with `nui_devtools tx_garage` and check the browser console for errors. The most common cause is a missing dependency (`ox_lib` not started before `tx_garage`).

**"My old config doesn't load"**
Expected — v2.0 broke config compatibility. See [CONFIG.md](./CONFIG.md) and re-edit.

---

## Verifying the install

A healthy boot looks like this in the server console:

```
[tx_garage] tx_garage v2 — server bridge loaded (QBox-native)
[oxmysql] [tx_garage] all migrations satisfied
[tx_garage] client ready (target)   (per connected player)
```

If you see `[tx_garage] failed to load server config` (only with `Config.Debug = true`), the config callback never resolved — usually means `qbx_core` isn't fully loaded yet. Restart `tx_garage` after `qbx_core` is up.
