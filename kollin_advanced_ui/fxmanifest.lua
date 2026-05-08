fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'kollin'
description 'kollin_advanced_ui — Premium Modern UI Suite'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/utils.lua',
    'config.lua',
    'locales/*.lua',
}

client_scripts {
    'client/main.lua',
    'client/cl_hud.lua',
    'client/cl_speedometer.lua',
    'client/cl_menu.lua',
    'client/cl_notifications.lua',
    'client/cl_progressbar.lua',
    'client/cl_context.lua',
    'client/cl_settings.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/sv_settings.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/css/themes.css',
    'html/css/animations.css',
    'html/js/app.js',
    'html/js/hud.js',
    'html/js/speedometer.js',
    'html/js/menu.js',
    'html/js/notifications.js',
    'html/js/progressbar.js',
    'html/js/context.js',
    'html/js/settings.js',
}

dependencies {
    'ox_lib',
    'oxmysql',
}

escrow_ignore {
    'config.lua',
    'locales/*.lua',
    'shared/utils.lua',
    'README.md',
    'INSTALL.sql',
}
