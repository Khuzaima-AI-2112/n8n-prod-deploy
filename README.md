# n8n Production Deploy

Reusable production template for deploying a Docker-based n8n automation server on a fresh Ubuntu 24.04 LTS VPS.

The stack includes Traefik, Let's Encrypt HTTPS, PostgreSQL, Redis, n8n queue mode, a webhook processor, configurable workers, Uptime Kuma, backups, updates, firewall rules, Fail2Ban, and automatic security updates.

## Quick Start

Prerequisites:

- Fresh Ubuntu 24.04 LTS server
- DNS records already pointing to the server:
  - `n8n.example.com`
  - `uptime.example.com`
- SSH access with a sudo user, or root access for first-time bootstrap
- Local machine with `bash`, `ssh`, and `scp`

Run from your laptop:

```bash
./install.sh --host SERVER_IP --user deploy --bootstrap-root
```

If the sudo user already exists:

```bash
./install.sh --host SERVER_IP --user deploy
```

For unattended installation, the sudo user must have passwordless sudo. The `--bootstrap-root` path creates that sudoers rule automatically. You may remove it after deployment if you prefer password-protected sudo:

```bash
sudo rm /etc/sudoers.d/90-deploy-n8n-prod-deploy
```

The installer prompts for:

- n8n domain
- Uptime Kuma domain
- Let's Encrypt email
- timezone
- worker count, default `2`

The production stack is installed at:

```bash
/opt/automation
```

## What Gets Deployed

- Traefik reverse proxy with Let's Encrypt
- PostgreSQL 17
- Redis 7
- n8n main instance
- n8n webhook instance
- n8n workers
- Uptime Kuma
- UFW firewall
- Fail2Ban SSH jail
- unattended security updates
- Docker log rotation
- daily local backups

## Operations

SSH into the server:

```bash
ssh deploy@SERVER_IP
cd /opt/automation
```

Check services:

```bash
docker compose ps
./scripts/healthcheck.sh
```

Manual backup:

```bash
./scripts/backup.sh
```

Safe update:

```bash
./scripts/update.sh
```

Change worker count:

```bash
./scripts/add-worker.sh 4
```

Restore:

```bash
./scripts/restore.sh /opt/automation/backups/YYYY-MM-DD_HH-MM-SS
```

## Security Notes

Do not commit real `.env` files, secrets, private keys, client domains, or backups. This repository includes `.env.example` only.

After deployment, create the first n8n owner account and Uptime Kuma admin account in the browser. Do not send those credentials in chat.

## Documentation

- [DNS requirements](docs/dns.md)
- [Backup and restore](docs/backup-restore.md)
- [Updates](docs/updates.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Fiverr handover checklist](docs/handover-checklist.md)
