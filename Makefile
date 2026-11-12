SHELL := /bin/bash
COMPOSE := docker compose

.PHONY: help init up down restart logs status import-keys backup restore check pull upgrade

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

init: ## First-time setup: .env, JWT secret, data dirs with the right owners
	@./scripts/init.sh

up: ## Start execution, beacon, validator and monitoring
	$(COMPOSE) up -d

down: ## Stop everything (state is kept under ./data)
	$(COMPOSE) down

restart: ## Restart the chain clients only
	$(COMPOSE) restart reth beacon validator

logs: ## Tail logs for the chain clients
	$(COMPOSE) logs -f --tail=200 reth beacon validator

status: ## One-screen health summary: sync, peers, validator duties
	@./scripts/status.sh

import-keys: ## Import keystores from ./keys-import into the validator client (stops the VC briefly)
	@./scripts/import-keys.sh

backup: ## Export the slashing-protection database to ./backups (stops the VC for ~30s)
	@./scripts/backup-slashing-protection.sh

restore: ## Import a slashing-protection export: make restore FILE=backups/<file>.json
	@./scripts/restore-slashing-protection.sh $(FILE)

pull: ## Pull the images pinned in .env
	$(COMPOSE) pull

upgrade: pull ## Pull new images and recreate containers; run `make backup` first
	$(COMPOSE) up -d --remove-orphans

check: ## Lint: compose config, yaml, shell, prometheus rules, dashboard json
	@./scripts/check.sh
