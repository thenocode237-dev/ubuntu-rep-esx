fx_version 'cerulean'
game 'gta5'

name 'ubuntu-interface'
description 'Interface joueur — menu principal (F1), habillage du menu pause et carte des points d''intérêt (blips)'
author 'Ubuntu RP'
version '2.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'locales/fr.lua',
    'locales/en.lua',
    'locales/locale.lua',
    'config.lua',
}

client_scripts {
    'client.lua',
}

server_scripts {
    'server.lua',
}

dependencies {
    'es_extended',
    'ox_lib',
}

lua54 'yes'
