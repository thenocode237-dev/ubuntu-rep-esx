# Médias de l'écran de chargement

Ce dossier contient les fichiers média affichés/joués pendant le chargement du serveur.

## Fichiers en place

| Fichier | Rôle | Statut |
|---------|------|--------|
| `background.jpg` | Image de fond plein écran (voile sombre appliqué par-dessus) | ✅ fourni |
| `logo.png` | Logo image officiel Ubuntu RP (512×512 ; masque le logo texte au chargement) | ✅ fourni |

> 🎵 **La musique a déménagé** : elle est désormais une **playlist** dans le dossier voisin
> [`../musics/`](../musics/) (dépose autant de pistes que tu veux ; scan automatique + boutons
> ⏮ / ⏭ sur l'écran de chargement). Voir `../musics/README.md`.

## Remplacer un média

Gardez **exactement les mêmes noms de fichiers** puis rechargez le serveur
(`docker compose restart fivem` ou `refresh` + `ensure ubuntu-loadscreen` dans la console txAdmin).

- **Fond** : `background.jpg` — JPG paysage, idéalement **1920×1080** (le 4K marche mais alourdit
  le démarrage de la NUI ; downscaler si le chargement traîne).
- **Musique** : voir [`../musics/`](../musics/) — dépose tes `.mp3/.ogg/.wav`, relance
  `make resources` (régénère `playlist.json`). Le lecteur se coupe silencieusement si le dossier
  est vide.
- **Logo image** : `logo.png` (512×512, logo Ubuntu RP). Déjà déclaré dans `../../fxmanifest.lua` et
  affiché à la place du logo texte (l'`<img>` masque le `<h1>` via son `onload` dans `../index.html` ;
  si le fichier est retiré, `onerror` rebascule sur le logo texte). Remplacer = même nom `logo.png`.

## Icône du serveur (navigateur FiveM)

L'icône du navigateur de serveurs n'est **pas** ici : c'est `config/server-icon.png` (PNG **96×96**,
même logo), activée par `load_server_icon "/opt/fivem/config/server-icon.png"` dans
`config/server.cfg.template`.

## Régénérer tous les logos d'un coup

Le logo source carré est versionné dans **`config/logo-source.png`**. Pour régénérer toutes les
tailles (loadscreen 512×512, wiki 560×560, icône serveur 96×96) depuis cette source :

```bash
python scripts/gen-logos.py config/logo-source.png .
```

Remplacer le logo du serveur = remplacer `config/logo-source.png` puis relancer cette commande.
