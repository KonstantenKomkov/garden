#!/usr/bin/env bash
# Настройка nginx на prod: статика лендинга из /var/www/garden + fallback на FastAPI.
# Одно SSH ControlMaster-соединение на всю операцию.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SSH_HOST="${SSH_HOST:-deploy@89.169.45.136}"
SSH_KEY="${SSH_KEY:-$ROOT_DIR/timeweb_key}"
if [[ ! -f "$SSH_KEY" && -f "$HOME/.ssh/garden_deploy_ci" ]]; then
    SSH_KEY="$HOME/.ssh/garden_deploy_ci"
fi
SSH_CONTROL_PATH="${SSH_CONTROL_PATH:-/tmp/garden-nginx-ssh-%r@%h:%p}"
SITE_URL="${SITE_URL:-https://garden-app.ru}"
NGINX_SITE="${NGINX_SITE:-/etc/nginx/sites-available/farming}"
SNIPPET_PATH="/etc/nginx/snippets/garden-landing.conf"

DRY_RUN=0

usage() {
    cat <<'EOF'
Настроить nginx для лендинга на garden-app.ru (try_files + @app).

Использование:
  ./scripts/setup_prod_nginx.sh [опции]
  make setup-prod-nginx

Опции:
  -h, --help    эта справка
  -n, --dry-run показать шаги без изменений на сервере

Перед запуском:
  ssh-add timeweb_key   # или ключ garden_deploy_ci

Переменные (опционально):
  SSH_HOST, SSH_KEY, NGINX_SITE, SITE_URL
EOF
}

log() {
    printf '==> %s\n' "$*"
}

ssh_cmd() {
    ssh -i "$SSH_KEY" -o ControlPath="$SSH_CONTROL_PATH" "$SSH_HOST" "$@"
}

ensure_ssh_master() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        return 0
    fi
    if ssh -i "$SSH_KEY" -o ControlPath="$SSH_CONTROL_PATH" -O check "$SSH_HOST" >/dev/null 2>&1; then
        log "SSH ControlMaster уже активен"
        return 0
    fi
    log "Открываю SSH ControlMaster ($SSH_HOST)"
    ssh -i "$SSH_KEY" \
        -o ControlMaster=yes \
        -o ControlPath="$SSH_CONTROL_PATH" \
        -o ControlPersist=600 \
        -o StrictHostKeyChecking=accept-new \
        -fN "$SSH_HOST"
}

ensure_ssh_key() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        return 0
    fi
    if [[ ! -f "$SSH_KEY" ]]; then
        echo "SSH-ключ не найден: $SSH_KEY" >&2
        exit 1
    fi
    chmod 600 "$SSH_KEY" 2>/dev/null || true
}

remote_setup() {
    log "Настройка nginx на сервере"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        printf '[dry-run] ssh: patch %s, nginx -t, reload\n' "$NGINX_SITE"
        return 0
    fi

    ssh_cmd "SNIPPET_PATH='$SNIPPET_PATH' NGINX_SITE='$NGINX_SITE' SITE_URL='$SITE_URL' bash -s" <<'REMOTE'
set -euo pipefail

if [[ ! -f "$NGINX_SITE" ]]; then
    echo "Файл nginx не найден: $NGINX_SITE" >&2
    exit 1
fi

if ! sudo test -d /var/www/garden; then
    echo "Каталог /var/www/garden не найден. Сначала: make update-prod-landing" >&2
    exit 1
fi

if ! sudo test -f /var/www/garden/index.html; then
    echo "Нет /var/www/garden/index.html. Сначала задеплойте лендинг." >&2
    exit 1
fi

STAMP=$(date +%Y%m%d%H%M%S)
sudo cp "$NGINX_SITE" "${NGINX_SITE}.bak.${STAMP}"
echo "Бэкап: ${NGINX_SITE}.bak.${STAMP}"

sudo mkdir -p /etc/nginx/snippets
sudo tee "$SNIPPET_PATH" >/dev/null <<'SNIPPET'
# Лендинг «Сад» (Astro dist в /var/www/garden). Подключается в server { listen 443 ssl; }.
root /var/www/garden;
index index.html;

location / {
    try_files $uri $uri/ $uri/index.html @app;
}

location @app {
    proxy_pass http://127.0.0.1:8000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 120s;
}
SNIPPET

if sudo grep -q 'snippets/garden-landing.conf' "$NGINX_SITE"; then
    echo "include garden-landing.conf уже есть — пропуск правки $NGINX_SITE"
else
    sudo python3 - "$NGINX_SITE" "$SNIPPET_PATH" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
snippet = sys.argv[2]
text = path.read_text()
include_line = f"    include {snippet};\n"

if "root /var/www/garden" in text or "snippets/garden-landing.conf" in text:
    print("Конфиг уже содержит лендинг — пропуск")
    sys.exit(0)

# Удалить старый location / с proxy_pass на 8000 (без location = /admin/login).
pattern = re.compile(
    r"\n[ \t]*location / \{[^{}]*proxy_pass\s+http://127\.0\.0\.1:8000;[^{}]*\}\n",
    re.MULTILINE | re.DOTALL,
)
new_text, count = pattern.subn("\n" + include_line, text, count=1)
if count != 1:
    print("Не удалось найти location / { proxy_pass ... } для замены.", file=sys.stderr)
    print("Отредактируйте вручную: добавьте include snippets/garden-landing.conf в server 443.", file=sys.stderr)
    sys.exit(1)

path.write_text(new_text)
print("Заменён location / на include snippets/garden-landing.conf")
PY
fi

sudo nginx -t
sudo systemctl reload nginx
echo "nginx reload OK"

for path in / /privacy/ /terms/; do
    code=$(curl -s -o /dev/null -w '%{http_code}' "${SITE_URL}${path}")
    echo "  ${SITE_URL}${path} -> HTTP ${code}"
    if [[ "$code" != "200" ]]; then
        exit 1
    fi
done

code=$(curl -s -o /dev/null -w '%{http_code}' -I "${SITE_URL}/health")
echo "  ${SITE_URL}/health (HEAD) -> HTTP ${code}"
if [[ "$code" != "200" ]]; then
    exit 1
fi
REMOTE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h | --help)
            usage
            exit 0
            ;;
        -n | --dry-run)
            DRY_RUN=1
            shift
            ;;
        *)
            echo "Неизвестная опция: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

ensure_ssh_key
ensure_ssh_master
remote_setup
log "Готово"
