fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fr_teams'
description 'Minimal freeroam teams — no friendly fire, member blips'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    'client.lua',
}

server_scripts {
    'server.lua',
}
