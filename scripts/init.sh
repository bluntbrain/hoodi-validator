#!/usr/bin/env bash
# First-time setup. Safe to re-run: it never overwrites an existing .env or jwt.hex.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  cp .env.example .env
  echo "created .env from .env.example. Edit FEE_RECIPIENT, GRAFANA_ADMIN_PASSWORD and the Telegram values."
fi
# shellcheck disable=SC1091
set -a; . ./.env; set +a

if [ ! -f jwt.hex ]; then
  openssl rand -hex 32 | tr -d '\n' > jwt.hex
  chmod 644 jwt.hex
  echo "generated jwt.hex (shared secret between Reth and Lighthouse)"
fi

# One unprivileged uid per client, matching the `user:` lines in docker-compose.yml.
mkdir -p data/reth data/lighthouse-beacon data/lighthouse-validator data/prometheus data/grafana data/alertmanager backups keys-import
sudo chown -R 10001:10001 data/reth
sudo chown -R 10002:10002 data/lighthouse-beacon
sudo chown -R 10003:10003 data/lighthouse-validator
sudo chown -R 65534:65534 data/prometheus data/alertmanager   # nobody, the prom images' default
sudo chown -R 472:472 data/grafana                             # grafana image default uid
chmod 700 data/lighthouse-validator keys-import

# Alertmanager does not expand environment variables, so render its config here.
if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
  echo "warning: TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID is empty in .env; alerts will not be delivered"
fi
sed -e "s|\${TELEGRAM_BOT_TOKEN}|${TELEGRAM_BOT_TOKEN:-}|g" \
    -e "s|\${TELEGRAM_CHAT_ID}|${TELEGRAM_CHAT_ID:-0}|g" \
    monitoring/alertmanager/alertmanager.yml.tmpl > monitoring/alertmanager/alertmanager.yml
chmod 600 monitoring/alertmanager/alertmanager.yml

if [ "${FEE_RECIPIENT}" = "0x0000000000000000000000000000000000000000" ]; then
  echo "warning: FEE_RECIPIENT is still the zero address. Set it before importing keys."
fi

echo "ready. next: make up, then watch 'make status' until both clients are synced."
