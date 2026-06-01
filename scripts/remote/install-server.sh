#!/usr/bin/env bash
set -euo pipefail

: "${INSTALL_PATH:?INSTALL_PATH is required}"
: "${DOMAIN_N8N:?DOMAIN_N8N is required}"
: "${DOMAIN_KUMA:?DOMAIN_KUMA is required}"
: "${LETSENCRYPT_EMAIL:?LETSENCRYPT_EMAIL is required}"
: "${TZ_VALUE:?TZ_VALUE is required}"
: "${WORKER_COUNT:?WORKER_COUNT is required}"

REMOTE_TMP="/tmp/n8n-prod-deploy"

if ! sudo -n true 2>/dev/null; then
  echo "This installer requires passwordless sudo for the target user." >&2
  echo "Use --bootstrap-root, or add a temporary sudoers rule before running the installer." >&2
  exit 1
fi

source /etc/os-release
if [[ "${VERSION_ID:-}" != "24.04" ]]; then
  echo "Ubuntu 24.04 is required. Detected: ${PRETTY_NAME:-unknown}" >&2
  exit 1
fi

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ufw fail2ban unattended-upgrades apt-listchanges curl ca-certificates gnupg lsb-release openssl

sudo install -m 0755 -d /etc/apt/keyrings
if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
fi

if [[ ! -f /etc/apt/sources.list.d/docker.list ]]; then
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
fi

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker "$USER"

sudo tee /etc/docker/daemon.json >/dev/null <<'JSON'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "5"
  }
}
JSON
sudo systemctl restart docker

sudo tee /etc/fail2ban/jail.d/sshd.local >/dev/null <<'INI'
[sshd]
enabled = true
port = ssh
filter = sshd
backend = systemd
maxretry = 5
findtime = 10m
bantime = 1h
INI
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban

sudo dpkg-reconfigure -f noninteractive unattended-upgrades
sudo systemctl enable unattended-upgrades

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.n8n-prod-deploy
sudo tee /etc/ssh/sshd_config.d/99-n8n-prod-deploy.conf >/dev/null <<'SSH'
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
KbdInteractiveAuthentication no
UsePAM yes
SSH
sudo sshd -t
sudo systemctl restart ssh

sudo mkdir -p "$INSTALL_PATH"/{templates,traefik,postgres,redis,n8n,uptime-kuma,backups,logs,scripts}
sudo chown -R "$USER:$USER" "$INSTALL_PATH"
chmod 750 "$INSTALL_PATH"

cp "$REMOTE_TMP/templates/docker-compose.yml.tpl" "$INSTALL_PATH/templates/docker-compose.yml.tpl"
cp "$REMOTE_TMP/server/"*.sh "$INSTALL_PATH/scripts/"
chmod 700 "$INSTALL_PATH/scripts/"*.sh

touch "$INSTALL_PATH/traefik/acme.json"
chmod 600 "$INSTALL_PATH/traefik/acme.json"
mkdir -p "$INSTALL_PATH/n8n/data/logs" "$INSTALL_PATH/n8n/files"

if [[ ! -f "$INSTALL_PATH/.env" ]]; then
  cat > "$INSTALL_PATH/.env" <<ENV
TZ=$TZ_VALUE

DOMAIN_N8N=$DOMAIN_N8N
DOMAIN_KUMA=$DOMAIN_KUMA
LETSENCRYPT_EMAIL=$LETSENCRYPT_EMAIL

POSTGRES_DB=n8n
POSTGRES_USER=n8n
POSTGRES_PASSWORD=$(openssl rand -hex 32)

N8N_IMAGE=docker.n8n.io/n8nio/n8n:2.22.5
TRAEFIK_IMAGE=traefik:v3.6.1
POSTGRES_IMAGE=postgres:17-alpine
REDIS_IMAGE=redis:7-alpine
UPTIME_KUMA_IMAGE=louislam/uptime-kuma:1

N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)
N8N_USER_MANAGEMENT_JWT_SECRET=$(openssl rand -base64 32)
ENV
  chmod 600 "$INSTALL_PATH/.env"
fi

printf '%s\n' "$WORKER_COUNT" > "$INSTALL_PATH/.worker-count"
cd "$INSTALL_PATH"
./scripts/render-compose.sh
docker network inspect proxy >/dev/null 2>&1 || docker network create proxy
docker network inspect internal >/dev/null 2>&1 || docker network create internal
docker compose config >/dev/null
docker compose up -d

(crontab -l 2>/dev/null | grep -v '/opt/automation.*backup.sh' || true; \
  echo "15 2 * * * cd $INSTALL_PATH && set -a && . ./.env && set +a && ./scripts/backup.sh >> $INSTALL_PATH/logs/backup.log 2>&1") | crontab -

./scripts/healthcheck.sh
