fx_version 'cerulean'
game 'gta5'

name 'ubuntu-loadscreen'
description 'Écran de chargement thématisé Ubuntu RP (Cameroun / Afrique centrale) : logo, fond, barre de progression, astuces RP et musique d''attente'
author 'Ubuntu RP'
version '1.0.0'

-- Loadscreen : ces directives DOIVENT être dans le fxmanifest de la ressource
-- (doc officielle Cfx.re — elles n'ont AUCUN effet dans server.cfg). Le HTML du
-- loadscreen doit aussi figurer dans files{} pour être servi au client.
loadscreen 'html/index.html'
loadscreen_manual_shutdown 'yes' -- reste affiché jusqu'à ShutdownLoadingScreenNui() (ubuntu-antichute)
loadscreen_cursor 'yes'          -- curseur actif (bouton mute musique)

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/assets/background.jpg',
    'html/assets/music.mp3',
    'html/assets/logo.png',
}

lua54 'yes'
