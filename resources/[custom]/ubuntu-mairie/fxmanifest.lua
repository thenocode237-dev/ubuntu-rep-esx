fx_version 'cerulean'
game 'gta5'

name 'ubuntu-mairie'
description 'Mairie / centre pour l\'emploi — PNJ + menu ox_lib pour prendre ou quitter un metier (citoyen, police, EMS...). 100% serveur-authoritative.'
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
    'server.lua',
}

dependencies {
    'es_extended',
    'ox_lib',
}

lua54 'yes'
