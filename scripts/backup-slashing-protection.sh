#!/usr/bin/env bash
# Export the slashing-protection database (EIP-3076 interchange JSON) to ./backups.
#
# Why stop the VC: Lighthouse opens slashing_protection.sqlite exclusively. Exporting while
# it runs can produce an inconsistent file, and an inconsistent file is worse than none.
# The stop costs one, sometimes two, attestations. Run it from the systemd timer
# (deploy/slashing-backup.timer) once a day at a quiet hour and rsync ./backups off-host.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
set -a; . ./.env; set +a

stamp=$(date -u +%Y%m%dT%H%M%SZ)
out="backups/slashing-protection-${NETWORK}-${stamp}.json"

docker compose stop validator
trap 'docker compose start validator' EXIT

docker compose run --rm --no-deps \
  -v "$PWD/backups:/backups" \
  --entrypoint lighthouse validator \
  account validator slashing-protection export "/backups/$(basename "$out")" \
  --network "${NETWORK}" --datadir /data

chmod 600 "$out"
python3 - "$out" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
vals = d.get("data", [])
print(f"exported {len(vals)} validator(s), interchange format v{d['metadata']['interchange_format_version']}, genesis root {d['metadata']['genesis_validators_root'][:12]}...")
for v in vals:
    print(f"  {v['pubkey'][:14]}...  blocks:{len(v.get('signed_blocks', []))}  attestations:{len(v.get('signed_attestations', []))}")
PY

# keep the last 30 exports locally
find backups -maxdepth 1 -name 'slashing-protection-*.json' -printf '%T@ %p\n' | sort -rn | tail -n +31 | cut -d' ' -f2- | xargs -r rm -f
echo "wrote $out"
