# DNS — matheusmafioletti.com

Configure estes registros no painel do registrador apontando para o **IP público da VPS Contabo** (não o IP Tailscale `100.x.x.x`).

| Host | Tipo | Valor |
|------|------|-------|
| `@` (matheusmafioletti.com) | A | IP público da VPS |
| `www` | A ou CNAME → `@` | conforme preferência do portfólio |
| `agentboard` | A | mesmo IP público da VPS |

## Validação

Aguarde a propagação (TTL) e confirme:

```bash
dig +short agentboard.matheusmafioletti.com
dig +short matheusmafioletti.com
```

Ambos devem retornar o IP público da VPS antes de executar o Certbot.

## URLs de produção

| Serviço | URL |
|---------|-----|
| AgentBoard | `https://agentboard.matheusmafioletti.com` |
| Portfólio | `https://matheusmafioletti.com` |

GitHub variable `DEMO_PUBLIC_URL` (repos `agentboard-infra` e `agentboard-web`): `https://agentboard.matheusmafioletti.com`
