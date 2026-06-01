#!/usr/bin/env bash
set -euo pipefail

: "${NEW_USER:?NEW_USER is required}"
: "${PUBLIC_KEY:?PUBLIC_KEY is required}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "bootstrap-user.sh must run as root" >&2
  exit 1
fi

if ! id "$NEW_USER" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "$NEW_USER"
fi

usermod -aG sudo "$NEW_USER"
install -d -m 700 -o "$NEW_USER" -g "$NEW_USER" "/home/$NEW_USER/.ssh"
printf '%s\n' "$PUBLIC_KEY" > "/home/$NEW_USER/.ssh/authorized_keys"
chown "$NEW_USER:$NEW_USER" "/home/$NEW_USER/.ssh/authorized_keys"
chmod 600 "/home/$NEW_USER/.ssh/authorized_keys"

printf '%s\n' "$NEW_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-$NEW_USER-n8n-prod-deploy"
chmod 440 "/etc/sudoers.d/90-$NEW_USER-n8n-prod-deploy"
visudo -cf "/etc/sudoers.d/90-$NEW_USER-n8n-prod-deploy" >/dev/null

echo "Sudo user '$NEW_USER' is ready with key auth and temporary passwordless sudo."
