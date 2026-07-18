# Playlist musicale de l'écran de chargement (`ubuntu-loadscreen`)

Dépose ici **autant de pistes que tu veux** (`.mp3`, `.ogg`, `.wav`).

- **Scan automatique** : à l'installation (`make resources`), le script génère
  `playlist.json` en scannant **tout** ce dossier. La NUI lit ce fichier et joue les
  pistes **dans l'ordre alphabétique des noms de fichiers**, puis boucle sur la playlist.
- Préfixe tes fichiers pour imposer l'ordre : `01-…`, `02-…`, `03-…`.
- Le joueur peut **changer de piste** (boutons ⏮ / ⏭ sur l'écran de chargement) et couper
  le son (bouton 🔊). Ces contrôles n'existent **que** sur le loadscreen.
- **Dégradation silencieuse** : si le dossier est vide, aucune erreur — pas de musique.

> Après avoir ajouté/retiré des pistes : relance `make resources` (régénère
> `playlist.json`). ⚠️ Le loadscreen est **mis en cache** côté client : **redémarre
> complètement FiveM** (ou vide le cache) pour voir le changement. Utilise des fichiers
> **libres de droits** ou dont tu détiens la licence (servis localement, aucun CDN).
