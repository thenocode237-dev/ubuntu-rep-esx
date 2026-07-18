/* =============================================================================
   Ubuntu RP — logique de l'écran de chargement
   - Écoute les events loadscreen FiveM (barre de progression + statut).
   - Fait tourner des astuces RP en français.
   - Gère la musique d'attente (auto-play, mute mémorisé, dégradation silencieuse).
   ========================================================================== */

(function () {
    'use strict';

    // --- Éléments -----------------------------------------------------------
    const barFill  = document.getElementById('bar-fill');
    const percent  = document.getElementById('percent');
    const status   = document.getElementById('status');
    const tipText  = document.getElementById('tip-text');
    const bgm       = document.getElementById('bgm');
    const muteBtn   = document.getElementById('mute-btn');
    const muteIcon  = document.getElementById('mute-icon');
    const prevBtn   = document.getElementById('prev-btn');
    const nextBtn   = document.getElementById('next-btn');
    const trackName = document.getElementById('track-name');
    const controls  = document.getElementById('music-controls');

    // --- Astuces RP (génériques) -------------------------------------------
    const TIPS = [
        "Appuyez sur F1 pour ouvrir le menu principal du serveur.",
        "Tapez /e pour ouvrir le menu d'emotes : danses, gestes et animations.",
        "Visitez /boutique pour découvrir les avantages premium : cosmétiques et confort, jamais pay-to-win.",
        "Gérez bien votre budget entre les commerces, le carburant et vos loisirs.",
        "Besoin d'un véhicule ? Rendez-vous aux points de location près des blips dédiés.",
        "Respectez le règlement RP : incarnez votre personnage, pas de HRP inutile. Bon jeu à tous !",
        "Ouvrez l'œil sur les opportunités : métiers légaux comme illégaux vous attendent.",
        "Besoin d'aide ? L'équipe de modération veille. Restez courtois et signalez les soucis via le Discord.",
    ];

    // --- Barre de progression ----------------------------------------------
    let displayed = 0;   // % affiché (lissé)
    let target = 0;      // % cible reçu de FiveM

    function render() {
        // Lissage : on approche progressivement la cible.
        displayed += (target - displayed) * 0.18;
        if (Math.abs(target - displayed) < 0.2) displayed = target;
        const val = Math.max(0, Math.min(100, displayed));
        barFill.style.width = val + '%';
        percent.textContent = Math.round(val) + ' %';
        requestAnimationFrame(render);
    }
    requestAnimationFrame(render);

    function setTarget(fraction) {
        // fraction attendue 0..1 (parfois 0..100 selon les builds) → normaliser.
        let pct = fraction <= 1 ? fraction * 100 : fraction;
        target = Math.max(target, pct); // jamais de retour en arrière
    }

    // --- Events loadscreen FiveM -------------------------------------------
    window.addEventListener('message', function (e) {
        const data = e.data || {};
        switch (data.eventName) {
            case 'loadProgress':
                setTarget(typeof data.loadFraction === 'number' ? data.loadFraction : 0);
                break;
            case 'startInitFunctionOrder':
                status.textContent = 'Préparation des ressources…';
                break;
            case 'initFunctionInvoking':
                if (data.name) status.textContent = 'Démarrage : ' + data.name;
                break;
            case 'startDataFileEntries':
                status.textContent = 'Chargement des données…';
                break;
            case 'performMapLoadFunction':
                status.textContent = 'Chargement de la carte…';
                break;
            case 'endInitFunctionOrder':
                status.textContent = 'Connexion en cours…';
                setTarget(1);
                break;
            default:
                break;
        }
    });

    // --- Rotation des astuces ----------------------------------------------
    let tipIndex = Math.floor(Math.random() * TIPS.length);
    function showTip() {
        tipText.textContent = TIPS[tipIndex];
        tipIndex = (tipIndex + 1) % TIPS.length;
    }
    showTip();
    setInterval(function () {
        tipText.classList.add('fade');
        setTimeout(function () {
            showTip();
            tipText.classList.remove('fade');
        }, 400);
    }, 6000);

    // --- Musique d'attente (PLAYLIST) --------------------------------------
    // Scanne musics/playlist.json (généré à l'install), joue les pistes DANS
    // L'ORDRE, en boucle. Le joueur peut changer de piste (⏮ / ⏭) et couper le son.
    const MUTE_KEY = 'ubuntu_loadscreen_muted';
    let muted = false;
    try { muted = localStorage.getItem(MUTE_KEY) === '1'; } catch (_) {}

    let tracks = [];   // ['musics/01.mp3', ...]
    let index = 0;
    let started = false;

    function applyMute() {
        bgm.muted = muted;
        muteIcon.textContent = muted ? '🔇' : '🔊';
        muteBtn.classList.toggle('muted', muted);
        muteBtn.setAttribute('aria-label', muted ? 'Activer la musique' : 'Couper la musique');
    }

    // Affiche brièvement le nom de la piste (sans extension ni préfixe d'ordre).
    let nameTimer = null;
    function showTrackName() {
        if (!trackName || !tracks.length) return;
        let raw = decodeURIComponent(tracks[index].replace(/^musics\//, ''));
        raw = raw.replace(/\.[^.]+$/, '').replace(/^\d+\s*[-_.]\s*/, '');
        trackName.textContent = raw;
        trackName.classList.add('show');
        if (nameTimer) clearTimeout(nameTimer);
        nameTimer = setTimeout(function () { trackName.classList.remove('show'); }, 3500);
    }

    function load(i) {
        if (!tracks.length) return;
        index = ((i % tracks.length) + tracks.length) % tracks.length;
        bgm.src = tracks[index];
        showTrackName();
    }

    function play() {
        const p = bgm.play();
        if (p && typeof p.catch === 'function') {
            // Certains contextes exigent une interaction : on réessaie au 1er clic/touche.
            p.catch(function () {
                const resume = function () {
                    bgm.play().catch(function () {});
                    window.removeEventListener('click', resume);
                    window.removeEventListener('keydown', resume);
                };
                window.addEventListener('click', resume);
                window.addEventListener('keydown', resume);
            });
        }
    }

    function start() {
        if (!tracks.length) { if (controls) controls.style.display = 'none'; return; }
        started = true;
        bgm.volume = 0.45;
        applyMute();
        if (!bgm.src) load(0);
        play();
    }

    function change(delta) {
        if (!tracks.length) return;
        load(index + delta);
        if (!muted) play();
    }

    // Enchaîne la piste suivante en fin de lecture (boucle sur la playlist).
    bgm.addEventListener('ended', function () {
        if (!tracks.length) return;
        load(index + 1);
        play();
    });
    // Piste illisible → on saute à la suivante (ne bloque jamais le loadscreen).
    bgm.addEventListener('error', function () {
        if (!started || tracks.length <= 1) return;
        load(index + 1);
        play();
    });

    muteBtn.addEventListener('click', function () {
        muted = !muted;
        try { localStorage.setItem(MUTE_KEY, muted ? '1' : '0'); } catch (_) {}
        applyMute();
        if (!muted) play();
    });
    prevBtn.addEventListener('click', function () { change(-1); });
    nextBtn.addEventListener('click', function () { change(1); });

    // Charge la playlist puis démarre.
    fetch('musics/playlist.json')
        .then(function (r) { return r.ok ? r.json() : []; })
        .then(function (list) {
            if (Array.isArray(list)) {
                tracks = list.map(function (name) { return 'musics/' + name; });
            }
            start();
        })
        .catch(function () { if (controls) controls.style.display = 'none'; });
})();
