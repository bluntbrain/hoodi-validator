# hoodi-validator

An Ethereum validator on the Hoodi testnet, run against my own execution and consensus nodes,
with monitoring, alerting, slashing-protection backups and a documented key ceremony.

**Status:** not yet live. This section becomes a table (chain, role, since, uptime, Grafana
link) updated by CI once the node is up.

| | |
| --- | --- |
| Network | Hoodi (chain id 560048), Ethereum's long-lived testnet for validators |
| Execution client | [Reth](https://github.com/paradigmxyz/reth) v2.8.0, full node |
| Consensus client | [Lighthouse](https://github.com/sigp/lighthouse) v8.3.0, beacon node + validator client |
| Monitoring | Prometheus, Grafana, Alertmanager to Telegram, node-exporter |
| Host | one bare-metal box, Ubuntu 24.04, Docker Compose |

## Why this exists

Running a validator is the smallest piece of blockchain infrastructure that has every property
of the large pieces: a stateful process that must stay in sync, peers and ports to keep healthy,
a key that must never be used twice, upgrades on a deadline set by the network, and a number
(attestation effectiveness) that says in public how well you are doing. Hoodi is where you learn
that without losing money. Everything here is done the way it would be done on mainnet.

## Quick start

```bash
# on a fresh Ubuntu 24.04 host with 16 GB RAM and 500 GB NVMe or better
git clone https://github.com/bluntbrain/hoodi-validator && cd hoodi-validator
./deploy/host-setup.sh          # docker, chrony, ufw, sysctl; log out and in afterwards
make init                       # .env, jwt secret, data dirs, alertmanager config
# edit .env: FEE_RECIPIENT, GRAFANA_ADMIN_PASSWORD, TELEGRAM_*
make up
make status                     # repeat until both clients report synced
```

Then follow [docs/key-ceremony.md](docs/key-ceremony.md) on an offline machine, copy the
keystore to `keys-import/`, and:

```bash
make import-keys
```

Grafana is on `127.0.0.1:3000` of the host; reach it with `ssh -L 3000:127.0.0.1:3000 user@host`.
The home dashboard is [Hoodi validator](monitoring/grafana/dashboards/hoodi-validator.json):
attester hit rate, head and target correctness, inclusion distance, balance, then CL, EL and host.

## What is in here

```
docker-compose.yml        reth, beacon, validator, prometheus, alertmanager, grafana, node-exporter
.env.example              pinned image versions and the handful of settings you change
Makefile                  init / up / status / import-keys / backup / restore / upgrade / check
scripts/                  the Makefile targets, each a short bash file you can read
monitoring/prometheus/    scrape config and alert rules (sync, peers, head stale, missed attestations, disk, clock)
monitoring/alertmanager/  Telegram routing; rendered from the .tmpl by make init
monitoring/grafana/       provisioned datasource and the dashboard
deploy/                   host-setup.sh, systemd unit for the stack, daily slashing-protection backup timer
docs/architecture.md      diagram and the reasoning behind each choice
docs/key-ceremony.md      offline key generation, funding, deposit, import, and the record to keep
docs/runbook.md           what to do for every alert, upgrades, host moves, exits
docs/benchmarks.md        sync times, resource use, RPC latency, filled in from this host
docs/incidents/           dated postmortems
.github/workflows/ci.yml  compose config, yamllint, shellcheck, promtool, amtool, dashboard json, image tags exist
```

## Design notes

- **Checkpoint sync, then verify.** The beacon node starts from a finalized state fetched over
  HTTPS. The runbook has the step that compares the finalized root against a second source
  before keys are imported. Skipping that step on mainnet is how you end up on the wrong chain.
- **Doppelganger protection stays on.** It costs two to three epochs of duties after each restart.
  That is the price of never signing from two places at once.
- **Slashing-protection exports are the backup that matters.** Keystores can be regenerated from
  the mnemonic; the signing history cannot. `make backup` exports it daily via a systemd timer,
  and `make restore` imports it before keys are allowed to sign on a new host.
- **Nothing public but p2p.** JSON-RPC, the beacon API and metrics are on the Docker network
  only. Grafana binds to localhost. A reverse proxy with auth is a separate decision.
- **One unprivileged uid per client.** A bug in Reth cannot read the validator's keystores.
- **Pinned versions, checked weekly.** Hoodi forks before mainnet, so stale clients drop off the
  chain. CI confirms every pinned image still exists and the configs still parse.

## Upstream references

Not forked, but read closely and worth your time:
[eth-docker](https://github.com/eth-educators/eth-docker) (the full-featured version of this
idea), [sigp/lighthouse-metrics](https://github.com/sigp/lighthouse-metrics) (the official
Lighthouse dashboards; import them next to this one),
[reth's Grafana dashboards](https://github.com/paradigmxyz/reth/tree/main/etc/grafana/dashboards),
the [Lighthouse book](https://lighthouse-book.sigmaprime.io/) and [reth.rs](https://reth.rs/).

## License

MIT.
