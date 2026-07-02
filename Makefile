NPM ?= npm
PORT ?= 4321
SSH_HOST ?= deploy@89.169.45.136
SSH_KEY ?= ./timeweb_key
REMOTE_DIR ?= /var/www/garden
SITE_URL ?= https://garden-app.ru

.PHONY: help install dev build preview clean update-prod-landing setup-prod-nginx

help:
	@echo "Команды лендинга «Сад»:"
	@echo "  make install              — установить зависимости (npm ci)"
	@echo "  make dev                  — dev-сервер с hot reload"
	@echo "  make build                — статическая сборка в dist/"
	@echo "  make preview              — просмотр собранного сайта (сначала make build)"
	@echo "  make clean                — удалить dist/ и кэш Astro"
	@echo "  make update-prod-landing  — сборка и деплой dist/ на prod (SSH + rsync)"
	@echo "  make setup-prod-nginx     — настроить nginx для лендинга на prod (один раз)"
	@echo ""
	@echo "Локально: http://localhost:$(PORT)/"
	@echo "Prod:     $(SITE_URL)/"

install:
	$(NPM) ci

dev:
	$(NPM) run dev

build:
	$(NPM) run build

preview: build
	$(NPM) run preview

clean:
	rm -rf dist .astro

update-prod-landing:
	SSH_HOST=$(SSH_HOST) SSH_KEY=$(SSH_KEY) REMOTE_DIR=$(REMOTE_DIR) SITE_URL=$(SITE_URL) \
		./scripts/update_prod_landing.sh

setup-prod-nginx:
	SSH_HOST=$(SSH_HOST) SSH_KEY=$(SSH_KEY) SITE_URL=$(SITE_URL) \
		./scripts/setup_prod_nginx.sh
