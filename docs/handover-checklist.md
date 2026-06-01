# Client Handover Checklist

Provide screenshots or command output for:

```bash
cd /opt/automation
docker compose ps
curl -I https://N8N_DOMAIN
curl -I https://UPTIME_DOMAIN
sudo ufw status verbose
sudo fail2ban-client status sshd
crontab -l
./scripts/backup.sh
ls -lh backups
```

Tell the client:

- n8n URL
- Uptime Kuma URL
- first admin accounts must be created by the client
- stack path is `/opt/automation`
- backups run daily
- updates should use `./scripts/update.sh`
- restore uses `./scripts/restore.sh BACKUP_PATH`

Do not send:

- `.env`
- private SSH keys
- passwords
- API keys
- backup archives

