#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-/opt/automation}"
BACKUP_PATH="${1:-}"

if [[ -z "$BACKUP_PATH" ]]; then
  echo "Usage: ./scripts/restore.sh /opt/automation/backups/YYYY-MM-DD_HH-MM-SS" >&2
  exit 1
fi

if [[ ! -d "$BACKUP_PATH" ]]; then
  echo "Backup directory not found: $BACKUP_PATH" >&2
  exit 1
fi

cd "$BASE_DIR"

test -s "$BACKUP_PATH/postgres_n8n.sql"
tar -tzf "$BACKUP_PATH/n8n_data.tar.gz" >/dev/null
tar -tzf "$BACKUP_PATH/traefik_acme.tar.gz" >/dev/null

docker compose down
rm -rf "$BASE_DIR/n8n/data" "$BASE_DIR/n8n/files"
tar -xzf "$BACKUP_PATH/n8n_data.tar.gz" -C "$BASE_DIR/n8n"
tar -xzf "$BACKUP_PATH/traefik_acme.tar.gz" -C "$BASE_DIR/traefik"
cp "$BACKUP_PATH/docker-compose.yml" "$BASE_DIR/docker-compose.yml"
cp "$BACKUP_PATH/env.backup" "$BASE_DIR/.env"
chmod 600 "$BASE_DIR/.env"

set -a
source .env
set +a

docker compose up -d postgres redis
sleep 10
cat "$BACKUP_PATH/postgres_n8n.sql" | docker compose exec -T postgres psql -U "$POSTGRES_USER" "$POSTGRES_DB"
docker compose up -d
docker compose ps

