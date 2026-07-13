# Médias de l'écran de chargement

Ce dossier contient les fichiers média affichés/joués pendant le chargement du serveur.

## Fichiers en place

| Fichier | Rôle | Statut |
|---------|------|--------|
| `background.jpg` | Image de fond plein écran (voile sombre appliqué par-dessus) | ✅ fourni |
| `music.mp3` | Musique d'attente jouée en boucle (bouton mute en bas à droite) | ✅ fourni |
| `logo.png` | Logo image officiel Ubuntu RP (512×512 ; masque le logo texte au chargement) | ✅ fourni |

## Remplacer un média

Gardez **exactement les mêmes noms de fichiers** puis rechargez le serveur
(`docker compose restart fivem` ou `refresh` + `ensure ubuntu-loadscreen` dans la console txAdmin).

- **Fond** : `background.jpg` — JPG paysage, idéalement **1920×1080** (le 4K marche mais alourdit
  le démarrage de la NUI ; downscaler si le chargement traîne).
- **Musique** : `music.mp3` — MP3 (ou remplacez par un OGG en adaptant la balise `<audio>` dans
  `../index.html`). Un morceau en boucle courte réduit le poids ; le fichier complet fonctionne
  aussi. Le lecteur se coupe silencieusement si le fichier est absent.
- **Logo image** : `logo.png` (512×512, logo Ubuntu RP). Déjà déclaré dans `../../fxmanifest.lua` et
  affiché à la place du logo texte (l'`<img>` masque le `<h1>` via son `onload` dans `../index.html` ;
  si le fichier est retiré, `onerror` rebascule sur le logo texte). Remplacer = même nom `logo.png`.

## Icône du serveur (navigateur FiveM)

L'icône du navigateur de serveurs n'est **pas** ici : c'est `config/server-icon.png` (PNG **96×96**,
même logo), activée par `load_server_icon "/opt/fivem/config/server-icon.png"` dans
`config/server.cfg.template`.
