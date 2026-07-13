1. Vision globale du serveur RP

Un serveur FiveM moderne est composé de plusieurs couches :

                JOUEURS GTA V
                      |
                      |
                FiveM Client
                      |
                      |
              Serveur FiveM FXServer
                      |
        --------------------------------
        |              |               |
     Scripts        Framework       Resources
        |              |               |
        --------------------------------
                      |
                 Base de données
                      |
              PostgreSQL / MySQL
2. Stack technique recommandée

Pour un serveur moderne :

Serveur
OS : Ubuntu Server 24.04 LTS
Conteneurisation : Docker + Docker Compose
Runtime : FXServer (FiveM)
Reverse proxy : Nginx
Monitoring : Grafana + Prometheus
Backend RP

Framework existant (recommandé pour commencer)

QBCore Framework

Avantages :

moderne
très utilisé
beaucoup de scripts disponibles
architecture plus propre


3. Architecture Docker proposée
fivem-server/

├── docker-compose.yml
│
├── fxserver/
│   ├── Dockerfile
│   └── server.cfg
│
├── database/
│   └── mysql/
│
├── resources/
│
│   ├── [core]
│   │    ├── framework
│   │    └── identity
│   │
│   ├── [jobs]
│   │    ├── police
│   │    ├── ambulance
│   │    └── mechanic
│   │
│   ├── [economy]
│   │    ├── banking
│   │    └── shops
│   │
│   └── [custom]
│
└── .env
4. Services Docker

Exemple :

services:

  fivem:
    image: ghcr.io/parkervcp/yolks:ubuntu
    container_name: fivem-server
    ports:
      - "30120:30120/tcp"
      - "30120:30120/udp"
    environment:
      LICENSE_KEY: ${FIVEM_LICENSE}
      SERVER_NAME: ${SERVER_NAME}
    volumes:
      - ./resources:/server-data/resources
      - ./fxserver/server.cfg:/server-data/server.cfg


  database:
    image: mysql:8
    container_name: fivem-db
    environment:
      MYSQL_DATABASE: fivem
      MYSQL_USER: fivem
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
    volumes:
      - mysql_data:/var/lib/mysql


  adminer:
    image: adminer
    ports:
      - 8080:8080


volumes:
  mysql_data:
5. Variables environnementales

.env

SERVER_NAME=NovaLife RP

FIVEM_LICENSE=xxxxxxxxxxxxxxxx

MYSQL_DATABASE=fivem
MYSQL_USER=fivem
MYSQL_PASSWORD=password

MYSQL_ROOT_PASSWORD=rootpassword

MAX_PLAYERS=128

DISCORD_WEBHOOK=https://discord.com/api/webhooks/xxx
6. Les clés nécessaires

Pour un serveur FiveM il faut :

1. Clé serveur Cfx.re

Créée depuis :

Cfx.re

Elle permet au serveur d'être reconnu.

2. Steam API Key

Utilisée pour identifier les joueurs Steam.

3. Licence Tebex

Nécessaire si tu veux vendre :

véhicules
skins
packs VIP
monnaie virtuelle
4. Discord Bot Token

Pour :

whitelist
logs
administration
sanctions
7. Fonctionnalités RP de base
Identité joueur

Table :

players

id
license
steam_id
discord_id

firstname
lastname
birthdate
gender

cash
bank
job
Système économique
Argent liquide
       |
       |
Banque
       |
       |
Entreprise
       |
       |
Salaire
Métiers

Exemples :

Police
police
|
├── recrutement
├── grade
├── armurerie
├── véhicule service
├── prison
└── amendes
EMS
ambulance

├── soins
├── réanimation
├── hôpital
└── facturation
8. Systèmes avancés

Ensuite :

Immobilier
achat maison
location
coffre
garage
Véhicules
concessionnaire
assurance
tuning
carburant
fourrière
Entreprises

Exemple :

BurgerShot

Owner
 |
Manager
 |
Employés
 |
Stock
 |
Caisse
Criminalité
gangs
braquages
blanchiment
trafic
territoires
9. Infrastructure production

Pour un vrai serveur :

Minimum :

CPU :
8 cores

RAM :
16 Go

Stockage :
100 Go SSD

Réseau :
1 Gbps

Pour 128 joueurs :

CPU :
16 cores

RAM :
32 Go

SSD NVMe
10. Roadmap réaliste
Phase 1 — Serveur fonctionnel

Durée : 1 semaine

Docker
FXServer
QBCore
Base SQL
Connexion joueur
Personnage
Phase 2 — RP Core

Durée : 1 mois

inventaire
métiers
argent
véhicules
propriétés
Phase 3 — Gameplay

Durée : 2-3 mois

police
EMS
entreprises
gangs
événements