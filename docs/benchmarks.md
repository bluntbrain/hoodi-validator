# Benchmarks

Numbers from this host. Fill in as you go; a table with real numbers is the part of this repo
an interviewer will actually read.

## Host

| Item | Value |
| --- | --- |
| Provider and model | |
| CPU | |
| RAM | |
| Disk | (model, NVMe/SATA, size) |
| Network | |
| OS and kernel | |
| Docker version | |

## Initial sync

| Component | Version | Started (UTC) | Synced (UTC) | Wall time | Peak RAM | Disk after sync |
| --- | --- | --- | --- | --- | --- | --- |
| Reth, Hoodi, `--full` | v2.8.0 | | | | | |
| Lighthouse beacon, checkpoint sync | v8.3.0 | | | | | |
| Lighthouse beacon, historical backfill complete | v8.3.0 | | | | | |

Sync log lines to record: Reth prints per-stage progress; note how long `Execution` took
versus the rest. Lighthouse prints `Downloading historical blocks` with a slot countdown.

## Steady state (measure after 7 days)

| Metric | Value | How measured |
| --- | --- | --- |
| Reth RSS | | `docker stats` |
| Lighthouse beacon RSS | | `docker stats` |
| Validator client RSS | | `docker stats` |
| Disk growth per week, Reth | | `du -sh data/reth` weekly |
| Disk growth per week, beacon | | `du -sh data/lighthouse-beacon` weekly |
| CPU average | | Grafana, Host row |
| Attester hit rate, 7 days | | Grafana, `avg_over_time(...[7d])` |
| Median inclusion distance | | Grafana |
| Block import p95 | | Grafana |

## Local RPC latency

Run from the host against Reth's HTTP port inside the compose network. Useful baseline for the
rpc-gateway project.

```bash
docker run --rm --network hoodi grafana/k6 run - <<'EOF'
import http from 'k6/http';
export const options = { vus: 20, duration: '30s' };
export default function () {
  http.post('http://reth:8545', JSON.stringify({jsonrpc:'2.0',id:1,method:'eth_blockNumber',params:[]}),
    { headers: { 'Content-Type': 'application/json' } });
}
EOF
```

| Method | VUs | p50 | p95 | p99 | req/s |
| --- | --- | --- | --- | --- | --- |
| eth_blockNumber | 20 | | | | |
| eth_getBlockByNumber(latest, true) | 20 | | | | |
| eth_getLogs (1000-block range) | 5 | | | | |
