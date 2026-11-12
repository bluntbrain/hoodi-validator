#!/usr/bin/env bash
# Import a slashing-protection interchange file into the validator client.
# Use it when moving these keys to a new machine or after rebuilding data/lighthouse-validator.
#
# Order matters: import the slashing-protection file BEFORE the keystores are allowed to sign.
# Importing the file only adds history; Lighthouse refuses to sign anything older than it.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
set -a; . ./.env; set +a

file="${1:-}"
if [ -z "$file" ] || [ ! -f "$file" ]; then
  echo "usage: make restore FILE=backups/slashing-protection-hoodi-<stamp>.json"
  exit 1
fi

echo "about to import $(basename "$file") into the VC datadir for network ${NETWORK}."
echo "if the keys were running elsewhere after this export was taken, STOP and wait at least"
echo "two finalized epochs (~15 min) before starting the VC here. Continue? [y/N]"
read -r ans; [ "$ans" = "y" ] || exit 1

docker compose stop validator
trap 'docker compose start validator' EXIT

docker compose run --rm --no-deps \
  -v "$PWD/$(dirname "$file"):/restore:ro" \
  --entrypoint lighthouse validator \
  account validator slashing-protection import "/restore/$(basename "$file")" \
  --network "${NETWORK}" --datadir /data

echo "imported. Doppelganger protection will hold duties for 2-3 epochs after start."
