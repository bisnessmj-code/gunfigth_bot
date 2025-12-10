shared_script '@WaveShield/resource/include.lua'

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'PVP GunFight'
description 'Système PVP GunFight ULTRA-OPTIMISÉ - matchmaking, ELO, zones, debug - v2.3.1'
version '2.3.1'

shared_scripts {
    '@es_extended/imports.lua',
    'config.lua',
    'shared/debug.lua'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/elo.lua',
    'server/groups.lua',
    'server/discord.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}
