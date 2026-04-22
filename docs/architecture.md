# AgentBoard Architecture

## Service Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        AgentBoard Platform                       │
│                                                                  │
│  ┌──────────────────┐        ┌────────────────────┐             │
│  │  agentboard-web  │        │   Claude Code /     │             │
│  │  React 18 + Vite │        │   Cursor AI Client  │             │
│  │  :5173           │        │                     │             │
│  └────────┬─────────┘        └──────────┬──────────┘             │
│           │ HTTP                        │ MCP (stdio)             │
│           │                             │                         │
│  ┌────────▼─────────┐        ┌──────────▼──────────┐             │
│  │  auth-service    │        │  agentboard-mcp-    │             │
│  │  Spring Boot     │        │  server             │             │
│  │  :8080           │        │  Node.js / TS       │             │
│  └──────────────────┘        └──────────┬──────────┘             │
│                                         │ HTTP                    │
│  ┌───────────────────┐       ┌──────────▼──────────┐             │
│  │  board-service    │◄──────┤  agent-service      │             │
│  │  Spring Boot      │ HTTP  │  Spring Boot         │             │
│  │  :8081            │       │  :8082               │             │
│  └────────┬──────────┘       └──────────┬──────────┘             │
│           │                             │                         │
│           └──────────────┬──────────────┘                         │
│                          │ JDBC                                   │
│                 ┌────────▼────────┐                               │
│                 │   PostgreSQL 16  │                               │
│                 │   :5432          │                               │
│                 └─────────────────┘                               │
└─────────────────────────────────────────────────────────────────┘
```

## Repository Responsibilities

| Repository | Technology | Port | Responsibility |
|------------|-----------|------|----------------|
| `agentboard-backend/commons` | Java 21 | — | Shared security, multitenancy, exceptions |
| `agentboard-backend/auth-service` | Spring Boot 3.2 | 8080 | User registration, login, JWT issuance |
| `agentboard-backend/board-service` | Spring Boot 3.2 | 8081 | Board and card lifecycle, Kanban state machine |
| `agentboard-backend/agent-service` | Spring Boot 3.2 | 8082 | Task queue, AI agent work assignment |
| `agentboard-mcp-server` | Node.js 20 / TypeScript | stdio | MCP tool bridge between AI clients and agent-service |
| `agentboard-web` | React 18 / Vite 5 | 5173 | Kanban board UI for human users |
| `agentboard-api-tests` | Java 21 / RestAssured | — | Black-box HTTP contract tests |
| `agentboard-e2e` | Playwright 1.44 | — | Full end-to-end browser tests |
| `agentboard-infra` | Docker Compose | — | Local and test environment infrastructure |

## Data Flow

1. **Human user** → `agentboard-web` (React) → `auth-service` (login/register)
2. **Human user** → `agentboard-web` → `board-service` (create/move cards)
3. **board-service** → `agent-service` (enqueue task when card enters agent queue)
4. **AI agent** (Claude Code / Cursor) → `agentboard-mcp-server` (MCP stdio) → `agent-service` (poll + complete tasks)
5. **agent-service** → `board-service` (update card state after task completion)

## Tenant Isolation

Every request carries a `tenantId`. Cross-tenant data access is prohibited at the service layer.
