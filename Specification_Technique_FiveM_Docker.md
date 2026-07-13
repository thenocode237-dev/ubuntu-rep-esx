# Spécification technico-fonctionnelle -- Plateforme Docker FiveM

## 1. Objectif

Construire une plateforme Docker permettant de déployer un serveur FiveM
entièrement configurable via des variables d'environnement,
reproductible, portable et évolutive.

## 2. Objectifs fonctionnels

-   Déploiement en une commande (`docker compose up -d`)
-   Configuration par fichier `.env`
-   Génération automatique de `server.cfg`
-   Téléchargement automatique des artifacts FiveM
-   Support txAdmin
-   Persistance des données
-   MariaDB, Redis et Adminer intégrés
-   Sauvegardes et restauration
-   Journalisation et supervision
-   Compatible CI/CD

## 3. Architecture

-   fivem : serveur FiveM
-   mariadb : base de données
-   redis : cache
-   adminer : administration SQL
-   nginx (V2)
-   backup (V2)
-   monitoring (V2)

Tous les services communiquent via un réseau Docker dédié.

## 4. Arborescence

``` text
docker-compose.yml
.env
docker/
config/
data/
scripts/
monitoring/
```

## 5. Variables d'environnement

Le fichier `.env` centralise : - informations serveur - licence FiveM -
ports - paramètres txAdmin - paramètres MariaDB - paramètres Redis -
fuseau horaire - OneSync - build GTA

## 6. Génération automatique

`server.cfg` est généré à partir d'un template avec `envsubst`.

## 7. Volumes persistants

-   data/resources
-   data/txData
-   data/database
-   data/cache
-   data/logs

Aucune donnée métier ne doit rester dans le conteneur.

## 8. Dockerfile

Le conteneur FiveM doit : 1. Installer les dépendances. 2. Télécharger
automatiquement les derniers artifacts. 3. Vérifier leur intégrité. 4.
Générer `server.cfg`. 5. Démarrer txAdmin/FiveM.

## 9. Sécurité

-   Exécution sous utilisateur non-root.
-   Variables sensibles dans `.env`.
-   Healthchecks.
-   Restart policies.
-   UFW conseillé côté hôte.

## 10. Sauvegardes

Sauvegarde automatique de : - base MariaDB - ressources - txData -
configuration

Compression et rotation.

## 11. Monitoring (V2)

-   Prometheus
-   Grafana
-   Loki
-   Promtail

## 12. CI/CD

Pipeline : - build - tests - construction image - publication registre -
déploiement VPS

## 13. Makefile

Commandes prévues : - make install - make up - make down - make logs -
make shell - make update - make backup - make restore - make health

## 14. Roadmap

### V1

-   Docker Compose
-   FiveM
-   txAdmin
-   MariaDB
-   Redis
-   Adminer
-   génération server.cfg

### V2

-   Nginx
-   sauvegardes
-   monitoring
-   CI/CD
-   optimisation image

### V3

-   clustering d'outils
-   marketplace de ressources
-   mises à jour intelligentes
-   API d'administration

## 15. Critères d'acceptation

-   Déploiement en moins de 5 minutes.
-   Aucune configuration manuelle interne.
-   Configuration exclusivement par `.env`.
-   Données persistantes.
-   Reconstruction sans perte.
-   Documentation complète.
