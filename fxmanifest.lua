fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

author 'tx'
description 'tx_garage — premium QBox garage with valet, live impound auctions, plate change, boss menu'
version '2.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/utils.lua',
    'config.lua',
    'locales/*.lua',
}

client_scripts {
    'client/main.lua',
    'client/cl_garage.lua',
    'client/cl_valet.lua',
    'client/cl_auction.lua',
    'client/cl_admin.lua',
    'client/cl_events.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/sv_garage.lua',
    'server/sv_valet.lua',
    'server/sv_auction.lua',
    'server/sv_admin.lua',
    'server/sv_callbacks.lua',
    'server/sv_events.lua',
    'server/sv_webhooks.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/style.css',
    'nui/script.js',
    'nui/assets/*.svg',
    'nui/assets/sounds/*.ogg',
    'nui/assets/fonts/*.woff2',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}

-- Tebex escrow allowlist — only config & locale-tier files remain editable.
escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'shared/utils.lua',
    'README.md',
    'INSTALL.sql',
    'LICENSE',
}

-- ACE permissions (declared here so admins know what to add to server.cfg)
-- add_ace group.admin tx_garage.admin allow
-- add_ace group.mod   tx_garage.mod   allow
provide 'tx_garage'
