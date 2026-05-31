# agentboard-infra

Docker Compose infrastructure for AgentBoard local development, testing, and demo deployment.

![CI](https://github.com/matheusmafioletti/agentboard-infra/actions/workflows/ci.yml/badge.svg)
![Deploy](https://github.com/matheusmafioletti/agentboard-infra/actions/workflows/deploy.yml/badge.svg)

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

Guia completo (Tailscale, SSH, Docker): [`docs/vps-tailscale-deploy-guide.txt`](docs/vps-tailscale-deploy-guide.txt).

Checklist de secrets/variables: [`docs/GITHUB_DEPLOY_SECRETS.md`](docs/GITHUB_DEPLOY_SECRETS.md).

### Arquitetura CI/CD

| Repo | Responsabilidade |
|------|------------------|
| `agentboard-backend` | Testes + build/push imagens auth, board, api-docs → `repository_dispatch` |
| `agentboard-web` | Testes + build/push imagem web → `repository_dispatch` |
| **`agentboard-infra`** | Deploy na VPS: `.env.prod`, tags, `docker compose pull/up` |

### 1. Bootstrap no VPS

```bash
sudo mkdir -p /opt/agentboard
sudo chown deploy:deploy /opt/agentboard
cd /opt/agentboard
git clone https://github.com/matheusmafioletti/agentboard-infra.git .
echo $GITHUB_PAT | docker login ghcr.io -u USERNAME --password-stdin
```

Não é necessário copiar `.env.prod` manualmente — o workflow **Deploy** gera o arquivo na VPS.

### 2. Secrets no GitHub (somente neste repo)

Configure variables e secrets conforme [`docs/GITHUB_DEPLOY_SECRETS.md`](docs/GITHUB_DEPLOY_SECRETS.md).

Nos repos `agentboard-backend` e `agentboard-web`, configure apenas `INFRA_DEPLOY_PAT` (e `DEMO_PUBLIC_URL` no web).

### 3. Primeiro deploy

1. Actions → **Deploy** → Run workflow → modo `full`
2. Depois, merge em `main` em backend/web dispara deploy automático via `repository_dispatch`

Deploy manual: Actions → Deploy → escolher `full`, `backend` ou `web` e tags opcionais.

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
- `.env.prod` e `.image-tags` na VPS são gerados pelo deploy e estão no `.gitignore`
- pgAdmin server credentials are defined in `pgadmin/servers.json` and `pgadmin/pgpass`; update both if you change `POSTGRES_*` values in `.env`
