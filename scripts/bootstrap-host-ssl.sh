#!/usr/bin/env bash
set -euo pipefail

AGENTBOARD_DOMAIN="${AGENTBOARD_DOMAIN:-agentboard.matheusmafioletti.com}"
PORTFOLIO_DOMAIN="${PORTFOLIO_DOMAIN:-matheusmafioletti.com}"
PORTFOLIO_WWW="${PORTFOLIO_WWW:-www.matheusmafioletti.com}"
DEPLOY_DIR="${DEPLOY_DIR:-/opt/agentboard}"
DOCKER_HTTP_PORT="${DOCKER_HTTP_PORT:-8080}"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo bash scripts/bootstrap-host-ssl.sh" >&2
  exit 1
fi

echo "==> Installing nginx and certbot"
apt-get update
apt-get install -y nginx certbot python3-certbot-nginx

echo "==> Ensuring Docker stack is not binding public port 80"
if [[ -d "$DEPLOY_DIR" ]]; then
  cd "$DEPLOY_DIR"
  if docker compose --env-file .env.prod -f docker-compose.prod.yml ps nginx 2>/dev/null | grep -q "0.0.0.0:80"; then
    echo "Stopping docker nginx — redeploy with 127.0.0.1 bind first" >&2
    docker compose --env-file .env.prod -f docker-compose.prod.yml stop nginx || true
  fi
fi

echo "==> Installing nginx site configs"
install -d /var/www/portfolio
install -m 644 "$DEPLOY_DIR/docs/host-nginx-agentboard.conf.example" /etc/nginx/sites-available/agentboard
install -m 644 "$DEPLOY_DIR/docs/host-nginx-portfolio.conf.example" /etc/nginx/sites-available/portfolio

ln -sf /etc/nginx/sites-available/agentboard /etc/nginx/sites-enabled/agentboard
ln -sf /etc/nginx/sites-available/portfolio /etc/nginx/sites-enabled/portfolio
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl enable nginx
systemctl reload nginx

echo "==> Verifying Docker nginx on 127.0.0.1:${DOCKER_HTTP_PORT}"
if ! curl -sf -o /dev/null -H "Host: ${AGENTBOARD_DOMAIN}" "http://127.0.0.1:${DOCKER_HTTP_PORT}/"; then
  echo "WARNING: Docker stack not responding on 127.0.0.1:${DOCKER_HTTP_PORT}." >&2
  echo "Run deploy (full) first, then re-run certbot manually." >&2
fi

echo "==> Requesting Let's Encrypt certificates"
certbot --nginx \
  -d "${AGENTBOARD_DOMAIN}" \
  -d "${PORTFOLIO_DOMAIN}" \
  -d "${PORTFOLIO_WWW}" \
  --non-interactive --agree-tos --register-unsafely-without-email || {
    echo "Certbot failed — confirm DNS propagation (see docs/DNS.md)" >&2
    exit 1
  }

echo "==> Enabling certbot renewal timer"
systemctl enable certbot.timer
systemctl start certbot.timer

echo "Done. Validate:"
echo "  curl -I https://${AGENTBOARD_DOMAIN}"
echo "  sudo certbot renew --dry-run"
