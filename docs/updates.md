# Updates

The safe update script creates a backup before pulling images.

```bash
cd /opt/automation
./scripts/update.sh
```

To pin a specific n8n version, edit:

```bash
/opt/automation/.env
```

Change:

```env
N8N_IMAGE=docker.n8n.io/n8nio/n8n:2.22.5
```

Then run:

```bash
./scripts/update.sh
```

Avoid `latest` tags for production unless you intentionally accept unplanned upgrades.

