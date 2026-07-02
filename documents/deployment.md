# Деплой лендинга на garden-app.ru

Лендинг публикуется на том же VPS и домене, что и `farming_backend`:
**Timeweb Cloud** (`deploy@89.169.45.136`), домен **`garden-app.ru`**.

Статика лежит в `/var/www/garden`. nginx отдаёт её с корня домена;
пути API и deep links проксируются на FastAPI (`127.0.0.1:8000`).

---

## 1. Первичная настройка сервера (один раз)

Подключитесь к серверу и создайте каталог:

```bash
ssh deploy@89.169.45.136
sudo mkdir -p /var/www/garden
sudo chown deploy:deploy /var/www/garden
```

### nginx

Обновите `/etc/nginx/sites-available/farming` — см. актуальный пример в
[`farming_backend/documents/deployment_prod.md`](https://github.com/KonstantenKomkov/farming_backend/blob/main/documents/deployment_prod.md)
(раздел «nginx + HTTPS»).

Ключевые отличия от «только API»:

- `root /var/www/garden;`
- `location /` с `try_files` для статики и fallback `@app` на FastAPI

```bash
sudo nginx -t && sudo systemctl reload nginx
```

TLS для `garden-app.ru` уже настроен certbot'ом — повторный выпуск не нужен.

---

## 2. Автодеплой (GitHub Actions)

При пуше в `main` workflow `.github/workflows/deploy.yml`:

1. `npm ci && npm run build`
2. `rsync -avzr --delete dist/` → `/var/www/garden/`
3. HTTP-проверка `/`, `/privacy/`, `/terms/`

### Secrets (Settings → Secrets and variables → Actions)

| Secret | Пример |
|--------|--------|
| `DEPLOY_SSH_KEY` | приватный ключ пользователя `deploy` (для CI — без passphrase) |
| `DEPLOY_HOST` | `89.169.45.136` |
| `DEPLOY_USER` | `deploy` |

---

## 3. Ручной деплой

```bash
# Ключ — тот же, что для farming_backend (можно симлинк)
ln -sf ../farming_backend/timeweb_key ./timeweb_key

ssh-add timeweb_key
make update-prod-landing
```

Опции скрипта: `./scripts/update_prod_landing.sh --help`

---

## 4. Проверка после деплоя

```bash
curl -sI https://garden-app.ru/
curl -sI https://garden-app.ru/privacy/
curl -sI https://garden-app.ru/terms/
curl -sI https://garden-app.ru/health              # backend (HEAD)
curl -sI https://garden-app.ru/.well-known/assetlinks.json
curl -sI https://garden-app.ru/cultivar/1
```

---

## 5. Отключение GitHub Pages (после стабильной работы)

1. Убедитесь, что новые URL работают несколько дней.
2. GitHub → репозиторий `garden` → Settings → Pages — отключить.
3. Удалить ветку `gh-pages` (опционально).
4. Обновить URL политики в консоли RuStore вручную.
5. Выпустить Shorebird-патч приложения `farming` с новыми `privacy_policy_url` / `terms_of_service_url`.
