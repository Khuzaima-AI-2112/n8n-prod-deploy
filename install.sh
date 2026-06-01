#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./install.sh --host SERVER_IP --user deploy [options]

Options:
  --host IP_OR_HOST          Target server IP/hostname.
  --user USER                SSH sudo user on the target server.
  --port PORT                SSH port. Default: 22.
  --key PATH                 SSH private key path.
  --path PATH                Remote install path. Default: /opt/automation.
  --worker-count NUMBER      n8n worker count. Default: 2.
  --bootstrap-root           First connect as root and create/prepare --user.
  -h, --help                 Show help.

Example:
  ./install.sh --host 203.0.113.10 --user deploy --bootstrap-root
USAGE
}

HOST=""
USER_NAME=""
SSH_PORT="22"
SSH_KEY=""
INSTALL_PATH="/opt/automation"
WORKER_COUNT="2"
BOOTSTRAP_ROOT="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="${2:-}"; shift 2 ;;
    --user) USER_NAME="${2:-}"; shift 2 ;;
    --port) SSH_PORT="${2:-}"; shift 2 ;;
    --key) SSH_KEY="${2:-}"; shift 2 ;;
    --path) INSTALL_PATH="${2:-}"; shift 2 ;;
    --worker-count) WORKER_COUNT="${2:-}"; shift 2 ;;
    --bootstrap-root) BOOTSTRAP_ROOT="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$HOST" || -z "$USER_NAME" ]]; then
  usage
  exit 1
fi

if ! [[ "$WORKER_COUNT" =~ ^[0-9]+$ ]] || [[ "$WORKER_COUNT" -lt 1 ]]; then
  echo "--worker-count must be a positive integer" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_OPTS=(-p "$SSH_PORT")
SCP_OPTS=(-P "$SSH_PORT")
if [[ -n "$SSH_KEY" ]]; then
  SSH_OPTS+=(-i "$SSH_KEY" -o IdentitiesOnly=yes)
  SCP_OPTS+=(-i "$SSH_KEY" -o IdentitiesOnly=yes)
fi

read -r -p "n8n domain (example: n8n.example.com): " DOMAIN_N8N
read -r -p "Uptime Kuma domain (example: uptime.example.com): " DOMAIN_KUMA
read -r -p "Let's Encrypt email: " LETSENCRYPT_EMAIL
read -r -p "Timezone [UTC]: " TZ_VALUE
TZ_VALUE="${TZ_VALUE:-UTC}"

if [[ -z "$DOMAIN_N8N" || -z "$DOMAIN_KUMA" || -z "$LETSENCRYPT_EMAIL" ]]; then
  echo "Domains and Let's Encrypt email are required." >&2
  exit 1
fi

quote() {
  printf '%q' "$1"
}

if [[ "$BOOTSTRAP_ROOT" == "true" ]]; then
  echo "Bootstrapping sudo user '$USER_NAME' through root SSH..."
  PUBLIC_KEY_PATH="${SSH_KEY:-$HOME/.ssh/id_ed25519}.pub"
  if [[ ! -f "$PUBLIC_KEY_PATH" ]]; then
    echo "Public key not found: $PUBLIC_KEY_PATH" >&2
    echo "Create one with: ssh-keygen -t ed25519" >&2
    exit 1
  fi
  PUBLIC_KEY="$(cat "$PUBLIC_KEY_PATH")"
  ssh "${SSH_OPTS[@]}" root@"$HOST" \
    "NEW_USER=$(quote "$USER_NAME") PUBLIC_KEY=$(quote "$PUBLIC_KEY") bash -s" \
    < "$SCRIPT_DIR/scripts/remote/bootstrap-user.sh"
fi

REMOTE_TMP="/tmp/n8n-prod-deploy"
echo "Uploading deployment bundle..."
ssh "${SSH_OPTS[@]}" "$USER_NAME@$HOST" "rm -rf '$REMOTE_TMP' && mkdir -p '$REMOTE_TMP'"
scp "${SCP_OPTS[@]}" -r \
  "$SCRIPT_DIR/templates" \
  "$SCRIPT_DIR/scripts/remote" \
  "$SCRIPT_DIR/scripts/server" \
  "$USER_NAME@$HOST:$REMOTE_TMP/"

echo "Running remote installer..."
ssh "${SSH_OPTS[@]}" "$USER_NAME@$HOST" \
  "INSTALL_PATH=$(quote "$INSTALL_PATH") DOMAIN_N8N=$(quote "$DOMAIN_N8N") DOMAIN_KUMA=$(quote "$DOMAIN_KUMA") LETSENCRYPT_EMAIL=$(quote "$LETSENCRYPT_EMAIL") TZ_VALUE=$(quote "$TZ_VALUE") WORKER_COUNT=$(quote "$WORKER_COUNT") bash '$REMOTE_TMP/remote/install-server.sh'"

echo
echo "Deployment complete."
echo "n8n:         https://$DOMAIN_N8N"
echo "Uptime Kuma: https://$DOMAIN_KUMA"

