#!/usr/bin/env bash
set -uo pipefail

PASS=0; FAIL=0

check() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo " [OK]  $desc"
    ((PASS++))
  else
    echo " [FAIL] $desc (ожидалось: '$expected', получено: '$actual')"
    ((FAIL++))
  fi
}

echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"

echo "[1] Служба SSH"
check "Вход от имени root запрещён" "no" "$(sudo sshd -T | awk '/^permitrootlogin/{print $2}')"
check "Парольная аутентификация отключена" "no" "$(sudo sshd -T | awk '/^passwordauthentication/{print $2}')"

PORT_VAL=$(sudo sshd -T | awk '/^port/{print $2}')
if [[ "$PORT_VAL" != "22" ]]; then
  echo " [OK]  Порт SSH отличен от 22 (port=$PORT_VAL)"
  ((PASS++))
else
  echo " [FAIL] Порт SSH равен 22"
  ((FAIL++))
fi

check "MaxAuthTries равен 3" "3" "$(sudo sshd -T | awk '/^maxauthtries/{print $2}')"

echo "[2] Межсетевой экран"
check "Межсетевой экран активен" "active" "$(sudo ufw status | awk '/^Status:/{print $2}')"
check "Политика по умолчанию: deny incoming" "deny" "$(sudo ufw status verbose | awk -F'[ ,]+' '/^Default:/{print $2}')"

echo "[3] Учётные записи"
awk -F: ' $3>=1000 && $3<65534 {printf " %s (uid=%s)\n",$1,$3}' /etc/passwd

echo "[4] Веб-сервер"
check "Nginx: конфигурация синтаксически корректна" "0" "$(sudo nginx -t >/dev/null 2>&1; echo $?)"

DAYS_OK=$(sudo openssl x509 -in /etc/ssl/certs/devops.crt -noout -checkend 2592000 >/dev/null 2>&1; echo $?)
check "Сертификат действителен не менее 30 дней" "0" "$DAYS_OK"

W_WRITABLE=$(sudo find /var/www/devops-site -perm -o+w | wc -l)
check "Нет файлов с правом записи для всех" "0" "$W_WRITABLE"

check "Права ключа TLS = 600" "600" "$(sudo stat -c '%a' /etc/ssl/private/devops.key)"

echo "[5] Контейнеризация"
check "Служба docker активна" "active" "$(systemctl is-active docker)"

# Проверка healthcheck базы данных (может занять пару секунд)
DB_HEALTH=$(docker inspect -f '{{.State.Health.Status}}' app-db-1 2>/dev/null || echo "not_found")
check "Контейнер СУБД healthy" "healthy" "$DB_HEALTH"

# Проверка портов (5000 и 5432 не должны слушать 0.0.0.0)
PORTS_OPEN=$(sudo ss -tln | awk '$4 ~ /0\.0\.0\.0:(5000|5432)/ {print $4}' | wc -l)
check "Порты 5000/5432 не опубликованы в 0.0.0.0" "0" "$PORTS_OPEN"

# Проверка прав .env
ACTUAL_USER="${SUDO_USER:-$USER}"
HOME_DIR=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
check "Права .env = 600" "600" "$(stat -c '%a' "${HOME_DIR}/devops-course-2026/app/.env")"

echo "[6] Контрольная работа № 2"

# Путь к проекту КР2 (используем HOME_DIR, чтобы работало под sudo)
KR2_DIR="${HOME_DIR}/kr2"

# а) Redis в состоянии healthy
KR2_REDIS_ID=$(docker compose --project-directory "$KR2_DIR" ps -q redis 2>/dev/null)
KR2_REDIS_HEALTH=$(docker inspect -f '{{.State.Health.Status}}' "$KR2_REDIS_ID" 2>/dev/null || echo "not_found")
check "КР2: Redis healthy" "healthy" "$KR2_REDIS_HEALTH"

# б) Порт 8004 опубликован только на 127.0.0.1
KR2_PORT=$(docker compose --project-directory "$KR2_DIR" port app 8004 2>/dev/null || echo "not_published")
check "КР2: Порт 8004 на 127.0.0.1" "127.0.0.1:8004" "$KR2_PORT"

# в) Права файла ~/kr2/.env равны 600
check "КР2: Права .env = 600" "600" "$(stat -c '%a' "$KR2_DIR/.env")"

# г) Сертификат kr2.crt действителен не менее 30 дней
KR2_CERT_OK=$(sudo openssl x509 -in /etc/ssl/certs/kr2.crt -noout -checkend 2592000 >/dev/null 2>&1; echo $?)
check "КР2: Сертификат kr2.crt > 30 дней" "0" "$KR2_CERT_OK"

# д) Ресурс kr2 активирован (символическая ссылка)
KR2_SYMLINK=$(ls /etc/nginx/sites-enabled/kr2 2>/dev/null | wc -l)
check "КР2: Сайт kr2 активирован" "1" "$KR2_SYMLINK"

echo
echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
