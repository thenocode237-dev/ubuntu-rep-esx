# Playlist musicale de la boîte (`ubuntu-boite`)

Dépose ici **autant de pistes que tu veux** (`.mp3`, `.ogg`, `.wav`).

- **Scan automatique** : à l'installation (`make resources`), le script génère
  `playlist.json` en scannant **tout** ce dossier. La NUI lit ce fichier et joue les
  pistes **dans l'ordre alphabétique des noms de fichiers**, puis boucle sur la playlist.
- Préfixe tes fichiers pour imposer l'ordre : `01-…`, `02-…`, `03-…`.
- La lecture démarre/s'arrête via la **platine DJ** à l'intérieur (aucun changement de
  piste manuel côté boîte — c'est une playlist en boucle).
- **Dégradation silencieuse** : si le dossier est vide, aucune erreur — la boîte tourne
  sans musique.

> Après avoir ajouté/retiré des pistes : relance `make resources` (régénère
> `playlist.json`) puis redémarre la ressource. Utilise des fichiers **libres de droits**
> ou dont tu détiens la licence (servis localement, aucun CDN).
