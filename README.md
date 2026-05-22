# Сад — лендинг

Статический лендинг для мобильного приложения **«Сад»** — приложения для планирования сада/огорода и выращивания культур.

Исходный код приложения: [farming](https://github.com/KonstantenKomkov/farming) (Flutter).

## Статус

🚧 В разработке. Приложение пока не опубликовано в сторах.

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

При пуше в `main` workflow `.github/workflows/deploy.yml` собирает проект и публикует `dist/` на GitHub Pages. В настройках репозитория включите **Pages → Source: GitHub Actions**.

## Контакты

Поддержка: [supportgardenrussia@gmail.com](mailto:supportgardenrussia@gmail.com)
