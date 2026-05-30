# agentboard-infra

Docker Compose infrastructure for AgentBoard local development, testing, and demo deployment.

![CI](https://github.com/agentboard/agentboard-infra/actions/workflows/ci.yml/badge.svg)

## Prerequisites

| Tool | Version |
|------|---------|
| Docker | 24+ |
| Docker Compose | v2+ |

## Setup (local)

```bash
# Copy environment file (defaults work for local dev)
cp .env.example .env

# Start local environment
./scripts/start-local.sh
# → PostgreSQL available at localhost:5432
# → pgAdmin available at http://localhost:5050 (login: admin@example.com / admin)
# → pgAdmin already includes server "AgentBoard Local" pointing at the postgres container

# Stop
docker compose down
```

## Compose Variants

| File | Purpose | Ports |
|------|---------|-------|
| `docker-compose.yml` | Local development with pgAdmin | postgres:5432, pgAdmin:5050 |
| `docker-compose.test.yml` | Integration test environment | postgres:5433 (no pgAdmin) |
| `docker-compose.e2e.yml` | E2E test environment with app service placeholders | postgres:5432, apps:8080-8082 |
| `docker-compose.prod.yml` | Demo VPS — GHCR images + nginx reverse proxy | HTTP:80 (configurable) |

## Production Deploy (demo VPS)

Guia completo (Tailscale, SSH, Docker, GitHub Actions): [`docs/vps-tailscale-deploy-guide.txt`](docs/vps-tailscale-deploy-guide.txt).

### 1. Bootstrap no VPS

```bash
sudo mkdir -p /opt/agentboard
sudo chown $USER:$USER /opt/agentboard
cd /opt/agentboard
git clone https://github.com/agentboard/agentboard-infra.git .
cp .env.prod.example .env.prod
# Editar .env.prod: JWT_SECRET, POSTGRES_PASSWORD, URLs públicas, GHCR_REGISTRY
```

Login no GHCR no VPS (para `docker compose pull`):

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
```

### 2. Secrets no GitHub

Configure em `agentboard-backend` e `agentboard-web`:

| Variable / Secret | Exemplo |
|-------------------|---------|
| Variable `VPS_HOST` | `100.x.x.x` (IP Tailscale da VPS) |
| Variable `VPS_USER` | `deploy` |
| Variable `VPS_DEPLOY_PATH` | `/opt/agentboard` |
| Variable `DEMO_PUBLIC_URL` | `https://demo.example.com` (apenas no repo web) |
| Secret `TS_OAUTH_CLIENT_ID` | OAuth client ID |
| Secret `TS_OAUTH_SECRET` | OAuth client secret |
| Secret `VPS_SSH_KEY` | chave privada SSH |

### 3. Deploy automático

Merge em `main` nos repos `agentboard-backend` e `agentboard-web` dispara:

1. Build das imagens Docker
2. Push para `ghcr.io/agentboard/*`
3. SSH no VPS → `docker compose pull` + `up -d`

### 4. Arquitetura nginx (demo)

| Rota pública | Serviço interno |
|--------------|-----------------|
| `/` | `agentboard-web` (SPA) |
| `/auth` | `agentboard-auth:8080` |
| `/api/v1` | `agentboard-board:8081` |
| `/ws` | `agentboard-board:8081` (WebSocket) |
| `/swagger-ui` | `agentboard-api-docs:8082` |

Configuração: [`nginx/nginx.conf`](nginx/nginx.conf).

### 5. SSL (opcional)

Adicione Certbot no host ou um container `certbot` apontando para o domínio. O `docker-compose.prod.yml` expõe a porta 80 para o nginx.

## Seeding Data

```bash
./scripts/seed-data.sh
```

> Script referenciado para uso futuro; ainda não implementado.

## Notes

- `docker-compose.test.yml` maps PostgreSQL to port 5433 to avoid conflict with a local postgres installation
- App service entries in `docker-compose.e2e.yml` use `image: placeholder` until real images are built
- pgAdmin server credentials are defined in `pgadmin/servers.json` and `pgadmin/pgpass`; update both if you change `POSTGRES_*` values in `.env`
