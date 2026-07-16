# Changelog

Toutes les évolutions notables d'**Ubuntu RP** (plateforme Docker FiveM + couche RP).

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/). Ce projet suit
un versionnage sémantique souple : `MAJEUR.MINEUR.CORRECTIF`.

---

## [2.9.2] — 2026-07-16 — Nouveau logo officiel Ubuntu RP (partout) + nettoyage loadscreen

- **Nouveau logo** appliqué à **tous** les emplacements depuis une source carrée unique versionnée
  (`config/logo-source.png`, 610×610 RGBA transparent) :
  - `config/server-icon.png` (96×96) — icône du navigateur de serveurs FiveM / txAdmin.
  - `resources/[custom]/ubuntu-loadscreen/html/assets/logo.png` (512×512) — logo du loadscreen.
  - `wiki/assets/logo.png` (560×560) — logo du wiki (hero + footer).
- **Régénération reproductible** : script [`scripts/gen-logos.py`](scripts/gen-logos.py) (PIL, recadrage
  carré centré + Lanczos, transparence préservée) → `python scripts/gen-logos.py config/logo-source.png .`
  régénère les 3 tailles. Remplacer le logo = remplacer `config/logo-source.png` + relancer.
- **Loadscreen — barre d'accent retirée** : la fine **ligne violette** fixée en haut de l'écran de
  chargement (`.flag-bar`/`.flag-accent`, reliquat d'habillage) est supprimée du HTML et du CSS.
- ⚠️ **Cache client** : loadscreen mis en cache côté client → **redémarrer complètement FiveM** pour
  voir le nouveau logo/loadscreen (l'icône serveur et le wiki, eux, se rafraîchissent sans ça).

## [2.9.1] — 2026-07-16 — PNJ & marqueurs calés au sol (fini les points flottants / mal placés)

- **Cale-sol runtime des PNJ + marqueurs** : plusieurs points d'intérêt (info, location de bateau,
  guichets, garage, boutique, grossiste, cibles de braquage…) apparaissaient **flottants, enterrés
  ou décalés** parce que le `Z` codé dans les `config.lua` ne correspondait pas exactement au sol
  réel de la map. Ajout d'un helper **`groundSnap`** dans les 8 ressources concernées
  (`ubuntu-location`/`garage`/`banque`/`academie`/`mairie`/`premium`/`drogue`/`braquages`) : dès que
  le joueur s'approche (map streamée → `GetGroundZFor_3dCoord` fiable), le PNJ **et** le marqueur
  sont **reposés sur le sol réel**. Idempotent (résultat mis en cache) et **prudent** : on ne déplace
  jamais un PNJ vers le niveau de la mer si le sol n'est pas trouvé, ni de plus de **12 m** (repli =
  Z de config). Aucun changement de logique métier, uniquement le rendu/placement.
- **Chevauchement corrigé** : le PNJ de **location de scooter** (`ubuntu-location`) était à ~1 m du
  PNJ du **garage Legion** (`ubuntu-garage`) → les deux modèles se télescopaient. Le scooter est
  déplacé sur le **bord nord dégagé de la place Legion** (`vector4(199.0, -875.0, 30.7, 160.0)`).
- **Relocalisations XY (coordonnées connues/accessibles, sourcées)** — les points suivants étaient à un
  **mauvais XY** (le cale-sol ne suffit pas) et sont déplacés vers des emplacements accessibles vérifiés :
  - **Mairie** (`ubuntu-mairie`) : `-545.9,-204.9` (pas la vraie mairie) → **Hôtel de ville canonique**
    `-262.79, -964.18, 30.22, 181.71` (emplacement `qb-cityhall`, trottoir devant l'entrée, accessible).
  - **Grossiste drogue** (`ubuntu-drogue`) : `-598,-1622,33` (Z flottant) → `-586.74, -1601.01, 27.01`
    (entrepôt bord de rivière, spot `esx_drugs` vérifié, Z au sol).
  - **Pharmacie publique** (`ox_inventory/data/shops.lua` + `install-resources.sh`) : `-661.32,-854.14`
    → **entrée piétonne hôpital Pillbox** `311.24, -593.52, 43.29` (accessible + thématique).
- **Note** : un point *à l'intérieur d'un mur* (mauvais XY, pas seulement mauvais Z) ne peut pas être
  détecté à coup sûr sans client GTA — signaler ses coordonnées en jeu pour le relocaliser précisément.

## [2.9.0] — 2026-07-16 — Mairie / centre pour l'emploi + niveau de recherche (étoiles) réactivé

- **Mairie fonctionnelle (`ubuntu-mairie`)** : jusqu'ici la « mairie » n'était qu'un **blip
  décoratif** dans `ubuntu-interface` — aucun PNJ, aucun menu → **impossible de prendre un métier**
  en jeu (seul `/admin` pouvait assigner un job, donc **impossible de devenir policier/EMS**).
  Nouvelle ressource maison [`resources/[custom]/ubuntu-mairie`](resources/) : PNJ « agent
  municipal » + blip + marqueur `[E]` à l'Hôtel de ville (Legion Square), menu **ox_lib** pour
  **prendre** (`police`, `ambulance`, `cardealer`…) ou **quitter** un métier (redevenir « sans
  emploi »). **100 % serveur-authoritative** : le client n'envoie qu'un nom de métier, le serveur
  revalide contre `Config.Jobs` (whitelist locale) + la garde `restricted` (staff) avant
  `xPlayer.setJob()`. Data-driven (ajouter un métier = 1 entrée `Config.Jobs` + son libellé
  `jobs.<name>` dans les locales fr/en). **Aucun SQL propre** (ESX persiste le job dans `users`).
  `ensure ubuntu-mairie` après `ubuntu-academie` dans
  [`config/server.cfg.template`](config/server.cfg.template) ; le **blip Mairie décoratif est retiré
  d'`ubuntu-interface`** (le doublon, comme pour `ubuntu-banque`).
- **Niveau de recherche GTA (étoiles) réactivé** : ESX Legacy livre `Config.EnableWantedLevel =
  false`, qui appelait `SetMaxWantedLevel(0)` au spawn → **jamais d'étoile** quand un crime est
  commis (ou qu'on tire sur un policier en public). **Override** complet
  [`overrides/es_extended/shared/config/adjustments.lua`](overrides/) avec `EnableWantedLevel = true`
  → les **étoiles réapparaissent** pour les crimes visibles. `DisableDispatchServices = true` reste
  actif (RP : on veut l'indicateur d'étoiles, **pas une armée de flics PNJ**). L'override est copié
  par-dessus le clone `es_extended` par `apply_overrides` de
  [`scripts/install-resources.sh`](scripts/install-resources.sh) (persiste au `make resources`).

## [2.8.0] — 2026-07-16 — Pharmacie publique payante + MLO intérieur d'hôpital (Pillbox)

- **Pharmacie civile** : jusqu'ici la seule pharmacie (`esx_ambulancejob`) et le shop `Medicine`
  d'ox_inventory étaient **réservés au job `ambulance`** → aucun civil ne pouvait acheter de soins.
  Ajout d'un **shop public `Pharmacie`** dans `ox_inventory/data/shops.lua` (sans `groups`, ciblé
  ox_target + blip) vendant **bandage (250 $)** et **medikit (1500 $)** — accessible à **tous les
  joueurs**. Injecté par une fonction **idempotente** `append_pharmacy_shop`
  ([`scripts/install-resources.sh`](scripts/install-resources.sh), marqueur `UBUNTU-RP pharmacie`,
  même patron qu'`append_phone_to_shop`/`append_weapons_to_ammunation`). Le shop EMS `Medicine`
  reste inchangé (réappro dédié des ambulanciers). Coord(s) de vente à affiner en jeu.
- **MLO intérieur d'hôpital** : le serveur tournait sur la **coquille Pillbox vanilla** (aucun
  intérieur jouable). Ajout du clone épinglé **`PillboxHospital`**
  (`jobscraft/PillboxHospital-by-Jobscraft`, map streamée, `[standalone]`) au tableau `RESOURCES`
  + `ensure PillboxHospital` (avant `esx_ambulancejob`) dans
  [`config/server.cfg.template`](config/server.cfg.template). L'MLO **remplace/nettoie la coquille
  vanilla** → **toutes les coords ESX** (blip, pharmacie EMS, vestiaire, spawns véhicules/héli,
  `RespawnPoints`, fast-travels) **restent valides** : amélioration **visuelle drop-in**, aucun
  reparamétrage. Asset lourd → va dans `data/resources` (gitignoré), rien de committé.
  ⚠️ Pas de tag amont (épinglé sur `master`, **noter le SHA en live**) ; **licence non explicite**
  → à vérifier avant usage public (alternative gratuite : `evgenius33/Pillbox-Hospital-Interior`).

## [2.7.1] — 2026-07-16 — Fix : loadscreen invisible (écran noir pendant le chargement)

- **Symptôme** : depuis la migration ESX, le loadscreen thématisé `ubuntu-loadscreen` ne s'affichait
  pas — **écran noir pendant tout le chargement**.
- **Cause racine (doc officielle Cfx.re)** : les directives de loadscreen
  (`loadscreen_manual_shutdown`, `loadscreen_cursor`) **doivent être dans le `fxmanifest.lua` de la
  ressource** — elles n'ont **aucun effet dans `server.cfg`**. Or `loadscreen_manual_shutdown 'yes'`
  était placé dans [`config/server.cfg.template`](config/server.cfg.template) → **ignoré**. De plus le
  HTML du loadscreen (`html/index.html`) **n'était pas déclaré dans `files{}`**, donc pas servi au
  client. Résultat : loadscreen non rendu → écran noir.
- **Fix** :
  - [`resources/[custom]/ubuntu-loadscreen/fxmanifest.lua`](resources/[custom]/ubuntu-loadscreen/fxmanifest.lua) :
    ajout de `loadscreen_manual_shutdown 'yes'` + `loadscreen_cursor 'yes'` (bouton mute) **dans le
    manifest**, et ajout de `'html/index.html'` à `files{}`.
  - [`config/server.cfg.template`](config/server.cfg.template) : **retrait** de la ligne
    `loadscreen_manual_shutdown 'yes'` (inutile/ineffective ici) + commentaire explicatif.
- **Timing du shutdown** ([`resources/[custom]/ubuntu-antichute/client.lua`](resources/[custom]/ubuntu-antichute/client.lua)) :
  maintenant que `manual_shutdown` est réellement actif, `ShutdownLoadingScreenNui()` n'est plus
  appelé dans les handlers `esx:playerLoaded`/`playerSpawned` (ils précèdent le streaming de la map)
  mais **à la fin** de `groundPlayerSafely()`, une fois la **collision chargée et le joueur posé au
  sol** (borné par le garde-fou 20 s → jamais bloqué). Fondu anti-flash `DoScreenFadeOut(0)` →
  `Wait(200)` → `ShutdownLoadingScreenNui()` → `DoScreenFadeIn(500)`. `shutdownLoadscreen` idempotent.
- ⚠️ **Cache client** : le loadscreen est mis en cache côté client → **redémarrer complètement FiveM**
  (pas un simple reconnect) pour voir le correctif.

## [2.7.0] — 2026-07-16 — Académie / centre d'accueil (`ubuntu-academie`) — tutoriels RP + onboarding des nouveaux joueurs

- **Nouvelle ressource maison `ubuntu-academie`** : un **PNJ « formateur »** (blip « académie »
  au centre-ville) à qui parler (`[E]`) ouvre un **menu de tutoriels** RP couvrant : *bienvenue /
  premiers pas*, *trouver un travail*, *se lancer dans l'illégal*, *acheter une voiture*, *acheter
  une maison*, *lancer ou acheter un business*. Chaque sujet s'affiche dans une fenêtre
  `lib.alertDialog` (contenu **markdown**, i18n fr/en via le shim `locales/locale.lua`).
- **Onboarding des nouveaux joueurs** : à la **première connexion** (identifier absent de la table
  **`ubuntu_academy_seen`**), le serveur envoie une **notification** invitant le joueur à se rendre
  à l'académie + pose un **itinéraire GPS** clignotant vers le point. Le joueur est marqué « vu »
  dès qu'il ouvre le menu (la relance ne réapparaît plus).
- **Pattern** : même socle que `ubuntu-garage`/`ubuntu-location` (PNJ + blip + marqueur de
  proximité, ESX/ox, `lib.registerContext`), **data-driven** (`Config.Points` + `Config.Tutorials`).
  Logique serveur minimale (aucune donnée sensible) : uniquement le suivi « déjà accueilli ».
  SQL propre `academy.sql` (`CREATE TABLE IF NOT EXISTS`, importé par `import_custom_sql`).
- **Câblage** : `ensure ubuntu-academie` après `ubuntu-interface` dans
  [`config/server.cfg.template`](config/server.cfg.template). Ajouter un tutoriel = 1 entrée
  `Config.Tutorials` + son texte dans `locales/*.lua` ; ajouter un point = 1 entrée `Config.Points`.

## [2.6.2] — 2026-07-14 — Fix : verrou d'un véhicule acheté au concessionnaire + sortie de la concession

- **Verrou (`ubuntu-garage`)** : la touche **U** ne verrouillait pas un véhicule acheté au
  concessionnaire (`esx_vehicleshop`). Cause : le cache client des plaques possédées (`ownedPlates`) était
  **périmé** après un achat hors garage. Fix : **dans un véhicule**, la touche cible le véhicule courant
  **sans** dépendre du cache (le serveur valide déjà la possession dans `owned_vehicles`) ; le cache est
  aussi **rafraîchi périodiquement** (30 s) pour le GPS + la détection à pied.
- **Sortie de la concession (`esx_vehicleshop`)** : au concessionnaire, le joueur était **coincé** (gelé,
  invisible, assis dans un véhicule d'expo) — la seule sortie était la touche « annuler » du menu, non
  visible. Ajout d'un **bouton « Quitter la concession »** en bas du menu d'achat (dégèle / rend visible /
  téléporte à l'entrée), + gardes pour ne pas planter sur l'aperçu du bouton. Appliqué au fichier live
  **et versionné** dans `overrides/esx_vehicleshop/client/main.lua` (⚠️ re-synchroniser si le pin
  `esx_vehicleshop` change).

## [2.6.1] — 2026-07-14 — Fix : armes à 0 balle à l'armurerie (armes pré-chargées + munitions complètes)

- **Symptôme** : après achat d'une arme **et** de munitions à l'armurerie, l'arme restait à **0 balle**.
- **Cause double** : (1) sous ox_inventory, acheter l'item munition ne remplit pas l'arme — il faut la
  **recharger en main (touche R)**, non intuitif ; (2) chaque arme exige un **type de munition précis**
  (`ammoname` dans `data/weapons.lua`) et l'arsenal 2.5.0 ne vendait pas `ammo-45` (SNSPISTOL/HEAVYPISTOL/
  MICROSMG) ni `ammo-rifle2` (ASSAULTRIFLE/COMPACTRIFLE).
- **Fix** :
  - **Armes pré-chargées** : chaque arme à feu de l'Ammunation civile est vendue avec
    `metadata = { registered = true, ammo = 250 }` → l'arme a des munitions **dès l'achat** (GTA plafonne
    au max de l'arme). `client.lua:75` lit `metadata.ammo` à l'équipement. Plus besoin de recharger pour
    tirer immédiatement. Appliqué dans `append_weapons_to_ammunation` (script) **+** `shops.lua` live.
  - **Munitions complètes** : `ammo-45` + `ammo-rifle2` ajoutés en rayon → **toutes** les armes vendues
    ont leur munition compatible pour se réapprovisionner (vérifié : mapping arme→`ammoname` 100 % couvert).
  - **Rechargement automatique** : `setr inventory:autoreload true` (`config/server.cfg.template`). Défaut
    ox_inventory = `false` → une arme **déjà achetée et vide** restait vide même avec des munitions en poche.
    Activé, l'arme se **recharge seule** depuis les munitions de l'inventaire quand le chargeur se vide
    (sinon rechargement manuel touche **R**, arme en main). Les armes achetées ont `durability = 100`
    (init `Items.Metadata`) donc le rechargement n'est jamais bloqué. Nécessite la régénération du
    `server.cfg` (redémarrage du conteneur `fivem`).

## [2.6.0] — 2026-07-13 — Garage : clés (verrou anti-vol) + GPS des véhicules sortis

Ajouts à **`ubuntu-garage`** (aucun SQL, aucune nouvelle dépendance).

- **Clés / verrou anti-vol** : touche **U** (`Config.Keys.key`, réassignable) verrouille/déverrouille
  un véhicule **possédé** (dans le véhicule ou le plus proche à pied). Le verrou est porté par un
  **statebag d'entité** `ubuntuLock` (réplicable → tous les clients l'appliquent via `SetVehicleDoorsLocked`,
  résiste au streaming). **Serveur-authoritative** : la possession est vérifiée dans `owned_vehicles`
  avant de basculer le statebag ; retour klaxon + phares au propriétaire.
- **GPS** : un **blip suit chaque véhicule sorti** du joueur sur la carte (`Config.Gps`). Le serveur
  suit les netId des véhicules sortis (`Spawned`, alimenté au spawn garage et à l'entrée d'un véhicule
  possédé) et renvoie leurs positions via OneSync (fonctionne même hors streaming du client) ; le client
  entretient/rafraîchit les blips (purge à la disparition/rangement du véhicule).

## [2.5.0] — 2026-07-13 — Permis d'arme (panel admin) + arsenal complet à l'armurerie

### Permis d'arme accordable par le staff (`ubuntu-admin`)
- **Contexte** : ox_inventory gate l'achat des armes à feu par `license = 'weapon'` (shop `Ammunation`).
  Le bridge ESX vérifie une ligne dans `user_licenses` (`type='weapon'`, `owner=xPlayer.identifier`),
  mais **aucune** n'était jamais créée (pas d'`esx_license`/DMV installé) → « Vous n'avez pas la licence
  pour acheter cet objet » systématique.
- **Nouvelle action `weaponlicense`** dans le panel admin (F6) : bouton **« Permis arme » → Accorder /
  Retirer** (modale `select`). Serveur-authoritative (revérifie la permission `guard(src)`), écrit dans
  `user_licenses` (`INSERT` idempotent / `DELETE`), log Discord + notif joueur. Aucune nouvelle table.
  Fichiers : `resources/[custom]/ubuntu-admin/{server.lua,html/app.js,locales/fr.lua,locales/en.lua}`.
- **Dépannage manuel** : `INSERT INTO user_licenses (type, owner) VALUES ('weapon', '<identifier>');`.

### Arsenal complet à l'armurerie civile (ox_inventory `Ammunation`)
- L'armurerie ne vendait que couteau/batte/pistolet. Nouvelle fonction idempotente
  **`append_weapons_to_ammunation`** (`scripts/install-resources.sh`, calquée sur `append_phone_to_shop`,
  marqueur `UBUNTU-RP arsenal`) : **AJOUTE** l'arsenal **standard** (armes blanches libres + pistolets /
  SMG / fusils d'assaut / pompes / snipers gatés `license='weapon'` + munitions `ammo-rifle/shotgun/
  sniper/heavysniper/50/44`), **SANS explosifs** (pas de RPG/minigun/grenades). Noms validés contre
  `ox_inventory/data/weapons.lua`. Appliqué via `make resources` → `restart ox_inventory`.

## [2.4.0] — 2026-07-13 — Métier EMS (`esx_ambulancejob`) activé — mort / réanimation / détresse

### `esx_ambulancejob` (métier ESX, monorepo `ESX-Legacy-Addons`)
- **Activé** — avant, à la mort d'un joueur **rien ne se passait** (aucun handler de mort). Désormais à la
  mort le joueur voit le **timer de respawn/bleedout** (respawn possible après `Config.EarlyRespawnTimer`
  = 60 s, saignement fatal à `Config.BleedoutTimer` = 10 min) et peut **envoyer un signal de détresse** aux
  **EMS en service** (notif + blip de détresse). Réanimation par un EMS avec `medikit`/`bandage`.
- **Dépendance dure `esx_skin` retirée par override** `overrides/esx_ambulancejob/fxmanifest.lua` :
  `esx_skin` a été retiré au profit de `fivem-appearance`, or le manifest amont le déclare en `dependencies`
  → la ressource refusait de démarrer. L'override copie le manifest **sans** la ligne `esx_skin`.
  **`fivem-appearance` fournit la compat `esx_skin` complète** (events `skinchanger:*` **+** callback serveur
  `esx_skin:getPlayerSkin`) → les appels du vestiaire EMS sont **réellement pris en charge**, le spawn/apparence
  n'est **pas** affecté. Seule limite non fatale (sans rapport avec mort/réanimation) : le callback renvoie
  1 arg `(appearance)` là où le vestiaire attend `(skin, jobSkin)` → l'**uniforme de métier EMS** ne s'applique
  pas complètement.
- **Install** : `esx_ambulancejob` ajouté à `${ESX_ADDONS[@]}` (`install-resources.sh`). Le **garde
  d'idempotence d'`install_esx_addons` vérifie maintenant que tous les dossiers d'addons voulus sont présents**
  (pas seulement le `.pin`) → ajouter un addon **re-déclenche le clone** même à pin inchangé. SQL
  `esx_ambulancejob.sql` (job/grades `ambulance`, `society_ambulance`, colonne `users.is_dead`) importé par le
  scan générique. Items `bandage`/`medikit` **déjà présents** dans `ox_inventory` (aucun ajout).
- **Template** : `ensure esx_ambulancejob` décommenté, **après `esx_policejob`**.

## [2.3.0] — 2026-07-13 — Garage personnel + refonte boutique premium (livraison garage / inventaire)

### `ubuntu-garage` (nouvelle ressource maison)
- **Garage personnel** — aucun n'existait (`esx_property` = par maison sans export d'injection,
  `esx_vehicleshop` = véhicules de métier). **100 % serveur-authoritative** : points data-driven
  (`Config.Garages`, PNJ+blip+E), menu ox_lib **Sortir** (`ESX.OneSync.SpawnVehicle` + `owned_vehicles.stored=0`,
  warp joueur) / **Ranger** (`stored=1` + suppression de l'entité). Valide la possession dans `owned_vehicles`.
  Aucun SQL propre. `ensure` après `ubuntu-banque`.

### `ubuntu-premium` — livraison corrigée + catalogue enrichi
- **Véhicules → garage** : `grantVehicle` insère dans `owned_vehicles` avec **`stored=1`** (récupérable
  via `ubuntu-garage`) et **ne spawn plus** immédiatement (handler client `spawnVehicle` retiré).
- **Objets → inventaire** : nouveau `type='item'` (`payload.items`) livré via `exports.ox_inventory:AddItem`
  avec **refund/notif si inventaire plein** ; `ox_inventory` ajouté aux dépendances.
- **Items premium** enregistrés (QoL non pay-to-win) : `premium_snack`/`premium_drink`/`premium_coffee`/
  `premium_giftbox` — dans `items.lua` (live) **et** le bloc versionné `append_ox_items` de `install-resources.sh`.
- **Catalogue enrichi** (data-driven, aucun SQL) : plus de véhicules (compacte→supercar, moto, 4x4,
  utilitaire), plus de tenues (bomber, costume…), **packs d'objets**, **packs mixtes** (véhicule+tenue+objets),
  **grade `vip_ultimate`**. Onglet **« Objets »** + icône NUI `ICONS.item`. i18n fr/en (`inventory_full`).

## [2.2.0] — 2026-07-13 — Phase 2 (métier POLICE) + Phase 3 (voix / téléphone / housing) activées

Activation réelle des blocs Phase 2 & 3 (jusque-là **faussement** documentés « FAITE »/« stagés » alors
qu'aucune ressource n'était sourcée). Les métiers ESX **existent bien** — dans le monorepo officiel
**`esx-framework/ESX-Legacy-Addons`** (le commentaire « les dépôts esx_* n'existent plus » était faux).

### Phase 2 — métier POLICE
- **`install_esx_addons`** (`scripts/install-resources.sh`) : clone le monorepo `ESX-Legacy-Addons`
  (pin = SHA de `main`, `a94ede6…`) et **aplatit sélectivement** les addons dans
  `data/resources/[esx_addons]/`. Set = **clôture des dépendances d'`esx_policejob`** : `esx_addonaccount`,
  `esx_datastore`, `esx_society`, `esx_billing`, `esx_vehicleshop`, `esx_policejob`.
  ⚠️ On **n'aplatit PAS** tout `[esx_addons]` (esx_banking/esx_shops/esx_jobs/… conflit avec `ubuntu-banque`).
- **`ensure`** (template) : `cron` (requis par `esx_society`) → addonaccount → datastore → society → billing
  → vehicleshop → policejob. `ubuntu-braquages`/`ubuntu-drogue` reçoivent enfin les **alertes police**
  (aucun code à changer : ils testaient déjà `xPlayer.job.name == 'police'`).
- **`esx_ambulancejob` DIFFÉRÉ** : dépend d'`esx_skin` (hard-dep + runtime `esx_skin:getPlayerSkin` pour
  le vestiaire EMS), retiré du projet au profit de `fivem-appearance`. À réintégrer quand la tenue EMS
  sera portée sur l'apparence. (Le vestiaire police a la même limite = uniforme no-op, non fatal.)

### Phase 3 — voix + téléphone + housing
- **`pma-voice`** `v7.0.0` (voix de proximité mumble natif, appels du téléphone).
- **`z-phone`** `v3.0.0` (`alfaben12/z-phone`) : téléphone **open-source ESX/ox**, deps `oxmysql`+`ox_lib`,
  **NUI pré-buildée** (aucun build node). **Remplace npwd** (pas de tag stable épinglable). Forcé en
  `Config.Core=ESX` par **`configure_zphone`** (dépôt en QBX par défaut) ; `z-phone.sql` auto-importé.
  **Accès** : touche **M** / `/phone`. z-phone **exige l'item `phone`** → **`append_phone_to_shop`**
  (idempotent, patron d'`append_ox_items`) ajoute `phone` à la boutique `General` (**supérettes 24/7**)
  d'ox_inventory à **10 000 $**. Sans achat, presser M affiche « You don't have a phone ».
- **`esx_property`** (housing, même monorepo `[esx_addons]`).

### Import SQL rendu idempotent (correctif au passage)
- `import_sql` **séparé en deux** : (a) schéma de base `legacy.sql` importé **une fois** (marqueur
  `data/.esx-sql-imported`) mais avec **`--force`** (un ré-import tolère les tables déjà présentes au lieu
  de `die` sur `CREATE TABLE` sans `IF NOT EXISTS`) ; (b) SQL des ressources (jobs/grades, `addon_account`,
  `datastore`, `z-phone`, …) **rejoué à chaque `make resources`** (non-fatal, idempotent). → **Ajouter un
  addon n'exige plus de supprimer le marqueur.**

### Activation / vérification
- `make resources` (MariaDB up) puis `make restart`. Vérifié : **boot headless 10/10 ressources `Started`,
  0 « Couldn't start »** ; DB OK (job `police` + 5 grades, comptes société, tables `zp_*`, `esx_property`
  → `datastore_data`). Pins confirmés via `git ls-remote`. Reste le test avec un client (achats/appels/housing).

## [2.1.2] — 2026-07-13 — Banque `ubuntu-banque` (dépôt / retrait / virement / ATM)

Nouvelle ressource maison **`ubuntu-banque`** — le serveur n'avait **aucune banque** (impossible de
déposer/retirer/virer). **100 % serveur-authoritative**, sur le patron de `ubuntu-location`.

- **Guichets** (PNJ + blip + E, aux emplacements « Banque ») : menu ox_lib **Solde / Déposer (cash→bank)
  / Retirer (bank→cash) / Virement** (bank→bank, par id de joueur connecté, frais configurables
  `Config.Transfer.feePercent`).
- **ATM** : ciblage **`ox_target`** sur les props distributeurs (`prop_atm_0*` / `prop_fleeca_atm`) —
  retrait / dépôt / solde (sans virement).
- **Sécurité** : montants saisis via `lib.inputDialog`, **revalidés côté serveur** (entier > 0, borné
  `Config.MaxAmount`), throttle anti-spam `Config.Cooldown`, opérations via l'API ESX
  (`add/removeAccountMoney`) → cash ox_inventory + banque synchronisés, **HUD à jour automatiquement**.
- **Journal** : table `ubuntu_bank_transactions` (`banque.sql`, importée par `import_custom_sql`).
- **Intégration** : `ensure ubuntu-banque` après `ubuntu-location` (dépend d'`ox_target`) ; les 2 blips
  « Banque » statiques ont été **retirés d'`ubuntu-interface`** (doublon avec les guichets interactifs).

## [2.1.1] — 2026-07-12 — Boutique : livraison des achats + solde du menu pause

Correctifs de deux régressions post-migration ESX.

### Affichage du solde (Cash + Banque)

- **Diagnostic** : le « solde à 0 » n'était **pas** un bug d'économie — l'argent vit bien dans
  `users.accounts` (vérifié en base : cash/banque réels, la banque augmente avec les paies). C'était
  **purement un défaut d'affichage** : la stack es_extended + **ox_inventory** n'a **aucun HUD**, le
  cash est un item ox_inventory (visible seulement dans l'inventaire) et la banque n'est affichée nulle
  part.
- **`ubuntu-interface`** — synchronise les comptes ESX `money`/`bank` (mis à jour en direct via
  `esx:setAccountMoney` — le bridge ox_inventory fire l'event même quand le cash change) vers les **stats
  natives du menu pause GTA** (`MP0_WALLET_BALANCE`/`BANK_BALANCE`, sinon figées à 0). Cache
  `cachedCash/cachedBank`, `pushMoneyStats()` + garde-fou périodique (5 s). Drapeau
  `Config.PauseMenu.syncMoney`. ⚠️ Index perso `MP0` du menu pause à confirmer en jeu.
- **Pas de HUD à l'écran** : un HUD NUI Cash + Banque avait été ajouté puis **retiré à la demande de
  l'utilisateur** (seul le sync du menu pause est conservé).

### Livraison des achats `ubuntu-premium`

- **Véhicules** : **spawn immédiat** à l'achat (`client:spawnVehicle`, devant le joueur, plaque unique)
  en plus de l'`INSERT owned_vehicles` (prêt pour un futur garage ESX). Auparavant inatteignables
  (aucun garage ne lisant la table).
- **Tenues** : le **skin complet** est stocké (`data.outfits`), commande **`/tenues`** (menu ox_lib)
  pour re-porter n'importe quelle tenue achetée, + **ré-application au (re)spawn** de la dernière tenue
  portée. Avant : appliquée une fois puis perdue.
- **Grade VIP** : le principal ace est **ré-appliqué à chaque connexion** (`esx:playerLoaded`, clé sur
  `data.aceGroup`) → VIP durable across reconnexions/redémarrages (avant : lié à l'id de session).
- **Perks** : nouveaux exports de lecture `GetPerks` / `GetRank` / `GetPremiumData` (seam pour un futur
  garage/garde-robe ; restent informatifs sans consommateur).
- Aucun changement SQL (méta stockée dans `ubuntu_premium_data.data`). i18n fr/en ajoutés.

## [2.1.0] — 2026-07-12 — Migration ESX (Phases 2 & 3)

Suite de la migration : **métiers ESX** + portage de l'**économie illégale**, et **câblage stagé**
du téléphone/housing.

### Phase 2 — Métiers + illégal (activé)

- **Métiers ESX** ajoutés au `RESOURCES` + `ensure` : `esx_addonaccount`, `esx_society` (comptes
  société), `esx_policejob`, `esx_ambulancejob` (leurs jobs viennent de leur SQL, importé par le scan
  générique). Mécano/trucker/taxi/garbage laissés **commentés** (dépôts ESX historiques, refs à confirmer).
- **`ubuntu-braquages`** (v2) porté ESX/ox : police en service via `ESX.GetExtendedPlayers` +
  `xPlayer.job` ; butin sur compte `money` ; items requis (`electronickit`/`thermite`) via
  **ox_inventory** ; **`lib.progressBar`** ; alertes `ox_lib:notify` + blips. Cibles **dé-thématisées**.
- **`ubuntu-drogue`** (v2) porté ESX/ox : ventes/achats via **ox_inventory** (`GetItem`/`RemoveItem`/
  `AddItem`), compte `money`, menu grossiste **`lib.registerContext`**, chaleur → alerte Police. Zones
  **dé-thématisées**.
- **Items ox_inventory** : nouvelle étape **`append_ox_items`** de `install-resources.sh` (idempotente,
  marqueur) **ajoute** `joint`/`xtcbaggy`/`crack_baggy`/`coke_baggy`/`electronickit`/`thermite` après le
  `return {` de `ox_inventory/data/items.lua` (sans remplacer le fichier, version-spécifique).

### Phase 3 — Téléphone + housing (stagé, DÉSACTIVÉ)

- **npwd** (téléphone, + pma-voice) et **housing** (loaf_housing / esx_property) câblés en **blocs
  commentés** dans `install-resources.sh` (section Phase 3) et `config/server.cfg.template` — à préparer
  et `ensure` **après validation en jeu** (mirroir de l'ancien « ps-housing stagé mais désactivé »).
- **HUD/météo** : défauts ESX/ox suffisants (polish optionnel, non requis).

### À confirmer en live

- **Refs ESX** (jobs/société/npwd/housing) posées **sans réseau** → valider au premier `make resources`
  (un `fetch` échoué nomme la ressource). Boot headless + test en jeu (prise de service Police/SAMU,
  braquage, deal, achat au grossiste).

---

## [2.0.0] — 2026-07-12 — Migration QBCore → ESX (Phase 1)

Bascule du serveur de **QBCore** vers **ESX Legacy + stack ox**, base propre, **sans l'habillage
Cameroun / Afrique** (concepts ESX par défaut, monnaie `$`, français conservé), **mono-personnage**.
Décisions utilisateur : base propre, stack ox, abandon FCFA, retrait des noms camerounais partout,
suppression du mobile money, comptes ESX par défaut uniquement, livraison **phasée**.

### Modifié / Ajouté (infra)

- **`scripts/install-resources.sh`** réécrit pour ESX : `install_esx_core` clone le **monorepo
  `esx_core`** (ESX Legacy) et **aplatit** ses dossiers catégorie dans `data/resources` ;
  `install_release_zip` (générique) installe **oxmysql / ox_lib / ox_inventory / ox_target /
  conservés (**PolyZone, interact-sound, rpemotes-reborn, LegacyFuel**). **Supprimé** :
  `normalize_currency()`, `recalibrate_vehicle_prices()`, le téléchargement `qbcore.sql`, la stack
  Housing. ⚠️ Pins ESX posés **sans réseau** → à confirmer au premier `make resources` (en-tête du script).
- **`sql/esx-base.sql`** (nouveau, versionné) : schéma ESX Legacy de base
  (`users`/`jobs`/`job_grades`/`user_licenses`/`owned_vehicles`), importé à la place de `qbcore.sql`.
- **`config/server.cfg.template`** : nouvel ordre `ensure` ESX ox (mono-perso), convars
  `setr esx:locale "fr"` / `ox:locale`, blocs Phase 2 commentés (métiers/société, braquages/drogue).
- **`overrides/`** : overrides `qb-*` supprimés. **Aucun override requis** en Phase 1 (défauts ESX ;
  `Config.Multichar` auto-désactivé sans multichar). `apply_overrides` durci (dossier vide géré).
- **`.env.example`** : description/tags/section dé-thématisés (ESX, plus de FCFA/MoMo/Cameroun).

### Ressources maison portées vers ESX / ox_lib

- **`ubuntu-premium`** (v2) : boutique de dons « **Points** » (ex-« Kubi »). Points en **table propre**
  `ubuntu_premium_data` (**pas de compte ESX**), crédit `/addpoints` + export **`AddPoints`**.
  Véhicules → `owned_vehicles` ; tenues cosmétiques **appliquées via natives GTA**. Catalogue
  dé-thématisé.
- **`ubuntu-admin`** (v2) : gaté par **groupe ESX** (`getGroup`), `ESX.GetExtendedPlayers`/`setJob`/
  comptes `money`/`bank`/`black_money` ; **table `bans` propre** + check `playerConnecting`. NUI mise à jour.
- **`ubuntu-interface`** (v2) : menu F1 via **`lib.registerContext`**, `isStaff` via groupe ESX,
  init sur `esx:playerLoaded`, blips **génériques**. Entrée « Mobile Money » retirée.
- **`ubuntu-location`** (v2) : compte `money`, menu **`lib.registerContext`**, points **génériques**.
- **`ubuntu-antichute`** : écoute `esx:playerLoaded`/`playerSpawned` + **ferme le loadscreen**
  (mono-perso).
- **`ubuntu-loadscreen`** : dé-thématisé (accent indigo, sans drapeau/FCFA/MoMo, astuces génériques).
- **i18n** : chaque ressource embarque un **shim `locales/locale.lua`** (remplace
  `@qb-core/shared/locale.lua`) reproduisant `Lang:t(..)` — framework-agnostique.

### Supprimé

- **`ubuntu-mobilemoney`** (mobile money `momo`, spécifique Afrique) + les comptes custom `momo`/`kubi`.

### Restant (non livré)

- **Phase 2** : métiers ESX (police/ambulance/mécano/trucker/taxi/garbage) + portage de
  **`ubuntu-braquages`** / **`ubuntu-drogue`** (encore QBCore, **non chargés** dans le template).
- **Phase 3** : téléphone (npwd), housing (loaf/esx_property), HUD/météo.
- **Vérification live requise** : `make resources` (confirmer les pins ESX) + boot headless + test en jeu.

---

## [1.8.3] — 2026-07-11 — Logo officiel du serveur (icône + loadscreen)

### Ajouté

- **Logo officiel Ubuntu RP** (bouclier V esport, thème GTA/Douala, doré/orange) installé aux deux
  emplacements « logo serveur » de FiveM, depuis une source carrée 1254×1254 (resize PIL) :
  - **Icône serveur** — `config/server-icon.png` (PNG **96×96**), activée par
    `load_server_icon "/opt/fivem/config/server-icon.png"` dans
    [`config/server.cfg.template`](config/server.cfg.template) (chemin absolu = fiable sous txAdmin ;
    `config/` est monté `./config:/opt/fivem/config`). Visible dans le navigateur FiveM / txAdmin.
  - **Logo du loadscreen** — `resources/[custom]/ubuntu-loadscreen/html/assets/logo.png` (512×512),
    déclaré dans le `fxmanifest.lua` ; l'`<img>` **masque le logo texte** au chargement via son
    `onload` (fallback `onerror` sur le texte si le fichier est retiré). Sous-titre « Douala • Afrique
    centrale » conservé.

---

## [1.8.2] — 2026-07-11 — Devise FCFA partout (fin du symbole « $ »)

### Corrigé

- **Symbole « $ » remplacé par FCFA dans toutes les ressources** (HUD, banque, téléphone/crypto,
  concession, garages, coffres société, compteur taxi, station-service, salaires, notifications…).
  Étape **`normalize_currency()`** de [`scripts/install-resources.sh`](scripts/install-resources.sh)
  (rejouée à chaque `make resources`, idempotente), en deux couches :
  - **(a) globale** sur tous les `.lua` : motifs interpolés sans ambiguïté `$%{x}` / `$%s` / `$%d`
    → suffixe ` FCFA` ; et sur les **fichiers de langue** uniquement (toutes langues) : montants
    codés en dur `$500` → `500 FCFA`, `($)` → `(FCFA)`, libellés `Solde: $` / `"$"` → FCFA.
  - **(b) ciblée** par fichier (aucun risque sur un `$` non monétaire — motif Lua, `$(` jQuery,
    `${}` template, liste de caractères, table de largeurs NativeUI) : `qb-hud` (HUD), `qb-banking`
    (Vue), **`qb-inventory`** (prix des supérettes/magasins — l'UI d'inventaire-boutique affiche le
    prix), `qb-garages`, `qb-taxijob` (`meter.html`/`meter.js`), `LegacyFuel`, et **`qb-phone`**
    (entité HTML `&#36;`, `"$"`, valeurs de démo, notifications — banque + crypto).
  - Appliqué **aussi aux clones déjà installés** pour effet immédiat. Le formateur de
    `qb-multicharacter` (fr-FR) et son suffixe ` FCFA` (v1.7.2) restent en place.

---

## [1.8.1] — 2026-07-11 — Correctif : chute à travers la map au spawn

### Corrigé

- **Spawn : le personnage traversait la map (chute dans les égouts) et se réveillait à l'hôpital.**
  Au chargement, `qb-spawn`/`qb-multicharacter` plaçaient le joueur (`SetEntityCoords`) puis le
  dégelaient **avant** que la collision de la map ne soit chargée autour de lui → le ped tombait à
  travers le sol, encaissait d'énormes dégâts de chute, et `qb-ambulancejob` le passait en
  « blessé/mort » (alerte « appelez les secours » + réveil sur un lit d'hôpital). Nouvelle ressource
  maison **`ubuntu-antichute`** ([`resources/[custom]/ubuntu-antichute`](resources/), client-only) :
  sur `QBCore:Client:OnPlayerLoaded`, elle **re-gèle le ped** et force `RequestCollisionAtCoord` en
  boucle jusqu'à `HasCollisionLoadedAroundEntity` (garde-fou 15 s) avant de le relâcher — couvre
  nouveau perso, reconnexion et réanimation SAMU. `ensure` après `qb-spawn`. Aucun fichier upstream
  modifié (survit à un re-pin), **0 SQL**.

---

## [1.8.0] — 2026-07-11 — Contenu plébiscité : emotes, braquages & drogue de rue (+ housing stagé)

Après un vote, ajout des **4 grands classiques RP** appréciés des joueurs et présents sur la plupart
des serveurs, mais absents ici : un **menu d'emotes**, des **braquages**, une **économie illégale
(drogue de rue)** et la **stack Housing** (`ps-housing`, installée mais désactivée en attente de
validation en jeu). Les 3 premières sont des features **serveur-authoritative**, thématisées Douala,
locales fr/en.

### Ajouté

- **`rpemotes-reborn`** (standalone, pin `834505f8`) — menu d'emotes/animations le plus populaire de
  FiveM (support QBCore) : `/e`, danses, gestes, **mains en l'air**, walkstyles. Gratuit, **0 SQL**.
  Touche « Emote Menu » rebindable dans *Paramètres > Touches*. `ensure` après `interact-sound`.
- **`ubuntu-braquages`** ([`resources/[custom]/ubuntu-braquages`](resources/)) — braquages
  **100 % serveur-authoritative**, butin **FCFA**, **alerte Police** (blip clignotant + notif aux
  policiers en service) et cooldowns. Cibles data-driven thématisées : **supérettes** (DOVV Akwa,
  Mahima Ndokoti, Santa Lucia Bonabéri — à main armée), **distributeurs** (Tradex, Bépanda — kit
  électronique) et **banques** (Atlantique, Afriland — thermite, présence policière renforcée). Seuil
  `minPolice`, items **déjà présents dans qb-core** (aucun nouvel item), anti-triche serveur (distance,
  durée mini). Locales fr/en. `ensure` après `qb-policejob`.
- **`ubuntu-drogue`** ([`resources/[custom]/ubuntu-drogue`](resources/)) — vente de **drogue de rue**
  aux PNJ dans les **quartiers chauds** (Ndokoti, Bépanda, Bonabéri, abords du Marché Mokolo), **prix
  dynamiques** (zone/heat), **chaleur** cumulée → **alerte Police** au seuil + « lay low », **grossiste**
  (PNJ + blip discret + menu qb-menu) pour l'approvisionnement. Produits = **baggies qb-core existants**
  (aucun nouvel item). Logique **serveur-authoritative** (possession, prix, chaleur, cooldown validés
  serveur), locales fr/en. `ensure` après `qb-policejob`, avant `ubuntu-location`.
- **Stack Housing (`ps-housing`) — installée mais DÉSACTIVÉE.** Pins ajoutés (`ox_lib` v3.38.0 en
  release buildée, `fivem-freecam` fork Deltanic `9b3797d7`, `ps-realtor` `99b92d64`, `ps-housing`
  tag `2.0.7`) + **import SQL dédié** de `properties.sql` (variante QBCore). Le bloc `ensure` reste
  **commenté** dans le template : `ps-housing` est **archivé** (fév. 2026), streame des shells MLO et
  introduit `ox_lib` → à **valider en jeu** avant activation (décommenter 4 lignes).

### Modifié

- [`scripts/install-resources.sh`](scripts/install-resources.sh) — pin `rpemotes-reborn` ; fonction
  `install_ox_lib` (release buildée, calquée sur `install_oxmysql`) ; pins `fivem-freecam`/`ps-realtor`/
  `ps-housing` ; étape `import_housing_sql` (SQL niché, idempotent via marqueur).
- [`config/server.cfg.template`](config/server.cfg.template) — `ensure rpemotes-reborn`,
  `ensure ubuntu-braquages`, `ensure ubuntu-drogue` ; bloc Housing **commenté** après `qb-apartments`.
- [`wiki/`](wiki/) — `economie` (braquages & drogue = revenus/risques) et `commandes` (emotes `/e`).

---

## [1.7.2] — 2026-07-11 — Correctif : écran noir à la création de personnage

### Corrigé

- **`qb-multicharacter` — écran noir à la création/sélection de perso.** Son UI est une app **Vuetify**
  qui chargeait `vuetify.js` / `vuetify.min.css` et `axios` depuis des **CDN externes**
  ([html/index.html](data/resources/[core]/qb-multicharacter/html/index.html)) ; quand le client ne peut
  pas les atteindre, le conteneur `<v-app>` reste vide → **écran noir** (souris prise mais rien à
  l'écran). Les libs sont désormais **rapatriées en local** via un override
  ([`overrides/qb-multicharacter/html/vendor/`](overrides/) + `index.html`/`fxmanifest.lua` patchés) — plus
  aucune dépendance CDN pour le rendu. `vue.js` était déjà local ; la police Material Symbols (icônes)
  reste en CDN (cosmétique). Appliqué par `make resources` (idempotent) et copié sur le clone existant.
- **`qb-multicharacter` — solde affiché en dollars ($) sur les cartes de perso.** Corrigé dans le même
  override : `html/app.js` passe le formateur de `Intl.NumberFormat("en-US")` à `"fr-FR"` (séparateur
  d'espace, montants entiers) et `html/index.html` remplace le préfixe `$` par le suffixe ` FCFA`.

---

## [1.7.1] — 2026-07-11 — Correctif : loadscreen personnalisé qui ne s'affichait pas

### Corrigé

- [`config/server.cfg.template`](config/server.cfg.template) — ajout de `loadscreen_manual_shutdown 'yes'`
  avant `ensure ubuntu-loadscreen`. Sans cette directive, FiveM fermait l'écran de chargement dès que la
  session était prête (le loadscreen custom n'apparaissait qu'une fraction de seconde, d'où « ne s'affiche
  pas »). Il reste désormais affiché pendant tout le chargement et n'est fermé que par `qb-multicharacter`
  (`ShutdownLoadingScreenNui()`, déjà appelé à la sélection de personnage). Rappel : le loadscreen est mis
  en cache côté client → **redémarrer complètement FiveM** (pas un simple reconnect) pour le voir changer.

---

## [1.7.0] — 2026-07-11 — Métiers, location de véhicules & boutique premium enrichie

Contenu RP joueur : quatre **métiers** officiels (gameplay), une ressource maison de **location de
véhicules** (bateau/scooter/vélo) et l'enrichissement de la **boutique premium** (véhicules custom
en Kubi + vêtements spéciaux).

### Ajouté

- **Métiers (boulots)** — 4 ressources officielles épinglées dans le tableau `RESOURCES` et
  `ensure` dans le template (les métiers étaient déjà **déclarés** dans
  [`overrides/qb-core/shared/jobs.lua`](overrides/qb-core/shared/jobs.lua) ; ces ressources
  apportent le gameplay + les blips) :
  - **`qb-policejob`** (pin `4abcce96`) — Police Nationale : MDT, interpellations, fouille,
    preuves, poste de police (blip).
  - **`qb-ambulancejob`** (pin `9d01cc93`) — SAMU : système de mort/réanimation, hôpital (blip),
    soins.
  - **`qb-mechanicjob`** (pin `1d014e1b`) — Mécanicien : réparation/customisation véhicule, garage.
  - **`qb-truckerjob`** (pin `2d27b30b`) — Camionneur : livraisons rémunérées (FCFA).

  Aucune dépendance nouvelle (qb-core / PolyZone / oxmysql déjà présents), aucun SQL propre.
- **`ubuntu-location`** ([`resources/[custom]/ubuntu-location`](resources/)) — location de véhicules
  **100 % serveur-authoritative**, tarifs **FCFA**, **caution remboursée à la restitution**. Points
  thématisés Douala : **Port de Douala** (pirogue motorisée, jet-ski, vedette), **Akwa** (scooters),
  **Bonanjo** (vélos/VTT). PNJ + blip + marqueur de proximité (`E`) ; menu **qb-menu** ; le serveur
  débite frais + caution puis pilote l'apparition du véhicule (clés via `qb-vehiclekeys`) et
  rembourse la caution au retour. Locales fr/en. `ensure` après `ubuntu-mobilemoney`.
- **Boutique premium enrichie** ([`resources/[custom]/ubuntu-premium/config.lua`](resources/)) —
  nouveaux articles Kubi (le catalogue reste la **source de vérité serveur**, insertion véhicule à
  **mods neutres** = non pay-to-win) : **véhicules custom** (SUV, sportive, moto de collection ;
  swap possible vers un modèle add-on streamé) et **vêtements spéciaux** (Maillot Lions Indomptables,
  Boubou traditionnel, Tenue Drapeau). La boutique reste **visitable** par PNJ + blip + `/boutique`.

### Modifié

- [`scripts/install-resources.sh`](scripts/install-resources.sh) — 4 entrées `[jobs]` épinglées
  ajoutées au tableau `RESOURCES`.
- [`config/server.cfg.template`](config/server.cfg.template) — `ensure` des 4 métiers (après
  `qb-garbagejob`) et de `ubuntu-location` (après `ubuntu-mobilemoney`).
- [`wiki/`](wiki/) — `metiers` (nouveaux boulots) et `commandes`/`economie` (location de véhicules).

---

## [1.6.0] — 2026-07-11 — Interface joueur : menu F1, menu pause & carte des points

Nouvelle ressource maison **`ubuntu-interface`** regroupant les commandes d'interface joueur
demandées : un **menu principal sur F1**, l'**habillage du menu pause** aux couleurs du serveur, et
la **carte des points d'intérêt** (blips).

### Ajouté

- **`ubuntu-interface`** ([`resources/[custom]/ubuntu-interface`](resources/)) — dépend de `qb-core`
  + `qb-menu`, `ensure` après `ubuntu-admin` dans le template. **Data-driven** via `config.lua` :
  - **Menu principal (F1)** — commande `menuprincipal` mappée par défaut sur **F1**
    (`RegisterKeyMapping`, rebindable), construite avec **qb-menu** : raccourcis Boutique premium,
    Mobile Money, Téléphone, sous-menu **« Se repérer »** (pose un GPS vers un lieu), Aide & commandes,
    et **Panel Admin** (visible seulement si staff — callback serveur `isStaff`, permission ace).
  - **Menu pause (Échap)** — `AddTextEntry('FE_THDR_GTAO', …)` remplace le libellé de l'onglet du
    menu pause par **« UBUNTU RP »**.
  - **Carte** — `Config.Blips` : liste curatée des points d'intérêt (Police, SAMU, Mairie, HYSACAM,
    banques, CFAO Motors, garage, bendskin, supermarchés DOVV/Mahima/Santa Lucia, Marché Mokolo,
    stations Tradex). Créés au chargement, retirés au `onResourceStop`. Ajouter un point = 1 entrée.
  - Locales **fr/en** ; textes RP en français.

### Modifié

- [`config/server.cfg.template`](config/server.cfg.template) — `ensure ubuntu-interface` après
  `ubuntu-admin`.

---

## [1.5.0] — 2026-07-11 — Téléphone, carte (minimap) & touches joueur

Ajout des ressources joueur manquantes : un **téléphone** et un **HUD/minimap** QBCore, ce qui
rend disponibles les **touches utilisateur** (téléphone / carte) dans *Paramètres > Touches* de
FiveM et affiche la minimap en permanence — donc les **blips des services** deviennent visibles.

### Ajouté

- **`qb-hud`** (pin `2bc4ec3c`, 2026-05-20) — HUD de statut + **minimap QBCore permanente**
  (`DisplayRadar(true)`) et commande `menu` (réglages HUD : afficher/masquer la carte). Rend
  visibles les blips déjà créés par les services (banque, magasins, concession, garages, taxi,
  éboueur, station-service, MoMo, boutique premium). Dépend de `qb-core`.
- **`qb-phone`** (pin `6056046b`, 2026-05-20) — téléphone joueur (messages, banque, annuaire…)
  avec **touche `Open Phone`** enregistrée via `RegisterKeyMapping('phone', …)` (rebindable dans
  *Paramètres > Touches*). Dépend de `qb-core`, `qb-apartments`, `oxmysql` (déjà installés) ; les
  tables `phone_*` / `player_contacts` sont déjà fournies par le `qbcore.sql` importé (aucun SQL
  supplémentaire). Locale FR active via `setr qb_locale "fr"`.

### Modifié

- [`scripts/install-resources.sh`](scripts/install-resources.sh) — deux entrées épinglées ajoutées
  au tableau `RESOURCES` (`qb-hud`, `qb-phone`, catégorie `[core]`).
- [`config/server.cfg.template`](config/server.cfg.template) — `ensure qb-hud` juste après
  `qb-core` ; `ensure qb-phone` après `qb-banking` (donc après sa dépendance `qb-apartments`),
  avant `ubuntu-mobilemoney`.

---

## [1.4.0] — 2026-07-10 — Écran de chargement & identité serveur

Habillage du serveur aux couleurs du RP camerounais / Afrique centrale : un écran de chargement
thématisé (fond, logo, barre de progression, astuces RP, musique d'attente) et une identité de
serveur affinée dans le navigateur FiveM.

### Ajouté

- **Ressource `ubuntu-loadscreen`** — [`resources/[custom]/ubuntu-loadscreen`](resources/) :
  écran de chargement **NUI** (`loadscreen`) thématisé Cameroun (accents drapeau vert/rouge/jaune,
  logo « UBUNTU RP », sous-titre « Douala • Afrique centrale »). **Barre de progression** pilotée par
  les events loadscreen FiveM (`loadProgress`/`initFunctionInvoking`…), **astuces RP** rotatives en
  français (`/momo`, bendskin, maquis, DOVV/Tradex, `/boutique`…), **image de fond** (`assets/background.jpg`)
  avec voile sombre, et **musique d'attente** en boucle (`assets/music.mp3`) avec bouton mute mémorisé
  (`localStorage`) et dégradation silencieuse si le fichier manque. Emplacement `logo.png` optionnel
  (logo texte par défaut) documenté dans [`assets/README.md`](resources/).
- **Icône serveur** — directive `load_server_icon` (commentée) dans
  [`config/server.cfg.template`](config/server.cfg.template) : déposer un PNG 96×96 dans
  `config/server-icon.png` puis décommenter.

### Modifié

- [`config/server.cfg.template`](config/server.cfg.template) — `ensure ubuntu-loadscreen` en tête du
  bloc ressources (affichage au plus tôt) + bloc `load_server_icon` documenté.
- [`.env`](.env) / [`.env.example`](.env.example) — `SERVER_DESCRIPTION` (« Roleplay camerounais •
  Douala • FCFA, MoMo, bendskin, maquis • Afrique centrale ») et `SV_TAGS`
  (`… afrique, cameroun, qbcore`) affinés.

---

## [1.3.0] — 2026-07-10 — Boutique premium (Kubi) & panel de gestion des joueurs

Deux briques de la roadmap [`vision_global.md`](vision_global.md) / du guide FiveM : **Phase 14 —
Monétisation** (boutique premium non pay-to-win) et **Phase 12 — Administration** (UI de gestion des
joueurs). Deux nouvelles ressources maison dans [`resources/[custom]`](resources/), logique
**serveur-authoritative**, NUI au **design épuré style Apple** (accent `#b71540`), locales fr/en.

### Ajouté

- **Monnaie premium « Kubi »** — nouveau type d'argent qb-core `kubi` (points de dons, hors économie
  RP, non pay-to-win) dans [`overrides/qb-core/config.lua`](overrides/qb-core/config.lua). Créditée par
  un admin (`/addkubi <id> <montant>`, ace-gated) ou l'export `ubuntu-premium:AddKubi`.
- **Ressource `ubuntu-premium`** (boutique premium) — [`resources/[custom]/ubuntu-premium`](resources/) :
  storefront **NUI** (`/boutique` ou PNJ « Boutique Premium » + blip). Catalogue **serveur-authoritative**
  (le client n'envoie que l'`id`, coûts/possession validés serveur, achats `oneTime` idempotents) :
  **3 starter packs** (Urban / Corporate / Young = transport + tenue), **cosmétiques** (tenues via la
  garde-robe `player_outfits`), **véhicules cosmétiques** (insert `player_vehicles`, sans performance),
  **grade donateur VIP/VIP+**, **confort** (slots perso/garage en métadonnée). Journal d'audit
  `ubuntu_premium_purchases`.
- **Ressource `ubuntu-admin`** (gestion des joueurs) — [`resources/[custom]/ubuntu-admin`](resources/) :
  panel **NUI** (`/admin`, défaut **F6**) **gated par permissions ace** (`god`/`admin`/`mod`), chaque
  action **revérifiée côté serveur**. Liste des joueurs en ligne (identité, métier, argent, ping) + actions :
  **kick, ban** (table `bans`, rejet géré par qb-core à la reconnexion), **argent** (cash/bank/momo/kubi),
  **job & grade**, **téléportation** (aller/amener), **observation**, **réanimer/soigner/geler**,
  **créditer des Kubi**, **annonce globale**. **Logs Discord** de chaque action (webhook `discord_webhook`).

### Modifié

- [`config/server.cfg.template`](config/server.cfg.template) — `ensure ubuntu-premium` puis
  `ensure ubuntu-admin` (ordre : premium avant admin pour l'export `AddKubi`).
- [`scripts/install-resources.sh`](scripts/install-resources.sh) — importe désormais aussi le SQL des
  ressources `resources/[custom]/**/*.sql` (idempotent, `CREATE TABLE IF NOT EXISTS`).
- [`wiki/`](wiki/) — `commandes` (`/boutique`) et `economie` (section **Kubi** / boutique premium /
  non pay-to-win).

---

## [1.2.0] — 2026-07-10 — Couche RP QBCore (thème Cameroun / Afrique centrale)

Ajout d'un serveur RP **jouable** par-dessus l'infrastructure Docker (phases 1 & 2 de la roadmap
[`vision_global.md`](vision_global.md) §10) : framework, identité/personnage, inventaire, argent,
métiers civils, véhicules et logement — thématisé société camerounaise / Afrique centrale, avec de
vraies enseignes de référence (DOVV, HYSACAM, CFAO Motors, Tradex, MoMo…).

### Ajouté

- **Installateur de ressources** — [`scripts/install-resources.sh`](scripts/install-resources.sh)
  (cible `make resources`), **idempotent** : clone ~24 ressources QBCore officielles à des
  **révisions épinglées (SHA/tag)** dans `data/resources/`, applique les overrides, recalibre les
  prix véhicules en FCFA, importe le schéma SQL dans MariaDB.
- **Framework QBCore** — qb-core + inventaire, banque, commerces, concessionnaire, garages, clés de
  véhicule, carburant (LegacyFuel), multi-personnages, logement (apartments), vêtements, météo,
  primitives UI (menu/input/target), gestion d'entreprise, etc.
- **Ressource maison `ubuntu-mobilemoney`** — [`resources/[custom]/ubuntu-mobilemoney`](resources/) :
  portefeuille **mobile money MoMo** (à la manière de MTN MoMo / Orange Money, monnaie `momo`),
  commande **`/momo`** (solde, transfert entre joueurs avec **frais de 1 %**, dépôt/retrait de liquide
  aux **points MoMo** avec blips sur la carte). Logique **entièrement côté serveur**, locales fr/en.
- **Overrides thématiques** — [`overrides/`](overrides/) (copiés par-dessus les clones) :
  - **Franc CFA** partout, montants entiers ; argent de départ 25 000 cash / 75 000 banque /
    10 000 momo ; prix véhicules recalibrés (×300, arrondi 5 000 FCFA).
  - **Métiers camerounais** : Police Nationale, SAMU, **Moto-taxi (Bendskin)**, **HYSACAM**
    (propreté), **CFAO Motors** (concession), **SOCATUR**/**CRTV**/**CDC**/**CAMRAIL**, garages de
    quartier (Bonabéri, Ndokoti, Bépanda…)… (grades & salaires en FCFA).
  - **Commerces (enseignes réelles)** : supermarchés **DOVV / Mahima / Santa Lucia / Casino**,
    stations **Tradex / Total / Neptune Oil / Bocom**, **maquis & tournedos**, **Marché Mokolo**,
    **Boulangerie Saker**, **Quincaillerie Quifeurou**, prix FCFA.
- **Textes en français** — `setr qb_locale "fr"` active la locale FR des ressources qb-*.
- **Wiki joueur** — [`wiki/`](wiki/) : site statique multi-pages (accueil, bien démarrer, règlement,
  économie & mobile money, métiers, commandes, FAQ) au thème savane, responsive, sans build.
- **Manuel de déploiement** — [`DEPLOIEMENT.md`](DEPLOIEMENT.md) : guide opérateur/admin pas à pas
  (prérequis, clés, installation, `.env`, couche RP, txAdmin, sécurité/UFW, dépannage).
- **`CLAUDE.md`** (guidage projet) et **`CHANGELOG.md`** (ce fichier).

### Modifié

- [`config/server.cfg.template`](config/server.cfg.template) — bloc `ensure` **ordonné** des
  ressources RP, convars (`qb_locale`, `locale`, `UseTarget`, `discord_webhook`), `add_ace` qb-core.
- [`.env.example`](.env.example) — nouvelle variable `DISCORD_WEBHOOK`.
- [`docker-compose.yml`](docker-compose.yml) — bind imbriqué `./resources:/opt/fivem/resources/[ubuntu]`
  pour monter les ressources maison versionnées.
- [`Makefile`](Makefile) — cible `resources` ; `make install` rappelle de lancer `make resources`.
- [`README.md`](README.md) — section « Couche RP (QBCore) » + roadmap mise à jour.

### Corrigé

- **Build de l'image** — l'image ne se construisait plus : `ubuntu:24.04` fournit déjà un utilisateur
  en uid 1000. Ajout de `userdel -r ubuntu` dans [`docker/fivem/Dockerfile`](docker/fivem/Dockerfile).
- **Démarrage headless** — en mode `TXADMIN_ENABLE=false`, FXServer était lancé depuis le dossier des
  artifacts et ne trouvait pas `resources/`. Le cwd est désormais `/opt/fivem`
  ([`entrypoint.sh`](docker/fivem/entrypoint.sh)).
- **Dépendances QBCore** — ajout de `qb-interior` (requis par qb-apartments) et `qb-weapons` (requis
  par qb-inventory), sans quoi ces ressources refusaient de démarrer.
- **Import SQL** — les scripts de migration (`migrate.sql`) et les `.sql` déjà couverts par le schéma
  agrégé sont désormais ignorés proprement (imports non-fatals) au lieu de faire échouer l'installation.

---

## [1.1.0] — Reverse proxy, monitoring & CI/CD (V2)

Services d'exploitation avancés, activables à la demande via des **profils Compose** (le démarrage
par défaut ne lance que la V1).

### Ajouté

- **Reverse proxy Nginx** (profil `proxy`) — point d'entrée HTTP unique, vhosts par nom d'hôte
  (défaut → txAdmin, `grafana.local` → Grafana, `adminer.local` → Adminer), bloc TLS en commentaire.
  Le trafic jeu (30120) reste direct.
- **Monitoring** (profil `monitoring`) — Prometheus + node-exporter + cAdvisor (métriques),
  Loki + Promtail (logs), **Grafana** avec sources de données et dashboard « Conteneurs »
  auto-provisionnés.
- **CI/CD** — [`.github/workflows/ci.yml`](.github/workflows/ci.yml) : lint (shellcheck, hadolint,
  `compose config`) → build & push de l'image vers **GHCR** → déploiement SSH optionnel.
- **Optimisation de l'image** — `.dockerignore`, `--no-install-recommends`, artifacts téléchargés au
  runtime (image de base légère).
- Cibles `make up-all`, `make proxy`, `make monitoring`.

---

## [1.0.0] — Plateforme Docker FiveM (V1)

Socle : déploiement d'un serveur FiveM reproductible, configurable exclusivement par `.env`.

### Ajouté

- **Orchestration Docker Compose** — services `fivem` (build local), `mariadb:11`, `redis:7`,
  `adminer`, réseau dédié `fivem-net`, healthchecks et politiques de redémarrage.
- **Conteneur FiveM** — [`docker/fivem`](docker/fivem/) : téléchargement automatique des artifacts
  FXServer (canal `recommended`/`latest` ou build épinglé), vérification d'intégrité, extraction en
  cache persistant, support **txAdmin** et mode **headless**.
- **Génération de `server.cfg`** — via `envsubst` depuis [`config/server.cfg.template`](config/server.cfg.template),
  nettoyage des directives optionnelles vides.
- **Configuration par `.env`** — [`.env.example`](.env.example) : identité serveur, licence, ports,
  txAdmin, MariaDB, Redis, OneSync, build GTA, fuseau horaire.
- **Persistance** — tout l'état sous `data/` (bind mounts) : resources, txData, database, cache, logs,
  artifacts, backups. Reconstruction sans perte.
- **Sauvegarde & restauration** — [`scripts/backup.sh`](scripts/backup.sh) / [`scripts/restore.sh`](scripts/restore.sh)
  (dump MariaDB + fichiers, compression, rotation `BACKUP_RETENTION`).
- **Makefile & documentation** — cibles `install/up/down/restart/logs/shell/update/backup/restore/
  health/ps`, README.

---

[1.3.0]: #130--2026-07-10--boutique-premium-kubi--panel-de-gestion-des-joueurs
[1.2.0]: #120--2026-07-10--couche-rp-qbcore-thème-cameroun--afrique-centrale
[1.1.0]: #110--reverse-proxy-monitoring--cicd-v2
[1.0.0]: #100--plateforme-docker-fivem-v1
