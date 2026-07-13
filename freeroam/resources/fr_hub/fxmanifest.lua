fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fr_hub'
author 'fivemerrs'
description 'Freeroam spawn hub — marker shops (no ped NPCs)'
version '1.1.0'

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    'client.lua',
}

server_scripts {
    'server.lua',
}
