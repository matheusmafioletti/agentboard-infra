#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env.e2e ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env.e2e
  set +a
fi

BASE_URL="${BASE_URL:-http://localhost:${HTTP_PORT:-8080}}"
EMAIL="${E2E_STAGING_USER_EMAIL:-staging-smoke@agentboard.dev}"
PASSWORD="${E2E_STAGING_USER_PASSWORD:-StagingSmoke123!}"
TENANT_NAME="${E2E_STAGING_TENANT_NAME:-E2E Smoke Workspace}"
PROJECT_NAME="${E2E_STAGING_PROJECT_NAME:-E2E Smoke Project}"

"${ROOT_DIR}/scripts/e2e-wait.sh"

register_response="$(curl -sf -X POST "${BASE_URL}/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"E2E Smoke\",\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\",\"tenantName\":\"${TENANT_NAME}\"}" \
  2>/dev/null || true)"

if [[ -n "${register_response}" ]]; then
  echo "Registered seed user: ${EMAIL}"
  TOKEN="$(echo "${register_response}" | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])" 2>/dev/null \
    || echo "${register_response}" | sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  TENANT_ID="$(echo "${register_response}" | python3 -c "import sys,json; print(json.load(sys.stdin)['tenantId'])" 2>/dev/null \
    || echo "${register_response}" | sed -n 's/.*"tenantId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
else
  echo "Seed user already exists or register skipped: ${EMAIL}"

  login_response="$(curl -sf -X POST "${BASE_URL}/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}" 2>/dev/null || true)"

  if [[ -z "${login_response}" ]]; then
    echo "Failed to login seed user: ${EMAIL}" >&2
    exit 1
  fi

  TOKEN="$(echo "${login_response}" | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])" 2>/dev/null \
    || echo "${login_response}" | sed -n 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  TENANT_ID="$(echo "${login_response}" | python3 -c "import sys,json; print(json.load(sys.stdin)['tenantId'])" 2>/dev/null \
    || echo "${login_response}" | sed -n 's/.*"tenantId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
fi

if [[ -z "${TOKEN}" || -z "${TENANT_ID}" ]]; then
  echo "Failed to obtain token/tenantId for seed user" >&2
  exit 1
fi

projects_response="$(curl -sf -X GET "${BASE_URL}/api/v1/projects" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Tenant-Id: ${TENANT_ID}" 2>/dev/null || echo '[]')"

if echo "${projects_response}" | grep -q "${PROJECT_NAME}"; then
  echo "Seed project already exists: ${PROJECT_NAME}"
  exit 0
fi

project_response="$(curl -sf -X POST "${BASE_URL}/api/v1/projects" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Tenant-Id: ${TENANT_ID}" \
  -d "{\"name\":\"${PROJECT_NAME}\"}" 2>/dev/null || true)"

if [[ -z "${project_response}" ]]; then
  echo "Failed to create seed project: ${PROJECT_NAME}" >&2
  exit 1
fi

PROJECT_ID="$(echo "${project_response}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id', d.get('projectId','')))" 2>/dev/null \
  || echo "${project_response}" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"

if [[ -z "${PROJECT_ID}" ]]; then
  echo "Failed to create seed project" >&2
  exit 1
fi

create_work_item() {
  local title="$1"
  local type="$2"
  local parent_id="${3:-}"
  local body="{\"title\":\"${title}\",\"type\":\"${type}\",\"priority\":1"
  if [[ -n "${parent_id}" ]]; then
    body="${body},\"parentId\":\"${parent_id}\""
  fi
  body="${body}}"

  curl -sf -X POST "${BASE_URL}/api/v1/work-items?projectId=${PROJECT_ID}" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "X-Tenant-Id: ${TENANT_ID}" \
    -d "${body}" >/dev/null
}

create_work_item "E2E Smoke Feature" "FEATURE"
echo "Seed data ready: user=${EMAIL}, tenant=${TENANT_ID}, project=${PROJECT_ID}"
