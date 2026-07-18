// Lecteur d'ambiance de la boite de nuit — PLAYLIST.
// Scanne musics/playlist.json (genere a l'install), joue les pistes DANS L'ORDRE
// et BOUCLE sur la liste. Recoit play/stop depuis client.lua (SendNUIMessage).
// Auto-contenu, aucune dependance externe. Degrade en silence si la playlist est
// vide ou absente. Aucun changement de piste manuel cote boite (playlist en boucle).
(function () {
    'use strict';

    var audio = document.getElementById('ambiance');
    audio.volume = 0.35;

    var tracks = [];   // ['musics/01.mp3', ...]
    var index = 0;
    var wantPlay = false;
    var ready = false;

    // Charge la playlist generee a l'installation.
    fetch('musics/playlist.json')
        .then(function (r) { return r.ok ? r.json() : []; })
        .then(function (list) {
            if (Array.isArray(list)) {
                tracks = list.map(function (name) { return 'musics/' + name; });
            }
            ready = true;
            if (wantPlay) start();
        })
        .catch(function () { ready = true; });

    function load(i) {
        if (!tracks.length) return;
        index = ((i % tracks.length) + tracks.length) % tracks.length;
        audio.src = tracks[index];
    }

    function play() {
        var p = audio.play();
        if (p && p.catch) { p.catch(function () {}); }
    }

    function start() {
        if (!tracks.length) return;
        if (!audio.src) load(0);
        play();
    }

    // Enchaine la piste suivante ; en fin de liste → retour au debut (boucle).
    audio.addEventListener('ended', function () {
        if (!wantPlay || !tracks.length) return;
        load(index + 1);
        play();
    });

    // Si une piste est illisible, on passe a la suivante (ne bloque pas la boite).
    audio.addEventListener('error', function () {
        if (!wantPlay || tracks.length <= 1) return;
        load(index + 1);
        play();
    });

    window.addEventListener('message', function (event) {
        var data = event.data || {};
        if (data.action === 'play') {
            wantPlay = true;
            if (ready) start();
        } else if (data.action === 'stop') {
            wantPlay = false;
            try { audio.pause(); } catch (e) {}
        } else if (typeof data.volume === 'number') {
            audio.volume = Math.max(0, Math.min(1, data.volume));
        }
    });
})();
