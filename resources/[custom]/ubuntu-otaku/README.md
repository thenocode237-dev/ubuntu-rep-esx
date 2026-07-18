# ubuntu-otaku — conteneur de vêtements / accessoires otaku (anime)

Ressource **stream-only** (aucune logique serveur) qui charge des vêtements, coiffures,
accessoires ou props à thème **anime / otaku** pour les joueurs. Elle est déjà `ensure`
dans `config/server.cfg.template` et montée dans le conteneur via le bind `[ubuntu]`.

> ⚠️ **Pourquoi le dossier est vide ?** Les fichiers 3D d'un pack de vêtements
> (`.ydd`/`.ytd`) sont des **binaires** qui doivent venir d'une **source réelle** — ils ne
> peuvent pas être générés. Tu dois donc déposer toi-même un pack **légitime**.

## Ajouter un pack

1. Récupère un pack de vêtements otaku **légitime** :
   - **Gratuit** : GitHub, [forum Cfx.re › Releases](https://forum.cfx.re/c/development/releases/7)
     (ex. *Anime Hair for MP Male/Female*), gta5-mods.com (add-on clothing).
   - **Payant** : boutiques **Tebex** officielles.
   - ❌ **Jamais** de site de leak (vag.gg, vfivem, code4mods…) : redistribution illégale →
     risque de bannissement de la clé serveur + fichiers vérolés.
2. Copie tous ses fichiers (`.ydd`, `.ytd`, `.ymt`, `.meta`…) dans **`stream/`**
   (les sous-dossiers sont acceptés — le stream est récursif).
3. Si le pack est un **add-on clothing** livré avec un ou plusieurs `.meta`
   (`SHOP_PED_APPAREL_META_FILE`), décommente et adapte les lignes `files{}` +
   `data_file` dans [`fxmanifest.lua`](fxmanifest.lua). Un pack qui **remplace** des
   drawables freemode existants n'a besoin d'aucune `.meta` (juste les fichiers dans `stream/`).
4. Redémarre le serveur (`make restart`) puis, en jeu, ouvre le menu d'apparence
   (`illenium-appearance`/`fivem-appearance`) : les nouveaux éléments apparaissent dans
   les composants concernés (hauts, jambes, coiffures, accessoires…).

## Vendre / offrir ces tenues

- **Boutique premium** : ajoute une entrée `type = 'cosmetic'` dans
  `resources/[custom]/ubuntu-premium/config.lua > Config.Catalog` (le skin complet est
  stocké et re-portable via `/tenues`).
- **Vestiaire d'apparence** : les tenues streamées sont directement sélectionnables dans le
  menu d'apparence, sans configuration supplémentaire.

## Voir aussi

- Arme otaku déjà intégrée : **ThermalKatana** (katana thermique), déclarée dans
  `ox_inventory/data/weapons.lua` et vendue à l'armurerie civile (6000 $) par
  `append_custom_weapons` dans `scripts/install-resources.sh`.
