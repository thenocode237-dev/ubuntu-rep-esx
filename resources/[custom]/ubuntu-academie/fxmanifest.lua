fx_version 'cerulean'
game 'gta5'

name 'ubuntu-academie'
description 'Academie / centre d\'accueil — PNJ + tutoriels RP (trouver un travail, illegal, acheter voiture/maison, business). Notifie les nouveaux joueurs.'
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
    'oxmysql',
}

lua54 'yes'
