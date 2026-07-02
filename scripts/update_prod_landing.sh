#!/usr/bin/env bash
# Сборка лендинга и публикация dist/ на prod через rsync.
# Один SSH ControlMaster на сессию деплоя.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SSH_HOST="${SSH_HOST:-deploy@89.169.45.136}"
SSH_KEY="${SSH_KEY:-$ROOT_DIR/timeweb_key}"
SSH_CONTROL_PATH="${SSH_CONTROL_PATH:-/tmp/garden-ssh-%r@%h:%p}"
REMOTE_DIR="${REMOTE_DIR:-/var/www/garden}"
SITE_URL="${SITE_URL:-https://garden-app.ru}"
LANDING_PATHS="${LANDING_PATHS:-/ /privacy/ /terms/}"

DRY_RUN=0
SKIP_BUILD=0
SKIP_VERIFY=0

usage() {
    cat <<'EOF'
Собрать лендинг и опубликовать dist/ на prod (rsync).

Использование:
  ./scripts/update_prod_landing.sh [опции]
  make update-prod-landing

Опции:
  -h, --help        эта справка
  -n, --dry-run     показать шаги без выполнения
  --skip-build      не запускать make build (использовать существующий dist/)
  --skip-verify     не проверять HTTP после деплоя

Перед первым запуском:
  1. На сервере: sudo mkdir -p /var/www/garden && sudo chown deploy:deploy /var/www/garden
  2. nginx настроен по documents/deployment.md
  3. Добавьте SSH-ключ в агент: ssh-add timeweb_key

Переменные окружения (опционально):
  SSH_HOST          по умолчанию deploy@89.169.45.136
  SSH_KEY           по умолчанию ./timeweb_key
  REMOTE_DIR        по умолчанию /var/www/garden
  SITE_URL          по умолчанию https://garden-app.ru
  LANDING_PATHS     пути для проверки (по умолчанию "/ /privacy/ /terms/")
EOF
}

log() {
    printf '==> %s\n' "$*"
}

run() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        printf '[dry-run] %s\n' "$*"
        return 0
    fi
    "$@"
}

ssh_cmd() {
    ssh -i "$SSH_KEY" -o ControlPath="$SSH_CONTROL_PATH" "$SSH_HOST" "$@"
}

rsync_cmd() {
    rsync -avzr --delete \
        -e "ssh -i $SSH_KEY -o ControlPath=$SSH_CONTROL_PATH" \
        "$@"
}

ensure_ssh_master() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "SSH ControlMaster (пропуск в dry-run)"
        return 0
    fi
    if ssh -i "$SSH_KEY" -o ControlPath="$SSH_CONTROL_PATH" -O check "$SSH_HOST" >/dev/null 2>&1; then
        log "SSH ControlMaster уже активен"
        return 0
    fi
    log "Открываю SSH ControlMaster ($SSH_HOST)"
    run ssh -i "$SSH_KEY" \
        -o ControlMaster=yes \
        -o ControlPath="$SSH_CONTROL_PATH" \
        -o ControlPersist=600 \
        -o StrictHostKeyChecking=accept-new \
        -fN "$SSH_HOST"
}

ensure_ssh_key_loaded() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        return 0
    fi
    if [[ ! -f "$SSH_KEY" ]]; then
        echo "SSH-ключ не найден: $SSH_KEY" >&2
        echo "Скопируйте timeweb_key из farming_backend или задайте SSH_KEY." >&2
        exit 1
    fi
    chmod 600 "$SSH_KEY" 2>/dev/null || true
    if ! ssh-add -l >/dev/null 2>&1; then
        echo "ssh-agent не запущен. Выполните:" >&2
        echo "  eval \"\$(ssh-agent -s)\"" >&2
        echo "  ssh-add $SSH_KEY" >&2
        exit 1
    fi
    if [[ "$(ssh-add -l 2>/dev/null | wc -l | tr -d ' ')" == "0" ]]; then
        echo "В ssh-agent нет ключей. Выполните: ssh-add $SSH_KEY" >&2
        exit 1
    fi
}

build_landing() {
    if [[ "$SKIP_BUILD" -eq 1 ]]; then
        log "Пропуск сборки (--skip-build)"
        if [[ ! -d dist ]]; then
            echo "Каталог dist/ не найден. Уберите --skip-build или выполните make build." >&2
            exit 1
        fi
        return 0
    fi
    log "Сборка (make build)"
    run make build
}

deploy_dist() {
    log "Публикация dist/ → $SSH_HOST:$REMOTE_DIR/"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        printf '[dry-run] rsync dist/ → %s:%s/\n' "$SSH_HOST" "$REMOTE_DIR"
        return 0
    fi
    ssh_cmd "mkdir -p '$REMOTE_DIR'"
    rsync_cmd dist/ "$SSH_HOST:$REMOTE_DIR/"
}

verify_landing() {
    if [[ "$SKIP_VERIFY" -eq 1 ]]; then
        log "Пропуск HTTP-проверки (--skip-verify)"
        return 0
    fi
    log "Проверка страниц на $SITE_URL"
    local path code
    for path in $LANDING_PATHS; do
        if [[ "$DRY_RUN" -eq 1 ]]; then
            printf '[dry-run] curl -sI %s%s\n' "$SITE_URL" "$path"
            continue
        fi
        code="$(curl -s -o /dev/null -w '%{http_code}' "${SITE_URL}${path}" || true)"
        if [[ "$code" != "200" ]]; then
            echo "Страница ${SITE_URL}${path} вернула HTTP $code" >&2
            exit 1
        fi
        echo "  OK ${path} (HTTP $code)"
    done
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
        --skip-build)
            SKIP_BUILD=1
            shift
            ;;
        --skip-verify)
            SKIP_VERIFY=1
            shift
            ;;
        *)
            echo "Неизвестная опция: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

ensure_ssh_key_loaded
build_landing
ensure_ssh_master
deploy_dist
verify_landing
log "Готово"
