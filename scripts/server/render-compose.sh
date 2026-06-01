#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-/opt/automation}"
WORKER_COUNT="$(cat "$BASE_DIR/.worker-count" 2>/dev/null || echo 2)"
TEMPLATE="$BASE_DIR/templates/docker-compose.yml.tpl"
OUTPUT="$BASE_DIR/docker-compose.yml"

if ! [[ "$WORKER_COUNT" =~ ^[0-9]+$ ]] || [[ "$WORKER_COUNT" -lt 1 ]]; then
  echo "Worker count must be a positive integer" >&2
  exit 1
fi

workers_file="$(mktemp)"
trap 'rm -f "$workers_file"' EXIT

for i in $(seq 1 "$WORKER_COUNT"); do
  cat >> "$workers_file" <<WORKER
  n8n-worker-$i:
    image: \${N8N_IMAGE}
    container_name: n8n-worker-$i
    restart: unless-stopped
    command: worker --concurrency=5
    environment:
      <<: *n8n-env
    volumes:
      - ./n8n/data:/home/node/.n8n
      - ./n8n/files:/home/node/.n8n-files
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - internal

WORKER
done

awk -v workers_file="$workers_file" '
  $0 == "{{WORKER_SERVICES}}" {
    while ((getline line < workers_file) > 0) print line
    close(workers_file)
    next
  }
  { print }
' "$TEMPLATE" > "$OUTPUT"

echo "Rendered $OUTPUT with $WORKER_COUNT worker(s)."
