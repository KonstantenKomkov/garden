NPM ?= npm
PORT ?= 4321

.PHONY: help install dev build preview clean

help:
	@echo "Команды лендинга «Сад»:"
	@echo "  make install   — установить зависимости (npm ci)"
	@echo "  make dev       — dev-сервер с hot reload"
	@echo "  make build     — статическая сборка в dist/"
	@echo "  make preview   — просмотр собранного сайта (сначала make build)"
	@echo "  make clean     — удалить dist/ и кэш Astro"
	@echo ""
	@echo "Локально: http://localhost:$(PORT)/garden/"

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
