#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-/opt/automation}"
cd "$BASE_DIR"

./scripts/backup.sh
docker compose pull
docker compose up -d
docker image prune -f
docker compose ps

