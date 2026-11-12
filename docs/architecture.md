# Architecture

One bare-metal host, seven containers, one Docker network. Only the three p2p ports and a
localhost-bound Grafana are reachable from outside the host.

```mermaid
flowchart LR
    subgraph internet[Internet]
        elp[EL peers]
        clp[CL peers]
        cp[Checkpoint sync endpoint]
    end

    subgraph host[Host: Ubuntu, Docker, network hoodi]
        reth[Reth v2.8<br/>execution client<br/>:30303 p2p, :8551 engine, :9001 metrics]
        beacon[Lighthouse beacon node v8.3<br/>:9000/:9001 p2p, :5052 HTTP, :5054 metrics<br/>--validator-monitor-auto]
        vc[Lighthouse validator client<br/>:5064 metrics<br/>keystores + slashing_protection.sqlite]
        prom[Prometheus<br/>90d retention]
        am[Alertmanager]
        graf[Grafana<br/>127.0.0.1:3000]
        ne[node-exporter]
    end

    tg[Telegram]
    you[You, over SSH tunnel]

    elp <--> reth
    clp <--> beacon
    cp -. one-time state download .-> beacon
    beacon -- Engine API, JWT --> reth
    vc -- duties, attestations, blocks --> beacon
    prom --> reth
    prom --> beacon
    prom --> vc
    prom --> ne
    prom -- alerts --> am
    am --> tg
    graf --> prom
    you --> graf
```

## Why these choices

| Choice | Reason |
| --- | --- |
| Reth + Lighthouse | Both are minority clients on mainnet, which is where new validators are asked to go. Both are Rust, which matches the rest of the plan. |
| Checkpoint sync | Hoodi is small, but syncing the beacon chain from genesis is still hours of wasted time. The finalized root is verified by hand after the first sync. |
| `--full` on Reth | A full node is enough for a validator. The archive node is a separate project (sepolia-archive). |
| `--validator-monitor-auto` | The beacon node exports per-validator attestation hit and miss counters for every key the VC attaches. That is what the Grafana effectiveness panels read. |
| Doppelganger protection on | Costs two to three epochs of attestations per restart. Prevents the one mistake that burns a validator: running the same keys twice. |
| Separate UIDs per container | Reth, beacon and VC each run as their own unprivileged user, so a bug in one cannot read another's data directory. The VC directory holds the keystores. |
| Grafana on localhost | No public dashboards until there is a reverse proxy with auth. Use an SSH tunnel. |
| Telegram alerts | Free, instant, and already where the operator is. |

## Data layout

```
data/
  reth/                     execution chain data (Storage V2)
  lighthouse-beacon/        beacon chain db, network keys
  lighthouse-validator/
    validators/             imported keystores + validator_definitions.yml
    validators/slashing_protection.sqlite    <- the file the backup script exports
  prometheus/               90 days of metrics
  grafana/                  dashboard edits made in the UI
  alertmanager/             silences and notification log
backups/                    slashing-protection exports, dated; rsync off-host
```
