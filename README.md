# Сад — лендинг

Статический лендинг для мобильного приложения **«Сад»** — планирование сада и задач: теплицы, грядки, справочник растений и прогноз погоды.

Исходный код приложения: [farming](https://github.com/KonstantenKomkov/farming) (Flutter).

## Статус

🚧 В разработке. Приложение ещё не опубликовано в сторах.

## Стек

- **Astro** (SSG, без SSR)
- **TypeScript**
- **GitHub Pages** + **GitHub Actions** для деплоя

## Страницы

- `/` — главная (Hero, Возможности, Скриншоты, Поддержка)
- `/privacy/` — Политика конфиденциальности
- `/terms/` — Пользовательское соглашение

## Локальная разработка

```bash
make install   # один раз
make dev       # http://localhost:4321/garden/
```

Сборка и просмотр production-версии:

```bash
make build
make preview   # http://localhost:4321/garden/
```

Все команды: `make help`.

Сайт публикуется на GitHub Pages с базовым путём `/garden/`:
<https://konstantenkomkov.github.io/garden/>

## Деплой

При пуше в `main` workflow `.github/workflows/deploy.yml` собирает проект и публикует `dist/` на GitHub Pages.

### Первый запуск (обязательно)

1. Запушьте код в `main` и дождитесь успешного workflow **Deploy to GitHub Pages** (он создаст ветку `gh-pages`).
2. [Settings → Pages](https://github.com/KonstantenKomkov/garden/settings/pages):
   - **Source:** Deploy from a branch
   - **Branch:** `gh-pages` → `/ (root)` → **Save**
   - **Custom domain:** оставить **пустым** (не вводить `github.io` и не URL с `/garden/`)
3. Через 1–2 минуты откройте <https://konstantenkomkov.github.io/garden/>

Если **Save** неактивна — очистите Custom domain (крестик) и выберите ветку `gh-pages` (появится после первого успешного деплоя).

## Контакты

Поддержка: [supportgardenrussia@gmail.com](mailto:supportgardenrussia@gmail.com)
