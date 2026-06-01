name: automation

x-n8n-env: &n8n-env
  TZ: ${TZ}
  GENERIC_TIMEZONE: ${TZ}
  N8N_HOST: ${DOMAIN_N8N}
  N8N_PROTOCOL: https
  N8N_PORT: 5678
  N8N_EDITOR_BASE_URL: https://${DOMAIN_N8N}/
  WEBHOOK_URL: https://${DOMAIN_N8N}/
  N8N_PROXY_HOPS: 1
  N8N_SECURE_COOKIE: "true"

  DB_TYPE: postgresdb
  DB_POSTGRESDB_HOST: postgres
  DB_POSTGRESDB_PORT: 5432
  DB_POSTGRESDB_DATABASE: ${POSTGRES_DB}
  DB_POSTGRESDB_USER: ${POSTGRES_USER}
  DB_POSTGRESDB_PASSWORD: ${POSTGRES_PASSWORD}
  DB_POSTGRESDB_POOL_SIZE: 10

  EXECUTIONS_MODE: queue
  QUEUE_BULL_REDIS_HOST: redis
  QUEUE_BULL_REDIS_PORT: 6379
  QUEUE_HEALTH_CHECK_ACTIVE: "true"
  OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS: "true"

  N8N_ENCRYPTION_KEY: ${N8N_ENCRYPTION_KEY}
  N8N_USER_MANAGEMENT_JWT_SECRET: ${N8N_USER_MANAGEMENT_JWT_SECRET}
  N8N_DEFAULT_BINARY_DATA_MODE: database

  EXECUTIONS_DATA_PRUNE: "true"
  EXECUTIONS_DATA_MAX_AGE: 168
  EXECUTIONS_DATA_PRUNE_MAX_COUNT: 50000
  EXECUTIONS_DATA_SAVE_ON_SUCCESS: none
  EXECUTIONS_DATA_SAVE_ON_ERROR: all
  EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS: "true"
  EXECUTIONS_DATA_SAVE_ON_PROGRESS: "false"
  EXECUTIONS_TIMEOUT: 3600
  EXECUTIONS_TIMEOUT_MAX: 7200
  N8N_AI_TIMEOUT_MAX: 3600000

  N8N_DIAGNOSTICS_ENABLED: "false"
  N8N_HIRING_BANNER_ENABLED: "false"
  N8N_PUBLIC_API_SWAGGERUI_DISABLED: "true"
  N8N_LOG_LEVEL: info
  N8N_GRACEFUL_SHUTDOWN_TIMEOUT: 60

services:
  traefik:
    image: ${TRAEFIK_IMAGE}
    container_name: traefik
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    command:
      - --api.dashboard=false
      - --ping=true
      - --log.level=INFO
      - --accesslog=true
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --providers.docker.network=proxy
      - --entrypoints.web.address=:80
      - --entrypoints.web.http.redirections.entrypoint.to=websecure
      - --entrypoints.web.http.redirections.entrypoint.scheme=https
      - --entrypoints.websecure.address=:443
      - --certificatesresolvers.letsencrypt.acme.email=${LETSENCRYPT_EMAIL}
      - --certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json
      - --certificatesresolvers.letsencrypt.acme.httpchallenge=true
      - --certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik/acme.json:/letsencrypt/acme.json
    networks:
      - proxy

  postgres:
    image: ${POSTGRES_IMAGE}
    container_name: postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      PGDATA: /var/lib/postgresql/data/pgdata
    volumes:
      - ./postgres/data:/var/lib/postgresql/data
    networks:
      - internal
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U \"$${POSTGRES_USER}\" -d \"$${POSTGRES_DB}\""]
      interval: 10s
      timeout: 5s
      retries: 10

  redis:
    image: ${REDIS_IMAGE}
    container_name: redis
    restart: unless-stopped
    command: ["redis-server", "--appendonly", "yes", "--save", "60", "1000"]
    volumes:
      - ./redis/data:/data
    networks:
      - internal
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 10

  n8n-main:
    image: ${N8N_IMAGE}
    container_name: n8n-main
    restart: unless-stopped
    environment:
      <<: *n8n-env
      N8N_DISABLE_PRODUCTION_MAIN_PROCESS: "true"
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
      - proxy
    labels:
      - traefik.enable=true
      - traefik.http.routers.n8n-main.rule=Host(`${DOMAIN_N8N}`)
      - traefik.http.routers.n8n-main.entrypoints=websecure
      - traefik.http.routers.n8n-main.tls.certresolver=letsencrypt
      - traefik.http.routers.n8n-main.priority=10
      - traefik.http.services.n8n-main.loadbalancer.server.port=5678

  n8n-webhook:
    image: ${N8N_IMAGE}
    container_name: n8n-webhook
    restart: unless-stopped
    command: webhook
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
      - proxy
    labels:
      - traefik.enable=true
      - traefik.http.routers.n8n-webhook.rule=Host(`${DOMAIN_N8N}`) && (PathPrefix(`/webhook/`) || PathPrefix(`/webhook-waiting/`))
      - traefik.http.routers.n8n-webhook.entrypoints=websecure
      - traefik.http.routers.n8n-webhook.tls.certresolver=letsencrypt
      - traefik.http.routers.n8n-webhook.priority=100
      - traefik.http.services.n8n-webhook.loadbalancer.server.port=5678

{{WORKER_SERVICES}}
  uptime-kuma:
    image: ${UPTIME_KUMA_IMAGE}
    container_name: uptime-kuma
    restart: unless-stopped
    volumes:
      - ./uptime-kuma/data:/app/data
    networks:
      - proxy
    labels:
      - traefik.enable=true
      - traefik.http.routers.uptime.rule=Host(`${DOMAIN_KUMA}`)
      - traefik.http.routers.uptime.entrypoints=websecure
      - traefik.http.routers.uptime.tls.certresolver=letsencrypt
      - traefik.http.services.uptime.loadbalancer.server.port=3001

networks:
  proxy:
    external: true
  internal:
    external: true

