#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-/opt/automation}"
COUNT="${1:-}"

if [[ -z "$COUNT" ]]; then
  echo "Usage: ./scripts/add-worker.sh WORKER_COUNT" >&2
  exit 1
fi

if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || [[ "$COUNT" -lt 1 ]]; then
  echo "Worker count must be a positive integer" >&2
  exit 1
fi

cd "$BASE_DIR"
printf '%s\n' "$COUNT" > .worker-count
./scripts/render-compose.sh
docker compose up -d
docker compose ps

