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
│                              ┌──────────▼──────────┐             │
│                              │  board-service      │             │
│                              │  Spring Boot        │             │
│                              │  :8081              │             │
│                              └──────────┬──────────┘             │
│                                         │ JDBC                    │
│                              ┌──────────▼──────────┐             │
│                              │   PostgreSQL 16      │             │
│                              │   :5432              │             │
│                              └─────────────────────┘             │
└─────────────────────────────────────────────────────────────────┘
```

## Repository Responsibilities

| Repository | Technology | Port | Responsibility |
|------------|-----------|------|----------------|
| `agentboard-backend/commons` | Java 21 | — | Shared security, multitenancy, exceptions |
| `agentboard-backend/auth-service` | Spring Boot 3.2 | 8080 | User registration, login, JWT issuance |
| `agentboard-backend/board-service` | Spring Boot 3.2 | 8081 | Work items, board lifecycle, MCP HTTP API |
| `agentboard-mcp-server` | Node.js 20 / TypeScript | stdio | MCP tool bridge between AI clients and board-service |
| `agentboard-web` | React 18 / Vite 5 | 5173 | Kanban board UI for human users |
| `agentboard-infra` | Docker Compose | — | Local and test environment infrastructure |

## Data Flow

1. **Human user** → `agentboard-web` (React) → `auth-service` (login/register)
2. **Human user** → `agentboard-web` → `board-service` (create/move work items)
3. **AI agent** (Claude Code / Cursor) → `agentboard-mcp-server` (MCP stdio) → `board-service` (SpecKit tools, work item API)

## Tenant Isolation

Every request carries a `tenantId`. Cross-tenant data access is prohibited at the service layer.
