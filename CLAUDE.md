# CLAUDE.md

Guide pour Claude Code lorsqu'il travaille dans ce dépôt.

> ⚠️ **Attention au CLAUDE.md parent.** Un `CLAUDE.md` situé dans `c:\Users\darks\Downloads\`
> décrit un **autre** projet (Caissia, une app POS Android en Kotlin). Il n'a **rien à voir**
> avec ce dépôt — ne pas suivre ses instructions ici. **Ce fichier-ci** fait foi pour `ubuntu RP`.

## Projet

**Ubuntu RP** — plateforme **Docker** pour déployer un **serveur FiveM (GTA V) de roleplay**,
100 % configurable par `.env`, reproductible et portable. Par-dessus l'infra, une **couche RP
ESX** (framework **ESX Legacy** + stack **ox** : ox_lib / ox_inventory / ox_target), concepts
**ESX par défaut**, monnaie `$`, textes en **français**, **mono-personnage**.

> 🔀 **Migration QBCore → ESX.** Le serveur a été bâti à l'origine sur **QBCore** (thème Cameroun /
> Afrique). Il est migré vers **ESX Legacy (stack ox)**, base propre, sans l'habillage africain
> (décision utilisateur). **Phase 1 = FAITE** (socle ESX + `ubuntu-premium`/`ubuntu-admin`/
> `ubuntu-interface`/`ubuntu-location`/`ubuntu-antichute`/`ubuntu-loadscreen`). **Phase 2 = FAITE**
> (métiers ESX police/ambulance + `esx_addonaccount`/`esx_society` ; `ubuntu-braquages` &
> `ubuntu-drogue` **portés en ESX/ox** et chargés ; items drogue/braquage ajoutés à ox_inventory).
> **Phase 3 = STAGÉE (désactivée)** : téléphone (npwd) + housing câblés en blocs commentés à activer
> après validation en jeu. ⚠️ La section « Couche RP QBCore » plus bas est **HISTORIQUE**. ⚠️ **Toutes
> les refs ESX sont posées sans réseau → à confirmer au 1er `make resources`.** Détail : `CHANGELOG.md`.

Documents de référence à la racine :
- [`vision_global.md`](vision_global.md) — vision produit (roadmap RP en phases).
- [`Specification_Technique_FiveM_Docker.md`](Specification_Technique_FiveM_Docker.md) — spec technique de l'infra.
- [`README.md`](README.md) — aperçu + guide rapide.
- [`DEPLOIEMENT.md`](DEPLOIEMENT.md) — manuel de configuration & déploiement (opérateur/admin).
- [`GUIDE_ADMIN.md`](GUIDE_ADMIN.md) — guide **staff** : panel `/admin`, permissions ace, dons Kubi, création de packs premium.
- [`wiki/`](wiki/) — site wiki **orienté joueur** (statique, HTML/CSS/JS).
- [`CHANGELOG.md`](CHANGELOG.md) — historique des fonctionnalités livrées.

## Build & exploitation

Tout passe par le [`Makefile`](Makefile) (`make help` liste les cibles) :

```bash
make install     # crée data/ + .env (depuis .env.example)
make up          # build + démarre la stack (fivem, mariadb, redis, adminer)
make resources   # installe la couche RP ESX (clones épinglés + overrides + SQL) — MariaDB doit tourner
make restart     # relance le serveur pour charger les ressources
make logs        # suit les logs FiveM
make up-all      # V1 + reverse proxy + monitoring (profils V2)
make backup / make restore / make health / make update
```

**Ordre d'installation** : `make up` (démarre MariaDB) **avant** `make resources` (import SQL).
L'utilisateur est sous Windows → lancer les scripts `bash` via Git Bash / Docker Desktop.

## Architecture (Docker)

Services sur le réseau `fivem-net` ([`docker-compose.yml`](docker-compose.yml)) :

| Service | Rôle | Port hôte |
|---------|------|-----------|
| `fivem` | Serveur FiveM + txAdmin (build local `docker/fivem`) | 30120 TCP/UDP, 40120 (txAdmin) |
| `mariadb` (mariadb:11) | Base de données | interne |
| `redis` | Cache | interne |
| `adminer` | Admin SQL web | 8080 |
| `nginx` *(profil `proxy`)* | Reverse proxy | 80/443 |
| Prometheus/Grafana/Loki/Promtail/exporters *(profil `monitoring`)* | Supervision | Grafana 3000 |

**Comment l'infra est câblée (ne pas re-dériver) :**
- [`docker/fivem/entrypoint.sh`](docker/fivem/entrypoint.sh) : (1) résout le build FXServer (canal
  `recommended`/`latest` ou `FIVEM_BUILD` épinglé) via l'API changelog ; (2) télécharge + vérifie
  (`xz -t`) + extrait dans le cache persistant `data/artifacts` (idempotent via marqueur de version) ;
  (3) **génère** `config/server.cfg` depuis [`config/server.cfg.template`](config/server.cfg.template)
  par `envsubst`, puis un `sed` **supprime les directives optionnelles laissées vides**
  (`sv_enforceGameBuild`, `steam_webApiKey`, `rcon_password`, `tags`, `discord_webhook`) ; (4) démarre
  txAdmin (`TXADMIN_ENABLE=true`, défaut) ou headless (`+exec` du cfg).
- **`server.cfg` est généré** — ne jamais l'éditer à la main. Modifier `.env` ou le template.
- **En headless, le cwd doit être `/opt/fivem`** (là où `resources/` est monté), pas le dossier des
  artifacts — sinon FXServer ne trouve pas les ressources. Déjà corrigé dans l'entrypoint.
- Le Dockerfile fait `userdel -r ubuntu` avant de créer l'utilisateur `fivem` (uid 1000) : l'image
  `ubuntu:24.04` livre déjà un user en uid 1000.

## Couche RP ESX (Phases 1 & 2 FAITES, fait autorité)

Stack cible : **ESX Legacy** (`es_extended`) + **ox** (`ox_lib` remplace qb-menu/qb-input + fournit
callbacks/context/notify, `ox_inventory` remplace qb-inventory/qb-weapons, `ox_target` remplace
qb-target). **Mono-personnage** (pas de `esx_multicharacter` → `Config.Multichar` auto-désactivé),
identité via `esx_identity`, apparence via `illenium-appearance`, spawn via `spawnmanager` (natif).
Concepts **ESX par défaut** (jobs/shops standard), monnaie `$`, comptes ESX **money/bank/black_money**
uniquement (**pas de momo/kubi**), locale FR via `setr esx:locale "fr"`.

**Installation** : [`scripts/install-resources.sh`](scripts/install-resources.sh) (réécrit ESX) —
`install_esx_core` clone le **monorepo `esx_core`** et **aplatit** ses dossiers catégorie dans
`data/resources` ; `install_release_zip` ; `RESOURCES` clone esx_identity + les standalone conservés
(PolyZone, interact-sound, rpemotes-reborn, LegacyFuel). Le **schéma ESX de base** est **versionné**
dans [`sql/esx-base.sql`](sql/esx-base.sql) (users/jobs/job_grades/user_licenses/owned_vehicles),
importé à la place de qbcore.sql ; `import_custom_sql` importe le SQL des `ubuntu-*`.
⚠️ **Pins ESX à confirmer en live** (posés sans réseau — cf. en-tête du script). **Aucun override**
n'est nécessaire en Phase 1 (défauts ESX). Ordre des `ensure` : [`config/server.cfg.template`](config/server.cfg.template).

**Ressources maison portées (ESX/ox)** — toutes en `local ESX = exports['es_extended']:getSharedObject()`,
callbacks/notify via `ox_lib` (`lib.callback`, `lib.registerContext`, `lib.notify` / `ox_lib:notify`),
i18n via un **shim `locales/locale.lua`** (reproduit `Lang:t('a.b', {var})` avec `%{var}`, lit `Locales`
depuis fr.lua/en.lua) :
- **`ubuntu-premium`** : boutique de dons « **Points** » (plus « Kubi »). Points stockés dans une
  **table propre** `ubuntu_premium_data(identifier, points, data)` (ESX n'a pas de metadata) —
  **pas de compte ESX**. Crédit par **`/addpoints`** + export **`AddPoints`**. **Livraison des achats
  (corrigée, ne pas re-dériver)** : véhicules → INSERT `owned_vehicles` (schéma ESX) **+ spawn immédiat**
  côté client (`client:spawnVehicle`, devant le joueur) car **aucun garage n'existe** encore. Tenues →
  **skin complet stocké** dans `data.outfits` (pas seulement le nom) + `data.lastOutfit` ; re-portables
  à volonté via **`/tenues`** (menu `lib.registerContext`, callback `getOutfits`) et **ré-appliquées au
  (re)spawn** ; l'application native est la fonction locale `applyOutfit` (client). VIP → `data.aceGroup`
  mémorisé et principal ace **ré-appliqué à chaque `esx:playerLoaded`** (durable across reconnexions).
  Perks confort → lisibles par d'autres ressources via exports **`GetPerks`/`GetRank`/`GetPremiumData`**
  (inertes tant qu'aucun garage/garde-robe ne les consomme). Aucun changement SQL (tout dans la colonne
  `data`).
- **`ubuntu-admin`** : panel staff gaté par **groupe ESX** (`xPlayer.getGroup()` ∈ admin/superadmin/mod),
  `ESX.GetExtendedPlayers`/`setJob`/comptes ; **table `bans` propre** (`bans.sql`) + check `playerConnecting`.
  Bouton « Points » → `exports['ubuntu-premium']:AddPoints`.
- **`ubuntu-interface`** : menu F1 via `lib.registerContext`, `isStaff` via groupe ESX (`lib.callback`),
  init sur `esx:playerLoaded`, blips **génériques** (sans noms camerounais). **Solde du menu pause
  (déjà câblé, ne pas re-dériver)** : ESX ne synchronise pas les stats natives GTA du menu pause →
  figées à 0. `ubuntu-interface` lit les comptes ESX `money`/`bank` (mis à jour en direct par
  `esx:setAccountMoney`, y compris quand le cash change via ox_inventory — le bridge ox fire l'event
  « Sync account with item ») dans un cache `cachedCash/cachedBank` et pousse
  `MP0_WALLET_BALANCE`/`BANK_BALANCE` (`pushMoneyStats`, drapeau `Config.PauseMenu.syncMoney`, garde-fou
  périodique). **Pas de HUD à l'écran** (un HUD NUI avait été ajouté puis **retiré à la demande** de
  l'utilisateur). ⚠️ L'argent vit bien dans `users.accounts` (backend économie sain) : le bug initial
  « solde à 0 » était **purement un défaut d'affichage**.
- **`ubuntu-location`** : compte `money`, menu `lib.registerContext`, points **génériques**. Clés véhicule
  = brancher un export de ressource de clés ESX si présente (sinon conduite libre).
- **`ubuntu-banque`** : **banque ESX** (aucune n'existait). **100 % serveur-authoritative** — le client
  n'envoie qu'un montant/une cible, le serveur revalide tout et applique l'argent via l'API ESX
  (`xPlayer.getAccount`/`addAccountMoney`/`removeAccountMoney`) → cash ox_inventory + compte `bank` restent
  synchronisés (le HUD `ubuntu-interface` se met à jour tout seul via `esx:setAccountMoney`). **Guichets**
  (PNJ + blip + E, réutilisent les emplacements « Banque ») : menu `lib.registerContext` Solde / Déposer
  (cash→bank) / Retirer (bank→cash) / **Virement** (bank→bank, par **id de joueur connecté**, frais
  `Config.Transfer.feePercent`). **ATM** = ciblage **`ox_target`** sur les props distributeurs
  (`prop_atm_0*`/`prop_fleeca_atm`, retrait/dépôt/solde, sans virement). Montants saisis via `lib.inputDialog`,
  sanitizés + bornés (`Config.MaxAmount`) + throttle (`Config.Cooldown`) côté serveur. **Journal**
  `ubuntu_bank_transactions` (`banque.sql`, importé par `import_custom_sql`). `ensure` après `ubuntu-location`
  (dépend de `ox_target`). Les 2 blips « Banque » ont été **retirés d'`ubuntu-interface`** (doublon).
  Ajouter un guichet/ATM = 1 entrée dans `Config.Tellers`/`Config.Atm`.
- **`ubuntu-antichute`** : écoute `esx:playerLoaded`/`playerSpawned` + **ferme le loadscreen**
  (`ShutdownLoadingScreenNui`, plus de multichar pour le faire).
- **`ubuntu-loadscreen`** : dé-thématisé (accent indigo, sans drapeau/FCFA/MoMo).

**Phase 2 (métiers + illégal) — FAITE :**
- **Métiers ESX** : `esx_addonaccount` + `esx_society` (comptes société) et `esx_policejob` +
  `esx_ambulancejob` ajoutés au `RESOURCES` et `ensure` (leurs jobs viennent de leur propre SQL,
  importé par le scan générique). Métiers additionnels (mécano/trucker/taxi/garbage : dépôts ESX
  historiques) laissés **commentés** dans `RESOURCES` + template (refs à confirmer).
- **`ubuntu-braquages`** & **`ubuntu-drogue`** portés ESX/ox (mêmes patrons) : police en service via
  `ESX.GetExtendedPlayers` + `xPlayer.job.name == 'police'` (+ `job.onDuty ~= false`), butin/argent
  sur le compte `money`, items via **ox_inventory** (`GetItem`/`RemoveItem`/`AddItem`), barre de
  progression **`lib.progressBar`** (braquages), menu grossiste **`lib.registerContext`** (drogue),
  alertes `ox_lib:notify` + blips. Cibles/zones **dé-thématisées**.
- **Items ox_inventory** : `append_ox_items` (dans `install-resources.sh`, idempotent via marqueur)
  **ajoute** `joint`/`xtcbaggy`/`crack_baggy`/`coke_baggy`/`electronickit`/`thermite` juste après le
  `return {` de `ox_inventory/data/items.lua` (sans remplacer le fichier).

**Phase 3 — STAGÉE (désactivée) :** téléphone **npwd** (+ pma-voice) et **housing** (loaf_housing/
esx_property) câblés en **blocs commentés** dans `install-resources.sh` (section Phase 3) et
`config/server.cfg.template` — à préparer + `ensure` après validation en jeu. HUD/météo = défauts
ESX/ox suffisants (polish optionnel).

**Ajouter un article premium** = 1 entrée `Config.Catalog`. **Ajouter un point de menu/blip/location/
cible/zone** = 1 entrée dans le `config.lua` concerné (data-driven). **Ajouter un item drogue/braquage**
= 1 ligne dans `append_ox_items` + `Config.Products`/`requiredItem`.

---

## Couche RP QBCore (HISTORIQUE — référence uniquement)

> ⚠️ Section **historique** décrivant l'ancienne architecture QBCore. **Ne s'applique plus** aux
> parties migrées (Phase 1, voir ci-dessus). Reste pertinente pour comprendre `ubuntu-braquages` /
> `ubuntu-drogue` (encore QBCore, **non chargés**, à porter en Phase 2) et l'historique.

**Modèle d'installation** : [`scripts/install-resources.sh`](scripts/install-resources.sh)
(cible `make resources`, **idempotent**) clone chaque ressource officielle à une **révision épinglée
(SHA/tag)** dans `data/resources/<catégorie>/` (`[standalone]`/`[core]`/`[economy]`/`[jobs]`), recalibre
les prix véhicules en FCFA (×300), applique les **overrides**, puis importe le SQL dans MariaDB.

**Ce que le dépôt versionne vs génère :**
- ✅ [`resources/[custom]/`](resources/) — nos ressources maison, montées dans le conteneur via un
  **bind imbriqué** `./resources:/opt/fivem/resources/[ubuntu]` (voir `docker-compose.yml`).
- ✅ [`overrides/`](overrides/) — fichiers de config **complets** (pas des patches) **copiés par-dessus**
  les clones par le script : `qb-core/config.lua` (MoneyTypes + `momo`, argent de départ FCFA),
  `qb-core/shared/jobs.lua` (métiers FR/Afrique, salaires FCFA), `qb-shops/config.lua` (supérette/
  maquis/marché/boulangerie, prix FCFA), `qb-taxijob/config.lua` (moto-taxi scooter),
  `qb-multicharacter/` (`html/index.html` + `html/vendor/` + `fxmanifest.lua` : libs UI rapatriées, cf.
  point d'attention ci-dessous).
- ❌ `data/resources/` — **gitignoré**, rempli par le script (clones officiels).

**Points d'attention :**
- **Cohérence des pins** : les dépôts `qb-*` évoluent ensemble → épingler des refs contemporaines.
  Le tableau `RESOURCES` du script est la source de vérité ; re-run = re-pin.
- **Dépendances dures** découvertes au boot : `qb-inventory` requiert `qb-weapons`, `qb-apartments`
  requiert `qb-interior` (inclus dans l'ensemble épinglé) ; `qb-phone` requiert `qb-apartments`
  (chargé avant lui dans le template).
- **Interface joueur (touches & carte)** : `qb-hud` (HUD statut + **minimap QBCore permanente**,
  commande `menu`) et `qb-phone` (téléphone, touche `Open Phone` via `RegisterKeyMapping`, rebindable
  dans *Paramètres > Touches*) sont épinglés dans le tableau `RESOURCES`. `qb-hud` s'`ensure` juste
  après `qb-core`, `qb-phone` après `qb-banking`. Les tables `phone_*`/`player_contacts` sont fournies
  par le `qbcore.sql` importé (pas de SQL propre). Sans `qb-hud`, la minimap (et donc les blips des
  services) ne s'affichait qu'en véhicule.
- **NUI dépendant de CDN → écran noir (piège majeur)** : l'UI de `qb-multicharacter` (pin `772d5eb`)
  est une app **Vuetify** qui charge `vuetify.js`/`vuetify.min.css` + `axios` depuis des **CDN externes**.
  Si le client ne peut pas les atteindre, `<v-app>` reste vide → **écran noir à la création de perso**
  (la souris est prise mais rien ne se dessine). Corrigé via un **override** : les libs sont rapatriées
  dans `overrides/qb-multicharacter/html/vendor/` et `index.html`/`fxmanifest.lua` patchés pour les servir
  en local (`vue.js` était déjà local ; la police Material Symbols reste en CDN = cosmétique). ⚠️ Si on
  bump le pin, ré-aligner ces deux fichiers d'override sur la nouvelle version. Réflexe pour toute NUI
  ajoutée : **vendrer les libs** (pas de `<script src="https://cdn…">`).
- **Devise FCFA (jamais « $ »)** : l'étape `normalize_currency()` de `install-resources.sh` réécrit le
  symbole `$` en `FCFA` sur les clones, en deux couches : (a) **globale** sur les `.lua` pour les motifs
  interpolés sûrs (`$%{x}`/`$%s`/`$%d` → suffixe ` FCFA`) + règles sur les **fichiers de langue** seuls
  (montants codés en dur, `($)`, libellés `: $`) ; (b) **ciblée par fichier** pour les NUI et cas
  particuliers (`qb-hud`, `qb-banking`, `qb-garages`, `qb-taxijob` `meter.js`, `LegacyFuel`, et surtout
  **`qb-phone`** dont la devise passe par l'entité `&#36;`). ⚠️ Ne **jamais** faire un `s/\$/FCFA/`
  global : `$` est aussi du code (motif Lua `gsub`, `$(` jQuery, `${}` template JS, liste de caractères
  bannis, table de largeurs NativeUI). Idempotent. Réécrire une NUI ajoutée = penser à sa devise ici.
- **Import SQL** : schéma agrégé `qbcore.sql` (dépôt `txAdminRecipe`, URL pinnée) + les `*.sql` des
  ressources (non-fatals, `migrate*`/`*upgrade*` exclus). Marqueur `data/.qbcore-sql-imported`
  (le supprimer force un ré-import).
- **Ajouter une ressource** = 1 ligne `catégorie|nom|url|ref` dans le script + 1 `ensure <nom>` dans
  le template (ordre : `oxmysql` → `qb-core` → le reste).
- **oxmysql** se récupère en **release buildée** (zip), pas en clone source.
- `setr qb_locale "fr"` (dans le template) active la locale FR des ressources qb-*.

### Thème RP (décisions fermes de l'utilisateur) — Cameroun / Afrique centrale
- **Monnaie franc CFA**, montants **entiers**.
- **Mobile money** : ressource [`resources/[custom]/ubuntu-mobilemoney`](resources/) — monnaie `momo`
  (déclarée dans qb-core), provider **MoMo** (à la MTN MoMo / Orange Money), commande `/momo` (solde,
  transfert entre joueurs frais 1 %, dépôt/retrait aux **points MoMo**). Logique **entièrement côté
  serveur** (les events client ne portent que des intentions).
- **Enseignes/institutions camerounaises réelles** : Police Nationale, SAMU, moto-taxi (**bendskin**),
  **HYSACAM** (propreté), **CFAO Motors** (concession), **SOCATUR**/**CRTV**/**CDC**/**CAMRAIL** (jobs),
  supermarchés **DOVV/Mahima/Santa Lucia**, stations **Tradex**, **Marché Mokolo**, maquis/tournedos,
  quartiers de Douala (Bonabéri, Ndokoti, Akwa, Bépanda).
- **Textes en français** partout.

## Ressources maison (déjà câblées — ne pas re-dériver)

Toutes dans [`resources/[custom]/`](resources/) (versionnées, montées via le bind `[ubuntu]`), même
pattern que `ubuntu-mobilemoney` : **logique 100 % serveur-authoritative**, locales fr/en, `config.lua`.

### `ubuntu-premium` — boutique premium (monnaie « Kubi »)

- **Catalogue = source de vérité serveur** (`config.lua > Config.Catalog`) : le client n'envoie que
  l'`id` ; coûts, effets et possession (`oneTime`) sont validés/appliqués côté serveur. Types :
  `bundle` (3 **starter packs** Urban/Corporate/Young = véhicule + tenue), `cosmetic` (tenue insérée
  dans `player_outfits`), `vehicle` (insert `player_vehicles`, **mods neutres**, aucune performance),
  `rank` (grade VIP → `metadata.premium.rank` + principal ace), `perk` (slots → `metadata.premium.perks`).
- Possession/état persistés dans `metadata.premium` (qb-core) ; audit dans **`ubuntu_premium_purchases`**
  (schéma `premium.sql`). NUI `/boutique` (ou PNJ + blip, **boutique visitable**). ⚠️ Ajouter un
  article = 1 entrée dans `Config.Catalog` (rien d'autre).
- **Véhicules custom & vêtements spéciaux** : le catalogue inclut des `vehicle` de collection (SUV,
  sportive, moto) et des `cosmetic` thématisés (Lions Indomptables, Boubou, Drapeau). Un vrai véhicule
  **add-on** = remplacer `payload.vehicle.model` par le nom du modèle **streamé** (fichiers du car pack
  fournis/streamés par le serveur) ; l'insert reste à **mods neutres** (non pay-to-win).

### `ubuntu-admin` — panel de gestion des joueurs (staff)
- NUI `/admin` (keybind défaut **F6**), **gated par permissions ace** (`Config.AllowedGroups` =
  `god`/`admin`/`mod`, via `QBCore.Functions.HasPermission`). **Chaque action est revérifiée côté
  serveur** — jamais de confiance client (le client ne fait qu'afficher + exécuter les effets locaux
  poussés par le serveur : revive/heal/freeze/teleport/spectate).
- Actions : kick, **ban** (INSERT `bans` → rejet géré par qb-core au `playerConnecting`), argent
  (cash/bank/momo/**kubi** via l'export premium), job & grade (validés contre `QBCore.Shared.Jobs`),
  aller/amener (coords serveur-side OneSync), observer, réanimer/soigner/geler, annonce globale.
- **Logs Discord** de chaque action via le webhook `discord_webhook` (convar déjà dans le template).
- **Ordre de chargement** : `ubuntu-premium` **avant** `ubuntu-admin` (export `AddKubi`) — respecté
  dans [`config/server.cfg.template`](config/server.cfg.template).

### `ubuntu-antichute` — anti-chute au spawn (client-only)
- **Corrige** le bug « le perso tombe / reste au sol au spawn, alerte SAMU perte de sang, réveil sur un
  lit d'hôpital, puis chute libre dans les égouts ». Cause : `qb-spawn`/`qb-multicharacter` placent le
  joueur (`SetEntityCoords`) puis le **dégèlent avant que la collision de la map soit streamée** → chute
  à travers le sol → dégâts de chute → `qb-ambulancejob` le passe en blessé/mort → hôpital.
- **Aucune logique serveur, aucune dépendance SQL.** Sur `QBCore:Client:OnPlayerLoaded`, re-gèle le ped
  et boucle `RequestCollisionAtCoord` jusqu'à `HasCollisionLoadedAroundEntity` (garde-fou 15 s, ré-affirme
  le gel à chaque tick pour gagner la course contre le `FreezeEntityPosition(false)` de qb-spawn) avant de
  relâcher. Couvre nouveau perso / reconnexion / réanimation. **Ne modifie aucun fichier upstream** (survit
  à un re-pin). `ensure` **juste après `qb-spawn`** dans le template. **Note** : un perso déjà persistant
  en état « mort » en base se réveillera une dernière fois à l'hôpital après le correctif, puis c'est réglé.

### `ubuntu-loadscreen` — écran de chargement thématisé
- Ressource **NUI `loadscreen`** (pas de logique serveur, aucune dépendance) : `ensure` **en tête** du
  bloc ressources du template pour s'afficher au plus tôt. Thème Cameroun (accents drapeau, logo
  « UBUNTU RP », « Douala • Afrique centrale »), barre de progression pilotée par les events loadscreen
  FiveM, astuces RP rotatives (fr), et **musique d'attente** en boucle (bouton mute mémorisé, dégradation
  silencieuse si absente).
- **Médias** dans `html/assets/` (versionnés) : `background.jpg` (fond, voile sombre CSS) + `music.mp3`
  + **`logo.png`** (512×512, logo officiel Ubuntu RP, déclaré dans `files{}`). L'`<img>` du logo masque
  le `<h1>` texte via son `onload` (et `onerror` rebascule sur le texte si le fichier manque). Remplacer
  un média = même nom de fichier + reload. Voir `html/assets/README.md`.
- **`loadscreen_manual_shutdown 'yes'`** (dans le template, juste avant `ensure ubuntu-loadscreen`) est
  **indispensable** pour que le loadscreen reste visible : sinon FiveM le ferme dès que la session est
  prête → il ne s'affiche qu'une fraction de seconde. Avec `manual_shutdown`, il persiste tout le
  chargement et n'est fermé que par `qb-multicharacter` (`ShutdownLoadingScreenNui()`, déjà appelé à la
  sélection de perso). ⚠️ Côté client, le loadscreen est **mis en cache** : un simple reconnect ne le
  rafraîchit pas — **redémarrer complètement FiveM** (ou vider le cache) après un changement.
- **Icône serveur** (distincte du loadscreen) : PNG **96×96** `config/server-icon.png` (même logo Ubuntu
  RP), activée par `load_server_icon "/opt/fivem/config/server-icon.png"` (chemin **absolu** = fiable
  sous txAdmin, `config/` monté via `./config:/opt/fivem/config`). Régénérer icône + logo depuis une
  source carrée : `PIL` → resize 96×96 et 512×512 (cf. CHANGELOG 1.8.3).

### `ubuntu-interface` — interface joueur (menu F1, menu pause, carte)
- **Aucune logique serveur sensible** (juste un callback `isStaff`) ; **data-driven** via `config.lua`.
  Dépend de `qb-core` + `qb-menu`. `ensure` **après `ubuntu-admin`** (le menu appelle `/admin`,
  `/boutique`, `/momo` à l'exécution, pas au load → l'ordre n'importe que pour la lisibilité).
- **Menu principal (F1)** : commande `menuprincipal` mappée par défaut sur **F1**
  (`RegisterKeyMapping`, rebindable dans *Paramètres > Touches*), construite avec **qb-menu** à partir
  de `Config.MainMenu.items` (chaque entrée = une `command` existante, un sous-menu `type=locations`,
  ou `type=help`). L'entrée « Panel Admin » (`staffOnly`) n'apparaît que si le callback serveur
  `ubuntu-interface:server:isStaff` (permission ace `god`/`admin`/`mod`) répond `true` — jamais de
  confiance client, et `ubuntu-admin` re-valide de toute façon.
- **Menu pause (Échap)** : `AddTextEntry('FE_THDR_GTAO', Config.PauseMenu.title)` remplace le libellé
  de l'onglet du menu pause par l'identité du serveur (réappliqué au load + player-loaded).
- **Carte** : `Config.Blips` = liste **curatée** des points d'intérêt du serveur (institutions,
  banques, concession/garage/bendskin, commerces, stations, marché) créés au load ; **s'ajoutent** aux
  blips déjà posés par les autres ressources (magasins, banque, boutique premium, MoMo…). Chaque blip
  `menu = true` alimente le sous-menu **« Se repérer »** (F1 → pose un `SetNewWaypoint`). Ajouter un
  point = 1 entrée dans `Config.Blips` (rien d'autre). Blips retirés proprement au `onResourceStop`.

### `ubuntu-location` — location de véhicules (bateau / scooter / vélo)
- **100 % serveur-authoritative**, monnaie `cash`, tarifs **FCFA**, **caution remboursée à la
  restitution**. Dépend de `qb-core` + `qb-menu` (clés via `qb-vehiclekeys`). `ensure` après
  `ubuntu-mobilemoney`. Aucun SQL (locations en mémoire serveur).
- **Data-driven** via `config.lua > Config.Points` : chaque point = PNJ + blip + marqueur de
  proximité (`E`) + une liste de `vehicles` (`model`/`label`/`fee`/`deposit`). Points thématisés :
  **Port de Douala** (`boat`, spawn sur l'eau), **Akwa** (`scooter`), **Bonanjo** (`bike`). Ajouter
  un point/véhicule = 1 entrée dans `Config.Points`.
- **Flux** : le client envoie l'intention (`server:rent` pointId+model) → le serveur valide, débite
  `fee + deposit`, génère une plaque, mémorise la location (`Rentals[plate]`) et pilote l'apparition
  (`client:spawnRental`) ; la **restitution** (`client:returnVehicle` → `server:return`) supprime le
  véhicule loué proche et rembourse la caution. Coords des `spawn` (surtout bateau, sur l'eau) à
  affiner en jeu.

### `ubuntu-braquages` — braquages (supérettes / distributeurs / banques)
- **100 % serveur-authoritative**, monnaie `cash`, butin **FCFA**. Dépend de `qb-core` + `qb-policejob`.
  `ensure` **après `qb-policejob`**. Aucun SQL, **aucun nouvel item** (réutilise `electronickit`/
  `thermite` déjà dans `qb-core/shared/items.lua`).
- **Data-driven** via `config.lua > Config.Targets` : chaque cible = `{ type, coords, label, duration,
  cooldown, minPolice, reward{min,max}, needWeapon?, requiredItem? }`. Types : `till` (supérettes
  DOVV/Mahima/Santa Lucia, à main armée), `atm` (Tradex/Bépanda, kit électronique), `bank`
  (Atlantique/Afriland, thermite, `minPolice` élevé). Ajouter une cible = 1 entrée.
- **Flux** : client envoie l'intention (`server:start` targetId) → **le serveur valide TOUT** (distance,
  cooldown par cible, seuil `minPolice` = policiers **en service**, consommation de l'item), tire le
  butin, **alerte la police** (notif + blip clignotant temporaire chez chaque policier en service via
  `client:alert`) et lance la barre de progression (`client:begin`). `server:finish` re-valide la durée
  (anti-« finish » instantané) avant de créditer. Cooldowns/braquages actifs **en mémoire serveur**.

### `ubuntu-drogue` — économie illégale (vente de drogue de rue)
- **100 % serveur-authoritative**, monnaie `cash`. Dépend de `qb-core` + `qb-menu` + `qb-inventory` +
  `qb-policejob`. `ensure` **après `qb-policejob`**, avant `ubuntu-location`. Aucun SQL, **aucun nouvel
  item** : `Config.Products` mappe des **baggies qb-core existants** (`joint`/`xtcbaggy`/`crack_baggy`/
  `coke_baggy` — éditer la clé si un nom diffère sur le build).
- **Vente aux PNJ** uniquement dans des **zones chaudes** (`Config.Zones` : Ndokoti, Bépanda, Bonabéri,
  abords Marché Mokolo ; `priceMult`/`heatMult`). Le client détecte le PNJ le plus proche + envoie
  l'intention (`server:sell` zoneId) ; **le serveur** vérifie la possession, calcule le **prix dynamique**,
  retire l'item, crédite le cash et incrémente la **chaleur** (`heat` par citizenid, décroît chaque
  minute). Au **seuil** → **alerte Police** (`client:alert`) + blocage « lay low ». **Grossiste**
  (`Config.Supplier` : PNJ + blip discret + menu **qb-menu**) pour s'approvisionner moins cher (la marge
  = le gameplay). Throttle anti-spam serveur (`SellCooldown`). État (heat/cooldown) **en mémoire serveur**.

> **Menu d'emotes** : **`rpemotes-reborn`** (standalone, support QBCore) est épinglé dans le tableau
> `RESOURCES` et `ensure` après `interact-sound`. Menu d'animations le plus populaire (`/e`, danses,
> gestes, mains en l'air, walkstyles) — **0 SQL**, touche « Emote Menu » rebindable. Externe → clone
> épinglé (pas une ressource maison).

> **Stack Housing (`ps-housing`) — INSTALLÉE MAIS DÉSACTIVÉE.** Pins présents dans `RESOURCES`
> (`fivem-freecam` fork **Deltanic**, `ps-realtor`, `ps-housing` tag `2.0.7`) + `ox_lib` v3.38.0
> (release buildée, fonction `install_ox_lib` calquée sur `install_oxmysql`) + import SQL dédié
> `import_housing_sql` (`properties.sql` niché, variante **QBCore**, marqueur `data/.ps-housing-sql-imported`).
> Le bloc `ensure ox_lib / fivem-freecam / ps-realtor / ps-housing` est **commenté** après
> `qb-apartments` dans le template : `ps-housing` est **archivé** (fév. 2026), streame des shells MLO
> et introduit `ox_lib` (le serveur est sinon volontairement sans ox_lib). **À valider en jeu** (achat,
> entrée, coffre) avant activation → décommenter les 4 lignes. `qb-target` (déjà chargé) suffit comme
> système target.

> **Métiers (boulots)** : les ressources de gameplay **`qb-policejob`** (Police Nationale),
> **`qb-ambulancejob`** (SAMU — gère aussi mort/réanimation), **`qb-mechanicjob`** et
> **`qb-truckerjob`** sont épinglées dans le tableau `RESOURCES` et `ensure` après `qb-garbagejob`.
> Elles s'appuient sur les métiers **déjà déclarés** dans
> [`overrides/qb-core/shared/jobs.lua`](overrides/qb-core/shared/jobs.lua) (clés `police`, `ambulance`,
> `mechanic`, `trucker`). Dépendances (qb-core/PolyZone/oxmysql) déjà présentes ; pas de SQL propre.

> **SQL des ressources `[custom]`** : contrairement aux clones (`data/resources`), leurs `.sql` sont
> importés par une étape dédiée de [`scripts/install-resources.sh`](scripts/install-resources.sh)
> (idempotente, `CREATE TABLE IF NOT EXISTS`, rejouée à chaque `make resources`).

## Vérification (sans client GTA)

```bash
docker compose run --rm -e TXADMIN_ENABLE=false fivem
# attendu : ~33 lignes "Started resource ..." (dont rpemotes-reborn, ubuntu-braquages, ubuntu-drogue,
# ubuntu-loadscreen, ubuntu-premium, ubuntu-admin & ubuntu-interface), 0 "Couldn't start",
# oxmysql "connection established". NB : la stack Housing (ps-housing) est désactivée → n'apparaît pas.
docker compose exec mariadb mariadb -ufivem -p<pass> fivem -e "SHOW TABLES;"   # players, player_vehicles, bans, ubuntu_premium_purchases...
```

Le test en jeu (création de perso, `/momo`, `/boutique`, `/admin`, `/e` emotes, braquage, deal, achats,
job moto-taxi) nécessite un vrai client FiveM.

## Wiki joueur ([`wiki/`](wiki/))

Site statique multi-pages (aucun build) : `index / demarrer / reglement / economie / metiers /
commandes / faq`, CSS partagé dans `wiki/assets/`. **Orienté joueur** : aucun secret ni détail
d'infra. Les montants/frais/métiers y reflètent la config RP — **les mettre à jour si la config change**.
Placeholders à personnaliser : adresse `adresse-du-serveur:30120` et le lien Discord.

## Conventions

- **Toute la config passe par `.env`** (secrets, gitignoré). Aucun secret en dur ; changer les
  `change-me-*` avant la prod.
- **I18n** : nouveaux textes RP en **fr** (+ en) ; le serveur tourne en locale `fr`.
- **Idempotence** : les scripts (`install-resources.sh`, `backup.sh`) doivent pouvoir être relancés.
- **CI** ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) : shellcheck (`scripts/*.sh` +
  entrypoint), hadolint, `docker compose config`, build/push GHCR, déploiement SSH optionnel.

## Follow

Mettre à jour **ce `CLAUDE.md`** ET le **[`CHANGELOG.md`](CHANGELOG.md)** à chaque changement critique
(nouvelle ressource/feature RP, changement d'infra, nouveau pin marquant).
