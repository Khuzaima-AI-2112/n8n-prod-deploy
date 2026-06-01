# Backup and Restore

Backups run daily at 02:15 server time through the `deploy` user's crontab.

Manual backup:

```bash
cd /opt/automation
./scripts/backup.sh
```

Backups are stored under:

```bash
/opt/automation/backups
```

Each backup contains:

```text
postgres_n8n.sql
n8n_data.tar.gz
traefik_acme.tar.gz
docker-compose.yml
env.backup
```

Validate latest backup:

```bash
cd /opt/automation
LATEST_BACKUP="$(ls -td backups/* | head -1)"
test -s "$LATEST_BACKUP/postgres_n8n.sql" && echo "Postgres dump exists"
tar -tzf "$LATEST_BACKUP/n8n_data.tar.gz" >/dev/null && echo "n8n archive is valid"
tar -tzf "$LATEST_BACKUP/traefik_acme.tar.gz" >/dev/null && echo "Traefik archive is valid"
```

Restore:

```bash
cd /opt/automation
./scripts/restore.sh /opt/automation/backups/YYYY-MM-DD_HH-MM-SS
```

Do a restore only during a maintenance window.

