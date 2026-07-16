#!/usr/bin/env bash
set -euo pipefail

DEPLOY_DIR="${DEPLOY_DIR:?DEPLOY_DIR required}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.prod.yml}"
ENV_FILE="${ENV_FILE:-.env.prod}"
TAGS_FILE="${TAGS_FILE:-.image-tags}"
ROLLBACK_FILE="${TAGS_FILE}.rollback"

cd "$DEPLOY_DIR"

if [[ ! -f "$ROLLBACK_FILE" ]]; then
  echo "No rollback snapshot found at $ROLLBACK_FILE" >&2
  exit 1
fi

cp "$ROLLBACK_FILE" "$TAGS_FILE"
chmod 600 "$TAGS_FILE"

set -a
# shellcheck source=/dev/null
source "$TAGS_FILE"
set +a

compose() {
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

DEPLOY_MODE="${DEPLOY_MODE:-backend}"

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
echo "Rollback complete — restored tags from $ROLLBACK_FILE"
