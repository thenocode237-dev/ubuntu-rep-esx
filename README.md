# Plateforme Docker FiveM — Ubuntu RP

Déploiement **reproductible, portable et 100 % configurable par `.env`** d'un serveur FiveM,
avec txAdmin, MariaDB, Redis et Adminer. Conçu pour un déploiement en une commande sur un hôte
Linux/Docker (VPS Ubuntu recommandé).

> Spécification de référence : [`Specification_Technique_FiveM_Docker.md`](Specification_Technique_FiveM_Docker.md).

## Sommaire

- [Architecture](#architecture)
- [Prérequis](#prérequis)
- [Démarrage rapide](#démarrage-rapide)
- [Configuration (`.env`)](#configuration-env)
- [Modes de démarrage : txAdmin vs headless](#modes-de-démarrage--txadmin-vs-headless)
- [Volumes persistants](#volumes-persistants)
- [Commandes Makefile](#commandes-makefile)
- [Couche RP (ESX)](#couche-rp-esx)
- [Sauvegarde & restauration](#sauvegarde--restauration)
- [Dépannage](#dépannage)
- [Roadmap](#roadmap)

## Architecture

| Service   | Rôle                         | Port hôte        |
|-----------|------------------------------|------------------|
| `fivem`   | Serveur FiveM + txAdmin      | `30120` TCP/UDP, `40120` (txAdmin) |
| `mariadb` | Base de données              | interne          |
| `redis`   | Cache                        | interne          |
| `adminer` | Administration SQL (web)     | `8080`           |

Tous les services communiquent sur un réseau Docker dédié `fivem-net`. Le conteneur FiveM
télécharge automatiquement les artifacts, génère `server.cfg` depuis un template et démarre —
**aucune configuration manuelle interne**.

## Prérequis

- Docker Engine 24+ et le plugin Docker Compose v2 (`docker compose`).
- `make` (facultatif mais recommandé).
- Une clé de licence FiveM : <https://keymaster.fivem.net>.
- Hôte **Linux** (les artifacts FiveM sont linux ; sur Windows utilisez Docker Desktop + WSL2).

## Démarrage rapide

```bash
make install     # crée data/ et .env (depuis .env.example)
# éditez .env : au minimum LICENSE_KEY et les mots de passe
make up          # build + démarre toute la stack
make logs        # suit le démarrage du serveur FiveM
make health      # état des conteneurs
```

Sans `make` :

```bash
mkdir -p data/{resources,txData,database,cache,logs,artifacts,backups}
cp .env.example .env      # puis éditez .env
docker compose up -d --build
```

- Interface **txAdmin** : <http://SERVEUR:40120>
- **Adminer** (SQL) : <http://SERVEUR:8080> (serveur `mariadb`)
- Connexion **jeu** : `connect SERVEUR:30120`

## Configuration (`.env`)

Toute la configuration passe par `.env` (SPECS §5). Référence :

| Variable | Rôle | Défaut |
|----------|------|--------|
| `SERVER_NAME` | Nom du serveur | `Ubuntu RP` |
| `SERVER_DESCRIPTION` | Description | `Serveur RP` |
| `MAX_CLIENTS` | Slots joueurs | `128` |
| `SV_TAGS` | Tags (navigateur de serveurs) | `roleplay, français` |
| `LICENSE_KEY` | Clé de licence FiveM (**obligatoire**) | — |
| `FIVEM_BUILD_CHANNEL` | Canal d'artifact : `recommended` \| `latest` | `recommended` |
| `FIVEM_BUILD` | URL d'un `fx.tar.xz` précis (épingle un build) | vide |
| `GTA_BUILD` | `sv_enforceGameBuild` (ex. `2802`, `3095`) | vide |
| `ONESYNC` | `on` \| `legacy` \| `off` | `on` |
| `TXADMIN_ENABLE` | `true` = txAdmin, `false` = headless | `true` |
| `FIVEM_PORT` | Port jeu (hôte) | `30120` |
| `TXADMIN_PORT` | Port txAdmin (hôte) | `40120` |
| `RCON_PASSWORD` | Mot de passe RCON | — |
| `STEAM_WEBAPI_KEY` | Clé Steam Web API (facultative) | vide |
| `MYSQL_DATABASE` / `MYSQL_USER` / `MYSQL_PASSWORD` / `MYSQL_ROOT_PASSWORD` | MariaDB | `fivem` / … |
| `REDIS_PASSWORD` | Mot de passe Redis | — |
| `TZ` | Fuseau horaire | `Europe/Paris` |

> `server.cfg` est **généré** à chaque démarrage par `envsubst` depuis
> [`config/server.cfg.template`](config/server.cfg.template) — ne l'éditez pas à la main.

## Modes de démarrage : txAdmin vs headless

- **txAdmin (défaut, `TXADMIN_ENABLE=true`)** — le serveur est piloté par l'interface web sur
  `:40120`. Les données txAdmin persistent dans `data/txData`.
- **Headless (`TXADMIN_ENABLE=false`)** — le serveur exécute directement le `server.cfg` généré
  (`+exec`), sans interface web. Idéal pour un déploiement entièrement scripté / CI.
  Dans ce mode, désactivez ou adaptez le healthcheck `fivem` (qui sonde le port txAdmin).

## Volumes persistants

Tout l'état vit sous `data/` (bind mounts) — **aucune donnée métier dans le conteneur** (SPECS §7) :

| Chemin hôte | Contenu |
|-------------|---------|
| `data/resources` | Ressources FiveM |
| `data/txData` | Données txAdmin |
| `data/database` | Base MariaDB |
| `data/cache` | Persistance Redis (AOF) |
| `data/logs` | Journaux |
| `data/artifacts` | Artifacts FiveM téléchargés (cache) |
| `data/backups` | Sauvegardes |

La reconstruction (`make down && make up`) ne perd aucune donnée : les artifacts ne sont
re-téléchargés que si le build change (ou `FIVEM_FORCE_UPDATE=1`).

## Commandes Makefile

| Commande | Effet |
|----------|-------|
| `make install` | Crée `data/` + `.env` |
| `make resources` | Installe/actualise la couche RP ESX (clones épinglés + overrides + SQL) |
| `make up` | Build + démarre la stack V1 |
| `make up-all` | V1 + reverse proxy + monitoring (V2) |
| `make proxy` | Démarre le reverse proxy Nginx (V2) |
| `make monitoring` | Démarre le monitoring (V2) |
| `make down` | Arrête (conserve les volumes) |
| `make restart` | Redémarre |
| `make logs` | Suit les logs FiveM |
| `make shell` | Shell dans le conteneur FiveM |
| `make update` | Met à jour les artifacts + recrée le conteneur |
| `make backup` | Sauvegarde base + fichiers |
| `make restore` | Restaure la dernière sauvegarde (ou `ARCHIVE=chemin`) |
| `make health` | État des conteneurs |
| `make ps` | Liste les conteneurs |

## Couche RP (ESX)

Serveur RP complet basé sur **ESX Legacy** + stack **ox** (ox_lib / ox_inventory / ox_target),
concepts **ESX par défaut**, **mono-personnage** :

- **Monnaie : dollars ($)** — comptes ESX standard `money` (liquide), `bank`, `black_money`.
- **Ressources maison** ([`resources/[custom]/`](resources/)) — boutique premium (points « Points »,
  `/boutique` + `/addpoints`), panel staff (`/admin`), interface joueur (menu F1), location de
  véhicules, braquages, trafic de drogue, anti-chute au spawn, écran de chargement.
- **Métiers & commerces = ESX par défaut** — Police, SAMU, taxi, mécanicien, camionneur, éboueur,
  concession, commerces standard.
- **Textes en français** — locale `fr` activée partout (`setr esx:locale "fr"`).

> 🔀 Le serveur a migré de **QBCore** vers **ESX** (base propre, sans l'ancien thème Cameroun/Afrique).
> Détail par phase : [`CHANGELOG.md`](CHANGELOG.md) et [`CLAUDE.md`](CLAUDE.md).

### Installation

```bash
make up          # la stack doit tourner (MariaDB) pour l'import SQL
make resources   # clone les ressources épinglées + overrides + schéma SQL
make restart     # relance le serveur avec les ressources
```

Le script [`scripts/install-resources.sh`](scripts/install-resources.sh) est **idempotent** :
le monorepo `esx_core` et chaque ressource (ox_lib, ox_inventory, ox_target, esx_identity,
 oxmysql…) sont installés à une **révision épinglée** dans
`data/resources/<catégorie>/` (gitignoré). Le schéma ESX de base est versionné dans
[`sql/esx-base.sql`](sql/esx-base.sql). Pour mettre à jour : changer la ref dans le tableau
`RESOURCES` (ou les versions en tête) et relancer `make resources`.

### Ce que versionne le dépôt

| Chemin | Rôle |
|--------|------|
| `resources/[custom]/` | Nos ressources maison (montées sur `/opt/fivem/resources/[ubuntu]`) |
| `overrides/` | Fichiers de config copiés **par-dessus** les clones (aucun requis en Phase 1) |
| `sql/esx-base.sql` | Schéma ESX de base (users/jobs/owned_vehicles…) |
| `scripts/install-resources.sh` | Pins + installation + import SQL |

Après un changement de pin, vérifier que les fichiers surchargés par `overrides/` n'ont pas
changé de structure en amont.

### Notes

- **txAdmin** : au premier lancement, pointez le « server data folder » sur `/opt/fivem`
  et le cfg sur `/opt/fivem/config/server.cfg`. En mode headless, c'est automatique.
- **Admin en jeu** : donnez-vous le groupe ESX `admin`/`superadmin` (colonne `users.group`, via
  Adminer ou txAdmin) — cf. [`GUIDE_ADMIN.md`](GUIDE_ADMIN.md).
- **SQL** : ré-import forcé en supprimant `data/.esx-sql-imported`.
- **Tests manuels (client GTA requis)** : création d'identité (esx_identity, mono-perso), `/boutique`,
  `/admin` (F6), menu F1, location de véhicule, prise de service Police/SAMU, braquage, deal.

## Sauvegarde & restauration

```bash
make backup                                   # -> data/backups/fivem-backup-<date>.tar.gz
make restore                                  # restaure la plus récente
make restore ARCHIVE=data/backups/fivem-backup-20260708-120000.tar.gz
```

La sauvegarde inclut : dump MariaDB, `data/resources`, `data/txData`, `config/` et `.env`.
Rotation configurable via `BACKUP_RETENTION` (défaut 7).

## Dépannage

- **`LICENSE_KEY` manquante** → le serveur refuse de démarrer ; renseignez-la dans `.env`.
- **Le téléchargement d'artifact échoue** → vérifiez l'accès réseau sortant ; épinglez un build
  via `FIVEM_BUILD=<url fx.tar.xz>`.
- **Permissions sur `data/`** → le conteneur tourne en uid 1000 ; assurez-vous que `data/` est
  accessible en écriture par cet uid (`chown -R 1000:1000 data` si besoin).
- **Conteneur `fivem` `unhealthy` en mode headless** → normal, le healthcheck sonde txAdmin ;
  adaptez-le ou passez `TXADMIN_ENABLE=true`.

## V2 — Reverse proxy & monitoring (opt-in)

Les services V2 sont derrière des **profils Compose** : le `make up` par défaut ne démarre que
la V1. Activez-les à la demande.

```bash
make proxy         # Nginx reverse proxy (profil "proxy")
make monitoring    # Prometheus + Grafana + Loki + Promtail + exporters
make up-all        # V1 + proxy + monitoring d'un coup
```

**Reverse proxy (Nginx)** — point d'entrée HTTP unique ([config/nginx/default.conf](config/nginx/default.conf)),
vhosts par nom d'hôte : défaut → txAdmin, `grafana.local` → Grafana, `adminer.local` → Adminer.
Bloc TLS fourni en commentaire (certificats dans `config/nginx/certs/`). Le trafic **jeu**
(30120) reste direct — protocole brut, non proxifiable par Nginx.

**Monitoring** — métriques via cAdvisor (conteneurs) + node-exporter (hôte) → Prometheus ; logs
via Promtail (socket Docker + `data/logs`) → Loki ; visualisation **Grafana** (sur
`GRAFANA_PORT`, défaut 3000), sources de données et un dashboard « Conteneurs » auto-provisionnés.
Identifiants Grafana : `GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD`.

**CI/CD** — [.github/workflows/ci.yml](.github/workflows/ci.yml) : lint (shellcheck, hadolint,
`compose config`) → build & push de l'image vers **GHCR** → déploiement SSH optionnel (secrets
`DEPLOY_HOST`/`DEPLOY_USER`/`DEPLOY_SSH_KEY`/`DEPLOY_PATH`).

**Optimisation image** — `docker/fivem/.dockerignore` réduit le contexte de build ; `apt` nettoyé
et `--no-install-recommends` ; les artifacts sont téléchargés au runtime (image de base légère).

## Roadmap

- **V1 (livrée)** — Docker Compose, FiveM, txAdmin, MariaDB, Redis, Adminer, génération
  `server.cfg`, artifacts auto, sauvegardes, Makefile, documentation.
- **V2 (livrée)** — Nginx (reverse proxy), monitoring (Prometheus/Grafana/Loki/Promtail), CI/CD,
  optimisation de l'image.
- **Couche RP (livrée)** — **ESX Legacy + stack ox** (base propre, concepts par défaut, `$`,
  mono-personnage) : socle + ressources maison (boutique premium, admin, interface, location,
  braquages, drogue) + métiers ESX (Police/SAMU). Cf. `CHANGELOG.md` (migration QBCore → ESX).
- **Phase 3 RP** — téléphone (npwd) + housing (staged/désactivés), HUD, entreprises, gangs.
- **V3** — clustering d'outils, marketplace de ressources, mises à jour intelligentes, API
  d'administration.
