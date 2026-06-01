#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-/opt/automation}"
BACKUP_DIR="$BASE_DIR/backups"
DATE="$(date +%F_%H-%M-%S)"
TARGET="$BACKUP_DIR/$DATE"

cd "$BASE_DIR"
set -a
source .env
set +a

mkdir -p "$TARGET"

docker compose exec -T postgres pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > "$TARGET/postgres_n8n.sql"
tar -czf "$TARGET/n8n_data.tar.gz" -C "$BASE_DIR/n8n" data files
tar -czf "$TARGET/traefik_acme.tar.gz" -C "$BASE_DIR/traefik" acme.json
cp "$BASE_DIR/docker-compose.yml" "$TARGET/docker-compose.yml"
cp "$BASE_DIR/.env" "$TARGET/env.backup"

find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -mtime +14 -exec rm -rf {} \;

echo "Backup completed: $TARGET"

