# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Команды

```bash
make install   # npm ci, требуется Node >=22.12
make dev       # astro dev → http://localhost:4321/garden/
make build     # статическая сборка в dist/
make preview   # build + astro preview
make clean     # удалить dist/ и кэш .astro/
```

Тестов и линтера в проекте нет. Тайпчек выполняется только при `astro build` (TS из `astro/tsconfigs/strict`).

## Архитектура

Лендинг мобильного Flutter-приложения «Сад» — Astro 6 SSG, без SSR и без UI-фреймворков. Только `.astro` + ванильный CSS.

**Базовый путь `/garden/` критически важен.** Сайт публикуется на `https://konstantenkomkov.github.io/garden/`, поэтому в `astro.config.mjs` задан `base: '/garden/'` и `trailingSlash: 'always'`. Любые внутренние ссылки и пути к ассетам в публичной папке должны строиться через `import.meta.env.BASE_URL` — иначе они сломаются на проде (пример паттерна — `src/components/Header.astro`, `src/layouts/BaseLayout.astro`). Никогда не хардкодить `/` как абсолютный путь.

**`src/site.ts` — единый источник правды** для контента: метаданные сайта (`site`), список фич (`features`), скриншоты (`screenshots`). Поле `site.legalUpdated` отображается на юридических страницах — обновлять при правках `/privacy/` и `/terms/`. Текстовые правки лендинга идут через этот файл, а не через компоненты.

**Структура страниц:**
- `src/pages/index.astro` — главная, собирает Hero → Features → Screenshots → Support
- `src/pages/privacy.astro`, `src/pages/terms.astro` — юридические, оборачивают контент в `LegalLayout`
- `BaseLayout` отвечает за `<head>`, OG-теги, canonical, шапку/подвал; `LegalLayout` оборачивает `BaseLayout` для типовых юридических страниц

**Шрифты** Manrope (sans) и Philosopher Italic (display, для вордмарка «Сад») подключены через `@font-face` в `src/styles/global.css` из `src/assets/fonts/`. CSS-переменные (бренд-палитра `--brand-*`, ink, радиусы) задаются в `:root` там же.

## Деплой

`main` → GitHub Actions (`.github/workflows/deploy.yml`) → `npm ci && npm run build` → публикация `dist/` в ветку `gh-pages` через `peaceiris/actions-gh-pages`. Pages настроен на ветку `gh-pages` (`/ (root)`), Custom domain должен быть пустым. Файл `public/.nojekyll` обязателен.

## Коммиты

Сообщения коммитов — на русском (см. историю и `.cursor/commands/commit.md`).
