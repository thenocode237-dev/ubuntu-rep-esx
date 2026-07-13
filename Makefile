# Makefile — plateforme Docker FiveM (SPECS §13)
# Usage : make <cible>. `make help` liste les cibles.

COMPOSE := docker compose
DATA_DIRS := resources txData database cache logs artifacts backups \
             monitoring/prometheus monitoring/grafana monitoring/loki

# Profils V2 (opt-in) : reverse proxy + monitoring.
PROFILES := --profile proxy --profile monitoring

.DEFAULT_GOAL := help
.PHONY: help install resources up up-all proxy monitoring down restart build logs shell update backup restore health ps

help: ## Affiche cette aide
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

install: ## Prépare l'arborescence data/ et le fichier .env
	@mkdir -p $(addprefix data/,$(DATA_DIRS))
	@if [ ! -f .env ]; then cp .env.example .env; echo "-> .env créé depuis .env.example (à personnaliser)"; fi
	@echo "Installation prête. Éditez .env, lancez 'make up', puis 'make resources' (couche RP QBCore)."

resources: ## Installe/actualise la couche RP QBCore (clones épinglés + overrides + SQL)
	@bash scripts/install-resources.sh

up: ## Démarre la stack V1 (build + détaché)
	$(COMPOSE) up -d --build

up-all: ## Démarre V1 + reverse proxy + monitoring (V2)
	$(COMPOSE) $(PROFILES) up -d --build

proxy: ## Démarre le reverse proxy Nginx (V2)
	$(COMPOSE) --profile proxy up -d

monitoring: ## Démarre le stack monitoring (Prometheus/Grafana/Loki) (V2)
	$(COMPOSE) --profile monitoring up -d

down: ## Arrête toute la stack (conserve les volumes)
	$(COMPOSE) $(PROFILES) down

restart: ## Redémarre la stack
	$(COMPOSE) restart

build: ## (Re)construit l'image FiveM
	$(COMPOSE) build

ps: ## Liste les conteneurs
	$(COMPOSE) ps

logs: ## Suit les logs du serveur FiveM
	$(COMPOSE) logs -f fivem

shell: ## Ouvre un shell dans le conteneur FiveM
	$(COMPOSE) exec fivem bash

update: ## Met à jour les artifacts FiveM et recrée le conteneur
	FIVEM_FORCE_UPDATE=1 $(COMPOSE) up -d --force-recreate fivem

backup: ## Sauvegarde base + fichiers (data/backups/)
	@bash scripts/backup.sh

restore: ## Restaure la dernière sauvegarde (ou ARCHIVE=chemin)
	@bash scripts/restore.sh $(ARCHIVE)

health: ## État de santé des conteneurs
	$(COMPOSE) ps --format "table {{.Name}}\t{{.Status}}"
