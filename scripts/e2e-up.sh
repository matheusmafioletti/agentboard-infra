#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f .env.e2e ]]; then
  cp .env.e2e.example .env.e2e
  echo "Created .env.e2e from .env.e2e.example"
fi

set -a
# shellcheck disable=SC1091
source .env.e2e
set +a

docker compose -f docker-compose.e2e.yml --env-file .env.e2e up -d

"${ROOT_DIR}/scripts/e2e-wait.sh"

echo "E2E stack ready at http://localhost:${HTTP_PORT:-8080}"
