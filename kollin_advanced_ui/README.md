# kollin_advanced_ui — Premium Modern UI Suite

> **0.00ms idle · QBCore · QBox · ESX · Standalone · Multi-language**

A complete UI replacement for FiveM: HUD, speedometer, notifications, progress bar, context menu, and main menu — all in one polished, zero-dependency resource.

---

## Features

| Module | What it does |
|---|---|
| **HUD** | Status bars (health/armor/hunger/thirst/stamina/stress/oxygen), money, location, time, wanted level |
| **Speedometer** | Speed, RPM, gear, fuel, seatbelt indicator, engine & body health |
| **Notifications** | Toast queue with sound, icons, timer bar, 5 positions |
| **Progress Bar** | Cancellable timed bar with label |
| **Context Menu** | Keyboard-navigable floating list |
| **Main Menu** | Player info, vehicle info, emotes, settings, admin tab |
| **Themes** | Dark, Light, Cyberpunk, Minimal, Red Dead — live preview |
| **Persistence** | Per-player settings saved to database |

---

## Installation

1. Drop `kollin_advanced_ui/` into `resources/[kollin]/`
2. Run `INSTALL.sql` against your server's MySQL database:
   ```
   mysql -u <user> -p <db> < INSTALL.sql
   ```
3. Add to `server.cfg`:
   ```
   ensure kollin_advanced_ui
   ```
4. Edit `config.lua`:
   - Set `Config.Framework` (or leave `'auto'`)
   - Adjust module toggles, default theme, speed unit

---

## Configuration

All tuneable values are in `config.lua`. Key options:

```lua
Config.Framework   = 'auto'       -- 'qbcore' | 'qbox' | 'esx' | 'standalone'
Config.DefaultTheme = 'dark'      -- 'dark' | 'light' | 'cyberpunk' | 'minimal' | 'redDead'
Config.Speedometer.unit = 'mph'   -- 'mph' | 'kph'
Config.Notifications.position = 'top-right'
Config.HUD.bars.stress.enabled = false  -- enable QBCore stress bar
```

---

## Integrations

### QBCore / QBox
- Money updates via `QBCore:Player:SetPlayerData`
- Metadata (hunger/thirst/stress) via `LocalPlayer.state`
- Admin detection via ACE permission `kollin.admin`

### ESX
- Money via `esx:setPlayerData`
- Metadata via QBCore-compatible statebag fallback

### Fuel Resources
Set `Config.Storage.fuelResource`:
```lua
Config.Storage = { fuelResource = 'LegacyFuel' }  -- or 'ox_fuel', 'ps-fuel'
```

### Vehicle Keys
Set in `Config.Storage.keysResource` for lock/unlock integration.

### ox_target / existing garage resources
No conflicts — this resource only adds NUI overlays and does not register ox_target zones.

---

## Exports (call from other resources)

```lua
-- Notifications
exports.kollin_advanced_ui:Notify('Message here', 'success', 5000)
-- type: 'success' | 'error' | 'info' | 'warning' | 'announce'

-- Progress bar
exports.kollin_advanced_ui:Progress({
    label     = 'Picking lock...',
    duration  = 5000,
    canCancel = true,
    onCancel  = function() print('cancelled') end,
}, function(completed)
    if completed then print('done') end
end)

-- Context menu
exports.kollin_advanced_ui:OpenContext({
    { label = 'Option A', icon = '🔑', callback = function() end },
    { label = 'Option B', icon = '💰', description = 'Some info', callback = function() end },
    { label = 'Disabled', disabled = true },
}, 'Menu Title')

-- HUD / Speedo visibility
exports.kollin_advanced_ui:SetHUDVisible(false)
exports.kollin_advanced_ui:SetSpeedoVisible(false)
```

---

## Adding a theme

1. Add a new `[data-theme="myTheme"]` block in `html/css/themes.css`
2. Add an entry to the `THEMES` array in `html/js/settings.js`
3. Optionally set `Config.DefaultTheme = 'myTheme'`

---

## Adding emotes

Extend `Config.Menu.emotes` in `config.lua`:
```lua
{ label = 'My Emote', cmd = '/e myemote' },
```

---

## Performance

- **Idle resmon**: 0.00ms (all modules sleep when no players in vehicle / menu closed)
- **HUD tick**: every 250ms (configurable via `Config.HUD.updateInterval`)
- **Speedometer tick**: every 100ms while in vehicle only
- **NUI rendering**: requestAnimationFrame, only repaints changed values

---

## Escrow

Files **not** escrow-locked (freely editable by buyers):
- `config.lua`
- `locales/*.lua`
- `shared/utils.lua`
- `README.md`, `INSTALL.sql`

---

## Changelog

### 1.0.0
- Initial release: HUD, Speedometer, Notifications, Progress Bar, Context Menu, Main Menu
- 5 themes with live preview
- QBCore / QBox / ESX / Standalone support
- Per-player settings persistence
- EN / ES / FR locales
