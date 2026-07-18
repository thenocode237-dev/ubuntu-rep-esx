fx_version 'cerulean'
game 'gta5'

name 'ubuntu-boite'
description 'Boite de nuit ESX — entree (videur), bar (boissons ox_inventory), DJ/ambiance. Interieur natif GTA (After Hours) via IPL. 100% serveur-authoritative.'
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

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    -- Playlist musicale : tout le dossier musics/ (pistes + playlist.json généré
    -- par generate_music_playlists dans scripts/install-resources.sh).
    'html/musics/**',
}

dependencies {
    'es_extended',
    'ox_lib',
    'ox_target',
    'ox_inventory',
}

lua54 'yes'
