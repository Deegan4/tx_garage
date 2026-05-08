--[[
    kollin_advanced_ui — Configuration
    All gameplay-affecting values live here. Never touch client/ or server/
    to tune this resource — edit this file only.
]]

Config = {}

-- 'auto' detects from loaded resources. Set explicitly if auto-detect fails.
-- Options: 'qbcore' | 'qbox' | 'esx' | 'standalone'
Config.Framework = 'auto'

Config.Locale   = 'en'
Config.Debug    = false
Config.Currency = '$'

-- ─────────────────────────────────────────────────────────────────────
-- HUD
-- ─────────────────────────────────────────────────────────────────────
Config.HUD = {
    enabled          = true,
    -- 'bottom-left' | 'bottom-right' | 'top-left' | 'top-right'
    statusPosition   = 'bottom-left',
    showMoney        = true,
    showCash         = true,
    showBank         = true,
    showLocation     = true,
    showTime         = true,
    showWantedLevel  = true,
    showVoiceIndicator = true,
    updateInterval   = 250,  -- ms between HUD refreshes

    bars = {
        health  = { enabled = true, lowThreshold = 25 },
        armor   = { enabled = true },
        hunger  = { enabled = true, lowThreshold = 20 },
        thirst  = { enabled = true, lowThreshold = 20 },
        stamina = { enabled = true },
        stress  = { enabled = false },   -- QBCore only
        oxygen  = { enabled = false },
    },
}

-- ─────────────────────────────────────────────────────────────────────
-- Speedometer
-- ─────────────────────────────────────────────────────────────────────
Config.Speedometer = {
    enabled         = true,
    unit            = 'mph',      -- 'mph' | 'kph'
    -- 'modern' | 'minimal' | 'classic'
    style           = 'modern',
    -- 'bottom-right' | 'bottom-left' | 'bottom-center'
    position        = 'bottom-right',
    showFuel        = true,
    showRPM         = true,
    showGear        = true,
    showSeatbelt    = true,
    showEngineHealth = true,
    showBodyHealth  = true,
    updateInterval  = 100,
}

-- ─────────────────────────────────────────────────────────────────────
-- Main Menu
-- ─────────────────────────────────────────────────────────────────────
Config.Menu = {
    enabled       = true,
    openKey       = 'F9',
    openCommand   = 'menu',
    animation     = 'slide',   -- 'slide' | 'fade' | 'scale'
    -- Job names or ACE groups treated as admin
    adminJobs     = { 'admin', 'superadmin' },
    adminAce      = 'kollin.admin',
    -- Emote list (name = command/anim, label = display name)
    emotes = {
        { label = 'Wave',      cmd = '/e wave'      },
        { label = 'Dance',     cmd = '/e dance'     },
        { label = 'Pushups',   cmd = '/e pushup'    },
        { label = 'Sitdown',   cmd = '/e sit'       },
        { label = 'Handsup',   cmd = '/e handsup'   },
        { label = 'Lean',      cmd = '/e lean'      },
        { label = 'Smoke',     cmd = '/e smoke'     },
        { label = 'Thumbsup',  cmd = '/e thumbsup'  },
        { label = 'Clap',      cmd = '/e clap'      },
        { label = 'Salute',    cmd = '/e salute'    },
        { label = 'Surrender', cmd = '/e surrender' },
        { label = 'Shrug',     cmd = '/e shrug'     },
    },
}

-- ─────────────────────────────────────────────────────────────────────
-- Notifications
-- ─────────────────────────────────────────────────────────────────────
Config.Notifications = {
    enabled         = true,
    replaceDefault  = true,  -- override QBCore/ESX built-in notifications
    -- 'top-right' | 'top-left' | 'bottom-right' | 'bottom-left' | 'top-center'
    position        = 'top-right',
    maxQueue        = 5,
    defaultDuration = 5000,
    sounds          = true,
}

-- ─────────────────────────────────────────────────────────────────────
-- Progress Bar
-- ─────────────────────────────────────────────────────────────────────
Config.ProgressBar = {
    enabled     = true,
    cancellable = true,
    cancelKey   = 'BACKSPACE',
}

-- ─────────────────────────────────────────────────────────────────────
-- Context Menu
-- ─────────────────────────────────────────────────────────────────────
Config.ContextMenu = {
    enabled = true,
}

-- ─────────────────────────────────────────────────────────────────────
-- Appearance defaults (overridden per-player once they save settings)
-- ─────────────────────────────────────────────────────────────────────
-- 'dark' | 'light' | 'cyberpunk' | 'minimal' | 'redDead'
Config.DefaultTheme = 'dark'
Config.DefaultScale = 1.0

-- ─────────────────────────────────────────────────────────────────────
-- Persistence
-- ─────────────────────────────────────────────────────────────────────
Config.SaveSettings  = true   -- save per-player settings to DB (requires oxmysql)
Config.SaveInterval  = 300    -- auto-save every N seconds
