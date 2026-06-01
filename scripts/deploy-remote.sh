#!/usr/bin/env bash
set -euo pipefail

DEPLOY_DIR="${DEPLOY_DIR:-$(pwd)}"
DEPLOY_MODE="${DEPLOY_MODE:?DEPLOY_MODE required (backend|web|full)}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.prod.yml}"
ENV_FILE="${ENV_FILE:-.env.prod}"
TAGS_FILE="${TAGS_FILE:-.image-tags}"

required_vars=(
  GHCR_REGISTRY
  POSTGRES_PASSWORD
  JWT_SECRET
  DEMO_PUBLIC_URL
)
for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    echo "Missing required environment variable: $var" >&2
    exit 1
  fi
done

cd "$DEPLOY_DIR"

git pull --ff-only

umask 077
cat > "$ENV_FILE" <<EOF
GHCR_REGISTRY=${GHCR_REGISTRY}
POSTGRES_USER=${POSTGRES_USER:-agentboard}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=${POSTGRES_DB:-agentboard}
JWT_SECRET=${JWT_SECRET}
CORS_ALLOWED_ORIGINS=${DEMO_PUBLIC_URL}
WEBSOCKET_ALLOWED_ORIGINS=${DEMO_PUBLIC_URL}
INVITE_BASE_URL=${DEMO_PUBLIC_URL}
HTTP_PORT=${HTTP_PORT:-8080}
EOF
chmod 600 "$ENV_FILE"

declare -A tags=(
  [AUTH_IMAGE_TAG]=latest
  [BOARD_IMAGE_TAG]=latest
  [API_DOCS_IMAGE_TAG]=latest
  [WEB_IMAGE_TAG]=latest
)

if [[ -f "$TAGS_FILE" ]]; then
  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" =~ ^# ]] && continue
    tags[$key]="$value"
  done < "$TAGS_FILE"
fi

merge_tag() {
  local key=$1
  local value=${2:-}
  if [[ -n "$value" ]]; then
    tags[$key]="$value"
  fi
}

merge_tag AUTH_IMAGE_TAG "${AUTH_IMAGE_TAG:-}"
merge_tag BOARD_IMAGE_TAG "${BOARD_IMAGE_TAG:-}"
merge_tag API_DOCS_IMAGE_TAG "${API_DOCS_IMAGE_TAG:-}"
merge_tag WEB_IMAGE_TAG "${WEB_IMAGE_TAG:-}"

tags_tmp="$(mktemp)"
trap 'rm -f "$tags_tmp"' EXIT
{
  echo "AUTH_IMAGE_TAG=${tags[AUTH_IMAGE_TAG]}"
  echo "BOARD_IMAGE_TAG=${tags[BOARD_IMAGE_TAG]}"
  echo "API_DOCS_IMAGE_TAG=${tags[API_DOCS_IMAGE_TAG]}"
  echo "WEB_IMAGE_TAG=${tags[WEB_IMAGE_TAG]}"
} > "$tags_tmp"
mv "$tags_tmp" "$TAGS_FILE"
chmod 600 "$TAGS_FILE"
trap - EXIT

set -a
# shellcheck source=/dev/null
source "$TAGS_FILE"
set +a

compose() {
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

case "$DEPLOY_MODE" in
  backend)
    compose pull agentboard-auth agentboard-board agentboard-api-docs
    compose up -d agentboard-auth agentboard-board agentboard-api-docs nginx
    compose restart nginx
    ;;
  web)
    compose pull agentboard-web
    compose up -d agentboard-web nginx
    compose restart nginx
    ;;
  full)
    compose pull
    compose up -d
    compose restart nginx
    ;;
  *)
    echo "Invalid DEPLOY_MODE: $DEPLOY_MODE" >&2
    exit 1
    ;;
esac

compose ps
