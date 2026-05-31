# GitHub Actions — secrets e variables (deploy centralizado)

Deploy na VPS é responsabilidade exclusiva do repositório **agentboard-infra** (`deploy.yml`).
Backend e web apenas publicam imagens no GHCR e disparam `repository_dispatch`.

## agentboard-infra

### Variables (Settings → Actions → Variables)

| Nome | Exemplo | Uso |
|------|---------|-----|
| `VPS_HOST` | `100.x.x.x` | IP Tailscale da VPS |
| `VPS_USER` | `deploy` | Usuário SSH |
| `VPS_DEPLOY_PATH` | `/opt/agentboard` | Diretório do clone do infra |
| `DEMO_PUBLIC_URL` | `https://demo.example.com` | CORS, WebSocket, invites no `.env.prod` |
| `GHCR_REGISTRY` | `ghcr.io/matheusmafioletti` | Prefixo das imagens no compose |

### Secrets (Settings → Actions → Secrets)

| Nome | Uso |
|------|-----|
| `TS_OAUTH_CLIENT_ID` | Tailscale OAuth (runners CI) |
| `TS_OAUTH_SECRET` | Tailscale OAuth |
| `VPS_SSH_KEY` | Chave privada SSH (sem passphrase) |
| `JWT_SECRET` | Auth/board (mín. 32 caracteres) |
| `POSTGRES_PASSWORD` | Banco Postgres em produção |

## agentboard-backend e agentboard-web

### Secrets

| Nome | Uso |
|------|-----|
| `INFRA_DEPLOY_PAT` | PAT com **Actions: Read and write** no repo `agentboard-infra` |

Criar PAT (fine-grained recomendado):

1. GitHub → Settings → Developer settings → Fine-grained tokens
2. Repository access: apenas `agentboard-infra`
3. Permissions: Actions → Read and write
4. Copiar token → Secret `INFRA_DEPLOY_PAT` em **backend** e **web**

### Variables (apenas agentboard-web)

| Nome | Uso |
|------|-----|
| `DEMO_PUBLIC_URL` | Build-args Vite no Dockerfile (`VITE_*_SERVICE_URL`) |

### Remover após validar deploy (backend e web)

Não são mais usados nos workflows:

- `TS_OAUTH_CLIENT_ID`, `TS_OAUTH_SECRET`
- `VPS_SSH_KEY`
- Variables `VPS_HOST`, `VPS_USER`, `VPS_DEPLOY_PATH` (backend)

## Rollout checklist

1. Configurar variables/secrets no repo **infra** (tabela acima).
2. Criar `INFRA_DEPLOY_PAT` e adicionar em **backend** e **web**.
3. Na VPS: clone em `/opt/agentboard`, `docker login ghcr.io` (usuário `deploy`).
4. Merge/push do `deploy.yml` no `main` do infra.
5. **Actions → Deploy → Run workflow** → modo `full` (valida SSH, `.env.prod`, compose).
6. Merge em `main` no backend → dispatch `deploy-backend`.
7. Merge em `main` no web → dispatch `deploy-web`.
8. Remover secrets/variables obsoletos dos repos backend/web.

## VPS bootstrap (sem `.env.prod` manual)

```bash
sudo mkdir -p /opt/agentboard
sudo chown deploy:deploy /opt/agentboard
cd /opt/agentboard
git clone https://github.com/matheusmafioletti/agentboard-infra.git .
echo "$GITHUB_PAT" | docker login ghcr.io -u SEU_USUARIO --password-stdin
```

O primeiro `workflow_dispatch` (Deploy → full) gera `.env.prod` e `.image-tags` na VPS.
