fx_version 'cerulean'
game 'gta5'

name 'ubuntu-banque'
description 'Banque ESX — guichets + distributeurs (ATM) : dépôt / retrait / virement. Logique 100% serveur-authoritative.'
author 'Ubuntu RP'
version '1.0.0'

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
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}

dependencies {
    'es_extended',
    'ox_lib',
    'ox_target',
    'oxmysql',
}

lua54 'yes'
