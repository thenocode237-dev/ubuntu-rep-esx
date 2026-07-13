# overrides/

Fichiers de configuration **complets** copiés par-dessus les ressources installées
(`scripts/install-resources.sh` → `apply_overrides`). Chaque sous-dossier porte le **nom exact**
de la ressource cible (ex. `overrides/ox_inventory/` → `data/resources/[core]/ox_inventory/`).

## État Phase 1 (migration ESX)

**Aucun override nécessaire** : on reste sur les concepts **ESX par défaut**.
- Monnaie `$`, comptes `money`/`bank`/`black_money` → défauts ESX.
- Mono-personnage → `Config.Multichar` est **auto-désactivé** par es_extended quand
  `esx_multicharacter` n'est pas chargé (pas d'override à écrire).
- Locale FR → convar `setr esx:locale "fr"` dans `config/server.cfg.template`.

## Phase 2 (à venir)

- `overrides/ox_inventory/data/items.lua` (ou un fichier d'items additionnels) : items
  génériques utilisés par `ubuntu-drogue` / `ubuntu-braquages` (baggies, kit électronique,
  thermite…). ⚠️ **Ne pas remplacer** tout `items.lua` d'ox_inventory (version-spécifique,
  centaines d'items) — ajouter/merger seulement.
- Métiers ESX (police/ambulance…) : ajoutés via leur propre SQL, pas via override.
