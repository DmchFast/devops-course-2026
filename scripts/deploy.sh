#!/usr/bin/env bash
# Доставка статического ресурса на devops-vm
# Использование: scripts/deploy.sh [--dry-run]
set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"
LOCAL_DIR="$(git rev-parse --show-toplevel)/site"

# 1. Разбор аргумента --dry-run
DRY_RUN=0
if [[ $# -gt 0 ]]; then
  if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=1
  else
    echo "Неизвестный аргумент: $1" >&2
    exit 1
  fi
fi

# 2. Проверки по требованиям 4 и 5
if [[ ! -f "${LOCAL_DIR}/index.html" ]]; then
  echo "Ошибка: файл ${LOCAL_DIR}/index.html не найден" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Ошибка: в репозитории есть незафиксированные изменения" >&2
  exit 1
fi

# 3. Синхронизация (одно SSH-соединение)
RSYNC_SSH="ssh -o BatchMode=yes -o ConnectTimeout=5"

if [[ $DRY_RUN -eq 1 ]]; then
  rsync -avz --delete --chmod=D755,F644 --dry-run \
    -e "${RSYNC_SSH}" \
    "${LOCAL_DIR}/" "${REMOTE}:${REMOTE_DIR}/"
  exit 0
fi

rsync -avz --delete --chmod=D755,F644 \
  -e "${RSYNC_SSH}" \
  "${LOCAL_DIR}/" "${REMOTE}:${REMOTE_DIR}/"

# 5. Проверка доступности с проверкой сертификата
if ! curl -sf --cacert "${CA_CERT}" -o /dev/null "${SITE_URL}"; then
  echo "Ошибка: ресурс ${SITE_URL} недоступен" >&2
  exit 1
fi

# Успех: короткий хеш коммита
echo "Доставлен коммит: $(git rev-parse --short HEAD)"
exit 0
