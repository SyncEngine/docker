# SyncEngine Docker helper targets.
# Everything here is a shortcut for a plain `docker compose` command,
# so using make is optional — see README.md for the full commands.

COMPOSE = docker compose

.DEFAULT_GOAL := help

.PHONY: help env up down restart build rebuild update ps logs shell console migrate worker-restart backup destroy

help: ## Show this help
	@echo "SyncEngine Docker — available targets:"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

env: ## Create .env from .env.example (if it does not exist yet)
	@test -f .env && echo ".env already exists, not overwriting" || (cp .env.example .env && echo "created .env — edit it to configure SyncEngine")

up: ## Build (if needed) and start all services
	$(COMPOSE) up -d --build

down: ## Stop all services (data is kept)
	$(COMPOSE) down

restart: ## Restart all services
	$(COMPOSE) restart

build: ## Build the images
	$(COMPOSE) build

rebuild: ## Rebuild from scratch (pulls newest base images and release)
	$(COMPOSE) build --pull --no-cache

update: rebuild ## Update to the newest SyncEngine release and restart
	$(COMPOSE) up -d

ps: ## Show service status and health
	$(COMPOSE) ps

logs: ## Follow logs of all services (make logs S=php for one service)
	$(COMPOSE) logs -f $(S)

shell: ## Open a shell in the php container
	$(COMPOSE) exec php bash

console: ## Run a Symfony console command, e.g. make console CMD="cache:clear"
	$(COMPOSE) exec php php bin/console $(CMD)

migrate: ## Run database migrations manually
	$(COMPOSE) exec php php bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration

worker-restart: ## Restart the background worker
	$(COMPOSE) restart worker

backup: ## Dump the SQLite database to ./backups/
	@mkdir -p backups
	$(COMPOSE) exec php sh -c 'cat /app/var/data/data.db' > backups/syncengine-$$(date +%F-%H%M%S).db
	@ls -lh backups/ | tail -1

destroy: ## Stop everything and DELETE all data volumes (asks for confirmation)
	@printf "This deletes the database, secrets, modules and blueprints. Type 'yes' to continue: " && read answer && [ "$$answer" = "yes" ] && $(COMPOSE) down -v || echo "aborted"
