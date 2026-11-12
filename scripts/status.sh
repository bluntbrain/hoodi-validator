#!/usr/bin/env bash
# One-screen health summary. Uses the containers' own HTTP APIs, nothing published on the host.
set -euo pipefail
cd "$(dirname "$0")/.."

bn() { docker compose exec -T beacon wget -qO- "http://127.0.0.1:5052$1" 2>/dev/null || echo '{}'; }
el() { docker compose exec -T reth wget -qO- --header='Content-Type: application/json' \
        --post-data="{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$1\",\"params\":[]}" http://127.0.0.1:8545 2>/dev/null || echo '{}'; }
j() { python3 -c "import sys,json; d=json.load(sys.stdin); print(eval(sys.argv[1]))" "$1" 2>/dev/null || echo "?"; }

echo "== containers"
docker compose ps --format 'table {{.Name}}\t{{.Status}}'

echo; echo "== execution (reth)"
syncing=$(el eth_syncing | j "d.get('result')")
peers=$(el net_peerCount | j "int(d.get('result','0x0'),16)")
block=$(el eth_blockNumber | j "int(d.get('result','0x0'),16)")
echo "syncing: $syncing   peers: $peers   head block: $block"

echo; echo "== consensus (lighthouse beacon)"
bn /eth/v1/node/syncing | j "'head slot: %s   sync distance: %s   is_syncing: %s   el_offline: %s' % (d['data']['head_slot'], d['data']['sync_distance'], d['data']['is_syncing'], d['data'].get('el_offline'))"
bn /eth/v1/node/peer_count | j "'peers connected: %s' % d['data']['connected']"
bn /eth/v1/beacon/states/head/finality_checkpoints | j "'finalized epoch: %s   justified epoch: %s' % (d['data']['finalized']['epoch'], d['data']['current_justified']['epoch'])"

echo; echo "== validator client (last 15 log lines)"
docker compose logs --no-log-prefix --tail=15 validator 2>/dev/null | cut -c1-160

echo; echo "== disk"
df -h . | tail -1
