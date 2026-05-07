# tx_garage — Claude Code Guide

## Project
FiveM resource (QBCore framework). Garage system with valet delivery and impound auction house.

## Stack
- **Language:** Lua (FiveM/CitizenFX)
- **Framework:** QBCore (`Config.Framework = 'qbcore'`)
- **DB:** oxmysql → MariaDB 12.2 (service name: `MariaDB`, database: `fivem`, root/no password)
- **Dependencies:** ox_lib, oxmysql, qb-core

## File layout
```
client/       — client-side Lua
server/       — server-side Lua
shared/       — utils shared both sides
nui/          — HTML/CSS/JS garage UI
locales/      — en.lua, es.lua
config.lua    — all tunable values (framework, garages, valet, auction)
fxmanifest.lua
INSTALL.sql   — non-destructive schema (run once against fivem DB)
```

## Server setup (local dev)
| Component | Path |
|-----------|------|
| FXServer  | `D:\server\FXServer.exe` |
| txAdmin   | http://localhost:40120 |
| server-data | `D:\txData\FiveMBasicServerCFXDefault_FBD687.base\` |
| resources | `D:\txData\FiveMBasicServerCFXDefault_FBD687.base\resources\[local]\` |
| server.cfg | `D:\txData\FiveMBasicServerCFXDefault_FBD687.base\server.cfg` |
| MariaDB   | `C:\Program Files\MariaDB 12.2\` — Windows service |
| HeidiSQL  | Installed via winget |

## Resource load order (server.cfg)
```
ensure oxmysql
ensure ox_lib
ensure qb-core
ensure tx_garage
```

## Deploying changes
The dev folder (`D:\tx_garage`) is separate from the deployed copy (`resources/[local]/tx_garage`).
Sync with:
```
robocopy "D:\tx_garage" "D:\txData\FiveMBasicServerCFXDefault_FBD687.base\resources\[local]\tx_garage" /E
```
Then in txAdmin console: `restart tx_garage`

## Database
- Connection string in server.cfg: `mysql://root@localhost/fivem?charset=utf8mb4`
- Tables: `player_vehicles`, `tx_garage_auctions`, `tx_garage_auction_bids`, `tx_garage_valet_log`
- Re-run schema: `mysql -u root fivem < INSTALL.sql`

## Known issues / notes
- Server list errors (`context deadline exceeded`) are expected — router port forward not set up, connect locally via `connect 127.0.0.1:30120` in FiveM F8 console
- ox_lib must be the **pre-built release zip** (not a source clone) — `web/build/index.html` must exist
- FiveM client not installed; GTA V is at `D:\SteamLibrary\steamapps\common\Grand Theft Auto V\`
- `player_vehicles` was created as a minimal stub for dev; will be replaced when a full QBCore install is done
