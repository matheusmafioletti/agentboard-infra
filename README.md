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

| `docker-compose.prod.yml` | Demo VPS — GHCR images + nginx reverse proxy | localhost:8080 → Docker nginx (host nginx on 80/443) |
| `docker-compose.e2e.yml` | E2E CI/local — full GHCR stack + nginx single-origin | `0.0.0.0:8080` |

## E2E Stack (Docker Compose)

Dedicated compose for running E2E tests against GHCR images with single-origin routing at `http://localhost:8080`.

### Prerequisites

- Docker Compose v2+
- GHCR login: `echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin`
- Web image tag **`e2e-latest`** (or `e2e-<sha>`) — never use demo `latest` web image in compose E2E

### Quick start

```bash
cp .env.e2e.example .env.e2e
./scripts/e2e-up.sh          # start stack (--wait)
./scripts/seed-e2e-data.sh   # staging-smoke user + baseline project
./scripts/e2e-down.sh        # stop (keeps volume)
./scripts/e2e-reset.sh       # down -v + up — replaces per-test DB cleanup
./scripts/e2e-wait.sh        # poll health + GET /
```

From workspace root:

```bash
./scripts/run-e2e-local.sh playwright [--reset]
```

### Image tags

| Context | Tags |
|---------|------|
| Local `e2e-up.sh` | `latest` (auth/board/api-docs), `e2e-latest` (web) |
| PR backend | `<sha>` (backend services), `e2e-latest` (web) |
| PR web | `latest` (backend), `e2e-<sha>` (web) |
| `repository_dispatch` | SHA from payload |

### Seed credentials (`.env.e2e.example`)

| Variable | Default |
|----------|---------|
| `E2E_STAGING_USER_EMAIL` | `staging-smoke@agentboard.dev` |
| `E2E_STAGING_USER_PASSWORD` | `StagingSmoke123!` |
| `E2E_STAGING_TENANT_NAME` | `E2E Smoke Workspace` |

Used by `@staging` smoke tests and `seed-e2e-data.sh`.



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

| `/api/swagger` | `agentboard-api-docs:8082` |



Configuração: [`nginx/nginx.conf`](nginx/nginx.conf).



### 5. SSL (host nginx + Certbot)

Production uses **host nginx** on ports 80/443 for TLS termination. Docker nginx binds **127.0.0.1:8080** only.

| Domain | Backend |
|--------|---------|
| `agentboard.matheusmafioletti.com` | Docker stack via `127.0.0.1:8080` |
| `matheusmafioletti.com` | Static files in `/var/www/portfolio` |

Setup: [`docs/DNS.md`](docs/DNS.md), [`docs/SSL-BOOTSTRAP.md`](docs/SSL-BOOTSTRAP.md), [`docs/host-nginx-agentboard.conf.example`](docs/host-nginx-agentboard.conf.example), [`scripts/bootstrap-host-ssl.sh`](scripts/bootstrap-host-ssl.sh).

`DEMO_PUBLIC_URL`: `https://agentboard.matheusmafioletti.com`



## Seeding Data



```bash

./scripts/seed-data.sh

```



> Script referenciado para uso futuro; ainda não implementado.



## Notes



- `docker-compose.test.yml` maps PostgreSQL to port 5433 to avoid conflict with a local postgres installation

- `.env.prod` e `.image-tags` na VPS são gerados pelo deploy e estão no `.gitignore`

- pgAdmin server credentials are defined in `pgadmin/servers.json` and `pgadmin/pgpass`; update both if you change `POSTGRES_*` values in `.env`

