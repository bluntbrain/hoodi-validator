#!/usr/bin/env bash
# Import keystore-*.json files from ./keys-import into the validator client's datadir,
# then shred the import directory. The VC is stopped during import because it holds the
# slashing-protection database open.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
set -a; . ./.env; set +a

count=$(find keys-import -maxdepth 1 -name 'keystore-*.json' | wc -l)
if [ "$count" -eq 0 ]; then
  echo "no keystore-*.json in ./keys-import. Copy them from the key-ceremony USB first (docs/key-ceremony.md)."
  exit 1
fi
echo "found $count keystore(s). You will be asked for the keystore password once (--reuse-password)."
echo "deposit_data-*.json must NOT be here; it goes to the launchpad from the offline machine."

docker compose stop validator
# Run the import as the validator uid so the files it writes are owned correctly.
docker compose run --rm --no-deps -it \
  -v "$PWD/keys-import:/keys:ro" \
  --entrypoint lighthouse validator \
  account validator import \
  --network "${NETWORK}" \
  --datadir /data \
  --directory /keys \
  --reuse-password

echo "imported. listing validators known to the VC:"
docker compose run --rm --no-deps --entrypoint lighthouse validator \
  account validator list --network "${NETWORK}" --datadir /data

echo "shredding keystores from ./keys-import (the VC now has its own encrypted copies)"
find keys-import -maxdepth 1 -name 'keystore-*.json' -exec shred -u {} \;

docker compose start validator
echo "validator client started. With doppelganger protection on, expect 2-3 epochs (~15-20 min) before the first attestation."
