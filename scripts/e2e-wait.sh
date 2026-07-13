#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8080}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-60}"
SLEEP_SECONDS="${SLEEP_SECONDS:-5}"

health_paths=(
  "/auth/actuator/health"
  "/actuator/health"
  "/auth/health"
)

wait_for_url() {
  local url="$1"
  local attempt=1
  while [[ $attempt -le $MAX_ATTEMPTS ]]; do
    if curl -sf "$url" >/dev/null 2>&1; then
      echo "Ready: $url"
      return 0
    fi
    echo "Waiting for $url ($attempt/$MAX_ATTEMPTS)..."
    sleep "$SLEEP_SECONDS"
    attempt=$((attempt + 1))
  done
  return 1
}

for path in "${health_paths[@]}"; do
  if wait_for_url "${BASE_URL}${path}"; then
    wait_for_url "${BASE_URL}/"
    exit 0
  fi
done

echo "E2E stack did not become healthy within timeout" >&2
exit 1
