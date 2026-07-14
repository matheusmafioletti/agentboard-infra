#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8080}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-60}"
SLEEP_SECONDS="${SLEEP_SECONDS:-5}"

health_paths=(
  "/"
)

wait_for_http() {
  local url="$1"
  local attempt=1
  while [[ $attempt -le $MAX_ATTEMPTS ]]; do
    local status
    status="$(curl -so /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")"
    if [[ "$status" =~ ^[23] ]]; then
      echo "Ready: $url (HTTP $status)"
      return 0
    fi
    echo "Waiting for $url ($attempt/$MAX_ATTEMPTS, HTTP $status)..."
    sleep "$SLEEP_SECONDS"
    attempt=$((attempt + 1))
  done
  return 1
}

wait_for_auth() {
  local url="${BASE_URL}/auth/login"
  local attempt=1
  while [[ $attempt -le $MAX_ATTEMPTS ]]; do
    local status
    status="$(curl -so /dev/null -w "%{http_code}" \
      -X POST "$url" \
      -H "Content-Type: application/json" \
      -d '{"email":"healthcheck@agentboard.dev","password":"invalid"}' 2>/dev/null || echo "000")"
    if [[ "$status" =~ ^(400|401|403|422)$ ]]; then
      echo "Ready: $url (HTTP $status)"
      return 0
    fi
    echo "Waiting for $url ($attempt/$MAX_ATTEMPTS, HTTP $status)..."
    sleep "$SLEEP_SECONDS"
    attempt=$((attempt + 1))
  done
  return 1
}

wait_for_board() {
  local url="${BASE_URL}/api/v1/projects"
  local attempt=1
  while [[ $attempt -le $MAX_ATTEMPTS ]]; do
    local status
    status="$(curl -so /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")"
    if [[ "$status" =~ ^(401|403)$ ]]; then
      echo "Ready: $url (HTTP $status)"
      return 0
    fi
    echo "Waiting for $url ($attempt/$MAX_ATTEMPTS, HTTP $status)..."
    sleep "$SLEEP_SECONDS"
    attempt=$((attempt + 1))
  done
  return 1
}

for path in "${health_paths[@]}"; do
  wait_for_http "${BASE_URL}${path}" || exit 1
done

wait_for_auth || exit 1
wait_for_board || exit 1

echo "E2E stack ready at ${BASE_URL}"
