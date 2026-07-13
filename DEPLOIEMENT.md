# Manuel de configuration & de déploiement — Ubuntu RP (FiveM ESX)

Guide complet pour installer, configurer, déployer et exploiter le serveur **Ubuntu RP** :
plateforme Docker FiveM (txAdmin, MariaDB, Redis, Adminer) + couche RP **ESX Legacy** (stack ox),
concepts ESX par défaut, monnaie `$`, textes en français, **mono-personnage**.

> Ce manuel est opérationnel (pas à pas). Pour la vision produit voir [`vision_global.md`](vision_global.md),
> pour la spécification technique [`Specification_Technique_FiveM_Docker.md`](Specification_Technique_FiveM_Docker.md),
> et pour un aperçu rapide le [`README.md`](README.md).

---

## Sommaire

1. [Architecture & composants](#1-architecture--composants)
2. [Prérequis matériels & logiciels](#2-prérequis-matériels--logiciels)
3. [Obtenir les clés nécessaires](#3-obtenir-les-clés-nécessaires)
4. [Installation pas à pas](#4-installation-pas-à-pas)
5. [Configuration du fichier `.env`](#5-configuration-du-fichier-env)
6. [La couche RP ESX](#6-la-couche-rp-esx)
7. [Modes de démarrage : txAdmin vs headless](#7-modes-de-démarrage--txadmin-vs-headless)
8. [Première configuration txAdmin](#8-première-configuration-txadmin)
9. [Devenir administrateur en jeu](#9-devenir-administrateur-en-jeu)
10. [Exploitation quotidienne](#10-exploitation-quotidienne)
11. [Sauvegarde & restauration](#11-sauvegarde--restauration)
12. [Mises à jour](#12-mises-à-jour)
13. [Reverse proxy & monitoring (V2)](#13-reverse-proxy--monitoring-v2)
14. [Sécurité & pare-feu](#14-sécurité--pare-feu)
15. [Dépannage](#15-dépannage)
16. [Annexes](#16-annexes)

---

## 1. Architecture & composants

Tous les services tournent en conteneurs Docker sur un réseau dédié `fivem-net`.

| Service | Image | Rôle | Port hôte |
|---------|-------|------|-----------|
| `fivem` | build local ([`docker/fivem`](docker/fivem/)) | Serveur FiveM + txAdmin | `30120` TCP/UDP (jeu), `40120` TCP (txAdmin) |
| `mariadb` | `mariadb:11` | Base de données | interne |
| `redis` | `redis:7-alpine` | Cache | interne |
| `adminer` | `adminer` | Administration SQL web | `8080` |
| `nginx` *(profil `proxy`)* | `nginx:1.27-alpine` | Reverse proxy | `80` / `443` |
| `prometheus` / `grafana` / `loki` / `promtail` / exporters *(profil `monitoring`)* | — | Supervision | Grafana `3000` |

Le conteneur `fivem` **télécharge automatiquement** les artifacts FXServer, **génère**
`config/server.cfg` depuis un template, puis démarre — aucune manipulation interne.

**Flux de démarrage du conteneur** ([`entrypoint.sh`](docker/fivem/entrypoint.sh)) :
1. résout le build FiveM (canal `recommended`/`latest` ou URL épinglée) ;
2. télécharge, vérifie (`xz -t`) et extrait l'artifact dans un cache persistant ;
3. génère `server.cfg` via `envsubst` depuis [`config/server.cfg.template`](config/server.cfg.template) ;
4. démarre txAdmin (défaut) **ou** le serveur headless.

---

## 2. Prérequis matériels & logiciels

### Matériel (hôte)

| Usage | CPU | RAM | Disque | Réseau |
|-------|-----|-----|--------|--------|
| Test / petite communauté | 4 cœurs | 8 Go | 60 Go SSD | 500 Mbps |
| Production (~64 joueurs) | 8 cœurs | 16 Go | 100 Go SSD | 1 Gbps |
| Production (128 joueurs) | 16 cœurs | 32 Go | NVMe | 1 Gbps |

> FiveM est très sensible à la **fréquence mono-cœur** : privilégiez des CPU à haute fréquence.

### Logiciels

- **Hôte Linux** recommandé (**Ubuntu Server 24.04 LTS**) — les artifacts FXServer sont Linux.
- **Docker Engine 24+** et **Docker Compose v2** (`docker compose`).
- `make`, `git`, `curl`, `unzip` (utilisés par le script d'installation des ressources).
- **Sous Windows** (poste de dev) : Docker Desktop + WSL2, et lancer les scripts `bash` via Git Bash.

Vérification rapide :

```bash
docker --version && docker compose version && git --version && make --version
```

---

## 3. Obtenir les clés nécessaires

| Clé | Où l'obtenir | Obligatoire ? | Variable `.env` |
|-----|--------------|---------------|-----------------|
| **Licence FiveM (Cfx.re)** | <https://keymaster.fivem.net> | **Oui** — sinon le serveur refuse de démarrer | `LICENSE_KEY` |
| **Steam Web API Key** | <https://steamcommunity.com/dev/apikey> | Non (identifiants Steam des joueurs) | `STEAM_WEBAPI_KEY` |
| **Webhook Discord** | Serveur Discord → Paramètres du salon → Intégrations → Webhooks | Non (logs/notifications) | `DISCORD_WEBHOOK` |

> **Ne committez jamais ces valeurs.** Le fichier `.env` est déjà exclu par [`.gitignore`](.gitignore).

---

## 4. Installation pas à pas

```bash
# 1. Récupérer le projet
git clone <votre-dépôt> ubuntu-rp && cd ubuntu-rp

# 2. Préparer l'arborescence data/ et le fichier .env
make install
#   -> crée data/{resources,txData,database,cache,logs,artifacts,backups,...}
#   -> copie .env.example en .env

# 3. Éditer .env : au MINIMUM la LICENSE_KEY et les mots de passe
nano .env

# 4. Démarrer l'infrastructure (build de l'image + conteneurs)
make up

# 5. Installer la couche RP ESX (clones épinglés + overrides + schéma SQL)
make resources

# 6. Redémarrer le serveur pour charger les ressources
make restart

# 7. Suivre le démarrage
make logs
```

À l'issue :
- **txAdmin** : <http://IP_SERVEUR:40120>
- **Adminer** (SQL) : <http://IP_SERVEUR:8080> (serveur `mariadb`)
- **Connexion jeu** : dans FiveM, `connect IP_SERVEUR:30120`

> L'ordre importe : `make resources` a besoin que **MariaDB tourne** (`make up`) pour importer
> le schéma SQL. Si vous lancez `make resources` avant `make up`, le clonage se fait quand même
> et l'import SQL est simplement reporté au prochain `make resources`.

---

## 5. Configuration du fichier `.env`

**Toute** la configuration passe par `.env` — le `server.cfg` est **généré** à partir de celui-ci,
ne l'éditez jamais à la main. Référence complète ([`.env.example`](.env.example)) :

### Serveur

| Variable | Rôle | Défaut |
|----------|------|--------|
| `SERVER_NAME` | Nom affiché dans le navigateur de serveurs | `Ubuntu RP` |
| `SERVER_DESCRIPTION` | Description | `Serveur RP` |
| `MAX_CLIENTS` | Nombre de slots joueurs | `128` |
| `SV_TAGS` | Tags (séparés par des virgules) | `roleplay, français` |

### Licence & artifacts

| Variable | Rôle | Défaut |
|----------|------|--------|
| `LICENSE_KEY` | **Clé de licence FiveM (obligatoire)** | — |
| `FIVEM_BUILD_CHANNEL` | Canal d'artifact : `recommended` \| `latest` | `recommended` |
| `FIVEM_BUILD` | URL d'un `fx.tar.xz` précis (épingle un build) | vide |
| `GTA_BUILD` | `sv_enforceGameBuild` (ex. `2802`, `3095`) | vide |
| `ONESYNC` | `on` \| `legacy` \| `off` | `on` |

### Démarrage & ports

| Variable | Rôle | Défaut |
|----------|------|--------|
| `TXADMIN_ENABLE` | `true` = txAdmin, `false` = headless | `true` |
| `FIVEM_PORT` | Port jeu (hôte) | `30120` |
| `TXADMIN_PORT` | Port txAdmin (hôte) | `40120` |

### Sécurité & API

| Variable | Rôle | Défaut |
|----------|------|--------|
| `RCON_PASSWORD` | Mot de passe RCON (vide = désactivé) | `change-me-rcon` |
| `STEAM_WEBAPI_KEY` | Clé Steam Web API (facultatif) | vide |

### Base de données & cache

| Variable | Rôle | Défaut |
|----------|------|--------|
| `MYSQL_DATABASE` / `MYSQL_USER` / `MYSQL_PASSWORD` / `MYSQL_ROOT_PASSWORD` | MariaDB | `fivem` / … |
| `REDIS_PASSWORD` | Mot de passe Redis | `change-me-redis` |

### Couche RP & système

| Variable | Rôle | Défaut |
|----------|------|--------|
| `DISCORD_WEBHOOK` | Webhook Discord des logs/notifications (vide = désactivé) | vide |
| `TZ` | Fuseau horaire | `Europe/Paris` |

### Reverse proxy & monitoring (V2, opt-in)

| Variable | Rôle | Défaut |
|----------|------|--------|
| `HTTP_PORT` / `HTTPS_PORT` | Ports Nginx | `80` / `443` |
| `GRAFANA_PORT` | Port Grafana | `3000` |
| `GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD` | Identifiants Grafana | `admin` / … |

> **À changer impérativement avant la production** : tous les mots de passe (`change-me-*`),
> `RCON_PASSWORD`, `GRAFANA_ADMIN_PASSWORD`.

---

## 6. La couche RP ESX

La commande `make resources` exécute [`scripts/install-resources.sh`](scripts/install-resources.sh),
qui est **idempotent** (le relancer ne refait que ce qui a changé) et réalise ces étapes :

1. **Installation épinglée** — le **monorepo `esx_core`** (aplati) + chaque ressource (ox_lib,
   ox_inventory, ox_target, esx_identity, illenium-appearance, oxmysql, PolyZone, LegacyFuel,
   rpemotes-reborn, esx_addonaccount/esx_society, esx_policejob/esx_ambulancejob…) sont installés à
   une **révision figée** dans `data/resources/<catégorie>/`. Catégories : `[standalone]`, `[core]`,
   `[economy]`, `[jobs]`.
2. **Items ox_inventory** — étape `append_ox_items` : ajoute les items utilisés par `ubuntu-drogue`/
   `ubuntu-braquages` (baggies, kit électronique, thermite) à `ox_inventory/data/items.lua`.
3. **Overrides** — les fichiers de [`overrides/`](overrides/) sont copiés **par-dessus** les clones
   (aucun requis en Phase 1 : on reste sur les défauts ESX).
4. **Import SQL** — le schéma ESX de base ([`sql/esx-base.sql`](sql/esx-base.sql) : users, jobs,
   job_grades, user_licenses, owned_vehicles…) + le SQL des ressources sont importés dans MariaDB si
   elle tourne. Marqueur : `data/.esx-sql-imported`.

> ⚠️ **Refs ESX à confirmer** : elles ont été posées sans accès réseau (voir l'en-tête du script).
> Au premier `make resources`, un `fetch` échoué nomme la ressource à corriger.

### Ce que le dépôt versionne (et pas)

| Chemin | Versionné ? | Contenu |
|--------|-------------|---------|
| `resources/[custom]/` | ✅ oui | Nos ressources maison (`ubuntu-premium`, `ubuntu-admin`…) |
| `overrides/` | ✅ oui | Configs copiées par-dessus les clones (vide en Phase 1) |
| `sql/esx-base.sql` | ✅ oui | Schéma ESX de base |
| `scripts/install-resources.sh` | ✅ oui | Pins + installation + import SQL |
| `data/resources/` | ❌ gitignoré | Rempli par le script (clones officiels) |

### Concepts ESX par défaut

- **Monnaie `$`** partout (comptes ESX `money`/`bank`/`black_money`, montants entiers).
- **Mono-personnage** — `esx_identity` (saisie d'identité unique), pas de multichar.
- **Métiers & commerces = ESX par défaut** — Police, SAMU (+ mécano/camionneur/taxi/éboueur en option),
  commerces et concession standard.
- **Ressources maison** — boutique premium (`/boutique`), panel staff (`/admin`), interface (F1),
  location, braquages, drogue.
- **Textes en français** — `setr esx:locale "fr"` (+ `ox:locale`) active la locale fr.

### Ajouter / mettre à jour une ressource

1. Ajouter une ligne `catégorie|nom|url|révision` au tableau `RESOURCES` du script (ou changer
   le SHA pour mettre à jour).
2. Ajouter le `ensure <nom>` correspondant dans [`config/server.cfg.template`](config/server.cfg.template)
   (l'ordre compte : `oxmysql` puis `es_extended` avant tout le reste).
3. `make resources && make restart`.

> Attention aux **dépendances dures** : par ex. `qb-inventory` requiert `qb-weapons`,
> `qb-apartments` requiert `qb-interior` — déjà inclus dans l'ensemble épinglé.

---

## 7. Modes de démarrage : txAdmin vs headless

| Mode | `TXADMIN_ENABLE` | Description | Usage |
|------|------------------|-------------|-------|
| **txAdmin** (défaut) | `true` | Piloté par l'interface web sur `:40120`. Données dans `data/txData`. | Exploitation courante, administration graphique |
| **Headless** | `false` | Exécute directement le `server.cfg` généré (`+exec`), sans interface web. | Déploiement 100 % scripté / CI |

> En mode **headless**, le healthcheck du conteneur (qui sonde le port txAdmin) rapportera
> `unhealthy` — c'est normal ; adaptez-le ou repassez en txAdmin.

---

## 8. Première configuration txAdmin

Au tout premier lancement en mode txAdmin :

1. Ouvrez <http://IP_SERVEUR:40120>. txAdmin affiche un **code PIN** dans les logs
   (`make logs`) pour créer le compte administrateur maître.
2. Créez le compte, puis **« New Deployment » / serveur existant** :
   - **Server Data Folder** : `/opt/fivem`
   - **CFG File** : `/opt/fivem/config/server.cfg`
3. La base de données est déjà accessible (`mysql://fivem:...@mariadb:3306/fivem`), le schéma
   étant importé par `make resources`.
4. Démarrez le serveur depuis txAdmin.

---

## 9. Devenir administrateur en jeu

Les droits staff reposent sur le **groupe ESX** du joueur (colonne `group` de la table `users`).
Pour devenir administrateur :

1. Connectez-vous une première fois au serveur (pour exister dans la table `users`) et récupérez
   votre identifiant (visible dans txAdmin → Players, ou via la console `status` : `license:xxxxx`).
2. Ouvrez **Adminer** (`http://VOTRE_HOTE:8080`, base `fivem`), table **`users`**, et mettez la
   colonne **`group`** à `admin` (ou `superadmin`) pour votre ligne — ou en SQL :
   ```sql
   UPDATE users SET `group` = 'admin' WHERE identifier = 'license:VOTRE_LICENCE';
   ```
3. **Reconnectez-vous** pour charger le nouveau groupe. Le panel `/admin` (F6) s'ouvre alors.

> Détail complet des outils staff (panel, dons, boutique) : [`GUIDE_ADMIN.md`](GUIDE_ADMIN.md).

---

## 10. Exploitation quotidienne

Toutes les opérations passent par le [`Makefile`](Makefile) (`make help` liste les cibles) :

| Commande | Effet |
|----------|-------|
| `make up` | Build + démarre la stack V1 |
| `make up-all` | V1 + reverse proxy + monitoring (V2) |
| `make resources` | Installe/actualise la couche RP (clones + overrides + SQL) |
| `make down` | Arrête tout (conserve les volumes) |
| `make restart` | Redémarre |
| `make logs` | Suit les logs du serveur FiveM |
| `make shell` | Ouvre un shell dans le conteneur FiveM |
| `make update` | Met à jour les artifacts FiveM + recrée le conteneur |
| `make backup` | Sauvegarde base + fichiers |
| `make restore` | Restaure la dernière sauvegarde |
| `make health` | État de santé des conteneurs |
| `make ps` | Liste les conteneurs |

---

## 11. Sauvegarde & restauration

```bash
make backup                                   # -> data/backups/fivem-backup-<date>.tar.gz
make restore                                  # restaure la plus récente
make restore ARCHIVE=data/backups/fivem-backup-20260710-120000.tar.gz
```

La sauvegarde ([`scripts/backup.sh`](scripts/backup.sh)) inclut : dump MariaDB, `data/resources`,
`data/txData`, `config/` et `.env`. Rotation configurable via `BACKUP_RETENTION` (défaut 7).

> **Planifier des sauvegardes** — ajoutez une tâche cron sur l'hôte, par exemple tous les jours à 4h :
> ```
> 0 4 * * * cd /chemin/vers/ubuntu-rp && make backup >> data/logs/backup.log 2>&1
> ```

---

## 12. Mises à jour

### Artifacts FiveM

```bash
make update           # force le re-téléchargement + recrée le conteneur fivem
```
Ou épinglez un build précis via `FIVEM_BUILD=<url fx.tar.xz>` dans `.env`.

### Ressources ESX

Changez le SHA/tag concerné dans le tableau `RESOURCES` de
[`scripts/install-resources.sh`](scripts/install-resources.sh), puis :
```bash
make resources && make restart
```

> Après un changement de pin, vérifiez que les fichiers surchargés par `overrides/` n'ont pas
> changé de structure en amont (un override est une **copie complète**, pas un patch).

### Ré-importer le schéma SQL

```bash
rm data/.esx-sql-imported && make resources
```

---

## 13. Reverse proxy & monitoring (V2)

Services opt-in via **profils Compose** (le `make up` par défaut ne démarre que la V1) :

```bash
make proxy         # Nginx reverse proxy (profil "proxy")
make monitoring    # Prometheus + Grafana + Loki + Promtail + exporters
make up-all        # V1 + proxy + monitoring d'un coup
```

- **Reverse proxy** ([`config/nginx/default.conf`](config/nginx/default.conf)) — point d'entrée
  HTTP unique, vhosts par nom d'hôte : défaut → txAdmin, `grafana.local` → Grafana,
  `adminer.local` → Adminer. Bloc TLS fourni en commentaire (certificats dans
  `config/nginx/certs/`). **Le trafic jeu (30120) reste direct** — protocole brut non proxifiable.
- **Monitoring** — Grafana sur `GRAFANA_PORT` (défaut 3000), sources de données et dashboard
  « Conteneurs » auto-provisionnés. Identifiants : `GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD`.

---

## 14. Sécurité & pare-feu

- **Exposez au strict nécessaire.** En production, seul le port **jeu** doit être public :

  ```bash
  ufw allow 30120/tcp
  ufw allow 30120/udp
  # txAdmin, Adminer, Grafana : restreindre à votre IP d'admin (ou via VPN / reverse proxy)
  ufw allow from VOTRE_IP to any port 40120 proto tcp
  ufw allow from VOTRE_IP to any port 8080  proto tcp
  ufw enable
  ```

- **MariaDB et Redis ne sont jamais exposés** (pas de mapping de port hôte) — accès interne
  uniquement via le réseau `fivem-net`.
- **Secrets** : uniquement dans `.env` (gitignoré). Changez tous les `change-me-*`, le
  `RCON_PASSWORD` et le mot de passe Grafana avant toute mise en ligne.
- **Cleartext / HTTPS** : le trafic web (txAdmin/Grafana/Adminer) devrait passer derrière Nginx
  + TLS en production (voir §13).
- Le conteneur FiveM tourne en **utilisateur non-root** (uid 1000).

---

## 15. Dépannage

| Symptôme | Cause probable | Solution |
|----------|----------------|----------|
| Le serveur refuse de démarrer | `LICENSE_KEY` manquante/invalide | Renseignez-la dans `.env`, `make restart` |
| Téléchargement d'artifact échoue | Pas de réseau sortant | Vérifiez l'accès Internet ; épinglez `FIVEM_BUILD=<url>` |
| `Couldn't start resource <x>` / `Could not find dependency` | Dépendance manquante | Ajoutez la ressource au script + un `ensure`, `make resources && make restart` |
| `Access denied for command add_ace` | es_extended sans permission | Vérifiez `add_ace resource.es_extended command allow` dans le template |
| oxmysql : `Access denied` / `ECONNREFUSED` | Identifiants MariaDB ou service down | Vérifiez `MYSQL_*` dans `.env` et `make health` |
| Conteneur `fivem` `unhealthy` en headless | Le healthcheck sonde txAdmin | Normal en headless ; adaptez ou passez `TXADMIN_ENABLE=true` |
| Tables SQL absentes | Import non effectué (MariaDB down au moment du script) | `make up` puis `rm data/.esx-sql-imported && make resources` |
| Permissions sur `data/` | uid conteneur ≠ propriétaire hôte | `chown -R 1000:1000 data` |
| Ressources modifiées non prises en compte | Cache serveur | `make restart` (les overrides sont réappliqués par `make resources`) |

**Inspecter la base** : Adminer sur <http://IP_SERVEUR:8080> (serveur `mariadb`,
utilisateur/mot de passe du `.env`), ou :
```bash
docker compose exec mariadb mariadb -ufivem -p fivem -e "SHOW TABLES;"
```

**Vérifier le démarrage des ressources sans client GTA** (mode headless) :
```bash
docker compose run --rm -e TXADMIN_ENABLE=false fivem
# cherchez les lignes "Started resource ..." et l'absence de "Couldn't start"
```

---

## 16. Annexes

### Récapitulatif des ports

| Port | Protocole | Service | Exposition recommandée |
|------|-----------|---------|------------------------|
| 30120 | TCP + UDP | Jeu FiveM | **Public** |
| 40120 | TCP | txAdmin | Admin uniquement |
| 8080 | TCP | Adminer | Admin uniquement |
| 3000 | TCP | Grafana (V2) | Admin uniquement |
| 80 / 443 | TCP | Nginx (V2) | Public si utilisé |

### Volumes persistants (`data/`)

| Chemin | Contenu |
|--------|---------|
| `data/resources` | Ressources FiveM (clones officiels via `make resources`) |
| `data/txData` | Données txAdmin |
| `data/database` | Base MariaDB |
| `data/cache` | Persistance Redis (AOF) |
| `data/logs` | Journaux |
| `data/artifacts` | Artifacts FiveM téléchargés (cache) |
| `data/backups` | Sauvegardes |

### Structure du dépôt

```
ubuntu RP/
├── docker-compose.yml          # orchestration des services
├── Makefile                    # commandes d'exploitation
├── .env / .env.example         # configuration (secrets, gitignoré)
├── docker/fivem/               # Dockerfile + entrypoint du serveur
├── config/
│   ├── server.cfg.template     # modèle du server.cfg (généré au démarrage)
│   └── nginx/                  # reverse proxy (V2)
├── scripts/
│   ├── install-resources.sh    # installe la couche RP ESX
│   ├── backup.sh / restore.sh  # sauvegarde / restauration
├── overrides/                  # configs copiées par-dessus les clones ESX
├── resources/[custom]/         # ressources maison (ex. ubuntu-premium, ubuntu-admin)
├── monitoring/                 # Prometheus / Grafana / Loki (V2)
└── data/                       # état persistant (gitignoré)
```

### Critères d'acceptation (rappel spec)

- Déploiement en moins de 5 minutes · Aucune configuration manuelle interne ·
  Configuration exclusivement par `.env` · Données persistantes · Reconstruction sans perte.

---

*Pour toute évolution critique de la configuration ou du déploiement, mettez ce manuel à jour.*
