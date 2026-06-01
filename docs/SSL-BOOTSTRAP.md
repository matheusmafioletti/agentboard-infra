# SSL bootstrap (one-time VPS setup)

After the Docker stack deploys with `127.0.0.1:8080` binding, the site is **not public** until host nginx + Certbot are configured.

## Quick setup (SSH as deploy, with sudo password)

```bash
cd /opt/agentboard
git pull
sudo bash scripts/bootstrap-host-ssl.sh
```

This installs host nginx + certbot, configures vhosts for AgentBoard and portfolio placeholder, and requests Let's Encrypt certificates.

## Enable automatic SSL bootstrap from GitHub Actions

```bash
cd /opt/agentboard
sudo cp docs/deploy-sudoers.example /etc/sudoers.d/agentboard-deploy
sudo chmod 440 /etc/sudoers.d/agentboard-deploy
sudo visudo -cf /etc/sudoers.d/agentboard-deploy
```

Then re-run **Deploy → full** in GitHub Actions.

## Validate

```bash
curl -I https://agentboard.matheusmafioletti.com
sudo certbot renew --dry-run
curl -H "Host: agentboard.matheusmafioletti.com" http://127.0.0.1:8080/
```

## DNS prerequisite

See [DNS.md](DNS.md). Both domains must resolve to the VPS public IP before running Certbot.
