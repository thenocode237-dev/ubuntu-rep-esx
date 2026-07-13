fx_version 'cerulean'
game 'gta5'

name 'ubuntu-braquages'
description 'Braquages de supérettes, distributeurs et banques — butin en $, alerte Police, cooldowns. Logique 100% serveur-authoritative.'
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
    'ox_inventory',
}

lua54 'yes'
