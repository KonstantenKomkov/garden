# Сад — лендинг

Статический лендинг для мобильного приложения **«Сад»** — планирование сада и задач: теплицы, грядки, справочник растений и прогноз погоды.

Исходный код приложения: [farming](https://github.com/KonstantenKomkov/farming) (Flutter).  
Бэкенд и хостинг: [farming_backend](https://github.com/KonstantenKomkov/farming_backend) (Timeweb VPS, `garden-app.ru`).

## Стек

- **Astro** (SSG, без SSR)
- **TypeScript**
- **Timeweb VPS** (`garden-app.ru`) + **GitHub Actions** для автодеплоя

## Страницы

- `/` — главная (Hero, Возможности, Скриншоты, Поддержка)
- `/privacy/` — Политика конфиденциальности
- `/terms/` — Пользовательское соглашение
- `/guide/` — Руководство пользователя

## Локальная разработка

```bash
make install   # один раз
make dev       # http://localhost:4321/
```

Сборка и просмотр production-версии:

```bash
make build
make preview   # http://localhost:4321/
```

Все команды: `make help`.

Prod: <https://garden-app.ru/>

## Деплой

При пуше в `main` workflow `.github/workflows/deploy.yml` собирает проект и публикует `dist/` на VPS через rsync.

Ручной деплой (тот же сценарий):

```bash
ssh-add timeweb_key   # один раз за сессию
make update-prod-landing
```

Подробная настройка сервера (nginx, каталог `/var/www/garden`, secrets GitHub) — в [`documents/deployment.md`](documents/deployment.md).

### Secrets в GitHub (Settings → Secrets and variables → Actions)

| Secret | Значение |
|--------|----------|
| `DEPLOY_SSH_KEY` | приватный SSH-ключ пользователя `deploy` |
| `DEPLOY_HOST` | `89.169.45.136` |
| `DEPLOY_USER` | `deploy` |

## Контакты

Поддержка: [supportgardenrussia@gmail.com](mailto:supportgardenrussia@gmail.com)
