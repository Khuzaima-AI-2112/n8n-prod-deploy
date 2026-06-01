# Troubleshooting

## SSL Privacy Error

Check Traefik logs:

```bash
cd /opt/automation
docker compose logs --tail=200 traefik
```

Common causes:

- DNS does not point to the server
- port 80 is blocked
- port 443 is blocked
- invalid Let's Encrypt email
- Traefik cannot write `traefik/acme.json`

## Docker API Error in Traefik

Use a current Traefik image. This template pins Traefik to `v3.6.1`.

## n8n Does Not Load

```bash
cd /opt/automation
docker compose ps
docker compose logs --tail=100 n8n-main
docker compose logs --tail=100 n8n-webhook
```

## Queue/Worker Problems

```bash
docker compose logs --tail=100 redis
docker compose logs --tail=100 n8n-worker-1
```

Verify Redis and PostgreSQL are healthy:

```bash
docker compose ps
```

## Firewall Check

```bash
sudo ufw status verbose
```

Expected inbound ports:

```text
22/tcp
80/tcp
443/tcp
```

