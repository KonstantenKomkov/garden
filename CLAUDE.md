# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Команды

```bash
make install              # npm ci, требуется Node >=22.12
make dev                  # astro dev → http://localhost:4321/
make build                # статическая сборка в dist/
make preview              # build + astro preview
make clean                # удалить dist/ и кэш .astro/
make update-prod-landing  # сборка + rsync dist/ на prod (SSH)
```

Тестов и линтера в проекте нет. Тайпчек выполняется только при `astro build` (TS из `astro/tsconfigs/strict`).

## Архитектура

Лендинг мобильного Flutter-приложения «Сад» — Astro 6 SSG, без SSR и без UI-фреймворков. Только `.astro` + ванильный CSS.

**Сайт публикуется на `https://garden-app.ru/`** (корень домена, тот же VPS и nginx, что и `farming_backend`). В `astro.config.mjs` задан `site: 'https://garden-app.ru'` и `trailingSlash: 'always'`, без `base`. Любые внутренние ссылки и пути к ассетам в публичной папке должны строиться через `import.meta.env.BASE_URL` — иначе они сломаются при смене базового пути (пример паттерна — `src/components/Header.astro`, `src/layouts/BaseLayout.astro`). Никогда не хардкодить `/` как абсолютный путь к ассетам.

**`src/site.ts` — единый источник правды** для контента: метаданные сайта (`site`), список фич (`features`), скриншоты (`screenshots`). Поле `site.legalUpdated` отображается на юридических страницах — обновлять при правках `/privacy/` и `/terms/`. Текстовые правки лендинга идут через этот файл, а не через компоненты.

**Структура страниц:**
- `src/pages/index.astro` — главная, собирает Hero → Features → Screenshots → Support
- `src/pages/privacy.astro`, `src/pages/terms.astro` — юридические, оборачивают контент в `LegalLayout`
- `src/pages/guide.astro` — руководство пользователя
- `BaseLayout` отвечает за `<head>`, OG-теги, canonical, шапку/подвал; `LegalLayout` оборачивает `BaseLayout` для типовых юридических страниц

**Шрифты** Manrope (sans) и Philosopher Italic (display, для вордмарка «Сад») подключены через `@font-face` в `src/styles/global.css` из `src/assets/fonts/`. CSS-переменные (бренд-палитра `--brand-*`, ink, радиусы) задаются в `:root` там же.

## Деплой

`main` → GitHub Actions (`.github/workflows/deploy.yml`) → `npm ci && npm run build` → rsync `dist/` на VPS (`/var/www/garden`). nginx на сервере отдаёт статику с корня домена; пути API (`/api/`, `/admin/`, `/.well-known/`, `/cultivar/` и т.д.) проксируются на FastAPI. См. `documents/deployment.md` и `farming_backend/documents/deployment_prod.md`.

Ручной деплой: `make update-prod-landing` (скрипт `scripts/update_prod_landing.sh`, SSH-ключ `timeweb_key`).

## Коммиты

Сообщения коммитов — на русском (см. историю и `.cursor/commands/commit.md`).
