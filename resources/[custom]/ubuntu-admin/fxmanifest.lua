fx_version 'cerulean'
game 'gta5'

name 'ubuntu-admin'
description 'Panel de gestion des joueurs (staff) — NUI, gated par groupe ESX : modération, économie, jobs, téléportation, annonces'
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
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies {
    'es_extended',
    'ox_lib',
    'oxmysql',
}

lua54 'yes'
