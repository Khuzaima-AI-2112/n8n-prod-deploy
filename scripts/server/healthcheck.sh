#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-/opt/automation}"
cd "$BASE_DIR"
set -a
source .env
set +a

docker compose ps
curl -fsSI "https://$DOMAIN_N8N" >/dev/null
curl -fsSI "https://$DOMAIN_KUMA" >/dev/null
sudo ufw status verbose
sudo fail2ban-client status sshd
crontab -l

echo "Healthcheck completed."

