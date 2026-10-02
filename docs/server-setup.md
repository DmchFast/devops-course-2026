# Конфигурация виртуальной машины devops-vm

## 1. Параметры машины
- Объём оперативной памяти: 2048 МБ
- Количество ядер процессора: 2
- Объём дискового накопителя: 25 ГБ (динамически расширяемый)

## 2. Сетевые интерфейсы
- enp0s3: NAT, адрес 10.0.2.15/24 — доступ в интернет, обновление пакетов
- enp0s8: Host-only, адрес 192.168.56.102/24 — доступ с хостовой системы, веб-сервер (работа №6)

## 3. Правило проброса портов
- Хост 127.0.0.1:2222 → Гость 2222 (SSH)

## 4. Учётные записи
- student (uid=1000, группы: student, adm, cdrom, sudo, dip, plugdev, users, lpadmin) — парольная аутентификация, sudo
- devops (uid=1001, группы: devops, sudo, users) — вход по ключу ~/.ssh/devops_vm (ed25519), sudo

## 5. Служба SSH
- Порт: 2222
- Файл конфигурации: /etc/ssh/sshd_config.d/99-hardening.conf
- Изменённые директивы:
  - Port 2222
  - PermitRootLogin no
  - PasswordAuthentication no
  - PubkeyAuthentication yes
  - PermitEmptyPasswords no
  - MaxAuthTries 3
  - LoginGraceTime 30
  - AllowUsers devops
  - X11Forwarding no
  - ClientAliveInterval 300
  - ClientAliveCountMax 2
- ssh.socket отключён (systemctl disable --now ssh.socket)

## 6. Правила межсетевого экрана
- Политики по умолчанию: deny incoming, allow outgoing
- Правила:
  - 2222/tcp LIMIT (SSH rate-limited)
  - 80/tcp ALLOW (HTTP)
  - 443/tcp ALLOW (HTTPS)
- Логирование: medium

## 7. Снимки состояния
- 01-clean-install — исходная конфигурация
- 02-keys-configured — после задания 1 (ключи, пользователь devops)
- 03-ssh-hardened — после задания 2 (SSH на 2222, root и пароли отключены)
- 04-firewall — после задания 3 (UFW активен, правило LIMIT)
- 05-dns — после задания 4 (devops.local, FQDN)
