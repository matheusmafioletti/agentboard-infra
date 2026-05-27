# agentboard-infra

Docker Compose infrastructure for AgentBoard local development and testing.

## Prerequisites

| Tool | Version |
|------|---------|
| Docker | 24+ |
| Docker Compose | v2+ |

## Setup

```bash
# Copy environment file (defaults work for local dev)
cp .env.example .env

# Start local environment
./scripts/start-local.sh
# → PostgreSQL available at localhost:5432
# → pgAdmin available at http://localhost:5050

# Stop
docker compose down
```

## Compose Variants

| File | Purpose | Ports |
|------|---------|-------|
| `docker-compose.yml` | Local development with pgAdmin | postgres:5432, pgAdmin:5050 |
| `docker-compose.test.yml` | Integration test environment | postgres:5433 (no pgAdmin) |
| `docker-compose.e2e.yml` | E2E test environment with app service placeholders | postgres:5432, apps:8080-8081,5173 |

## Seeding Data

```bash
./scripts/seed-data.sh
```

## Notes

- `docker-compose.test.yml` maps PostgreSQL to port 5433 to avoid conflict with a local postgres installation
- App service entries in `docker-compose.e2e.yml` use `image: placeholder` until real images are built in a future feature
