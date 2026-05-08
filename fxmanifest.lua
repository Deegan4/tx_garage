fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'tx'
description 'tx_garage — modern multi-framework garage with valet & impound auctions'
version '1.0.0'

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
    'client/cl_events.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/sv_garage.lua',
    'server/sv_valet.lua',
    'server/sv_auction.lua',
    'server/sv_events.lua',
    'server/sv_callbacks.lua',
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/style.css',
    'nui/script.js',
    'nui/assets/*.svg',
    'nui/assets/fonts/*.woff2',
}

dependencies {
    'ox_lib',
    'oxmysql',
}

-- Tebex escrow allowlist (kept editable for buyers)
escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'README.md',
    'INSTALL.sql',
    'LICENSE',
    'shared/utils.lua',
}
