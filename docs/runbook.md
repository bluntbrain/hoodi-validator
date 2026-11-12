# Runbook

Short answers to "something is wrong, what do I do". Every alert in
`monitoring/prometheus/rules/chain.yml` points at a section here.

## Daily glance

```bash
make status          # sync, peers, finality, last VC log lines, disk
```

Healthy looks like: `is_syncing: False`, `sync_distance: 0`, EL `syncing: False`, 30+ CL peers,
10+ EL peers, finalized epoch two behind the head epoch, and VC logs showing
`Successfully published attestations` every 6.4 minutes.

## First sync

1. `make init && make up`.
2. Reth syncs Hoodi from genesis. Expect a few hours on NVMe; `make logs` shows stage progress
   (`Headers`, `Bodies`, `Execution`, ...). Record the time in `docs/benchmarks.md`.
3. Lighthouse downloads a finalized state from `CHECKPOINT_SYNC_URL` and is "synced" within a
   minute, then backfills history in the background. **Verify the checkpoint** the way you would
   on mainnet: compare the finalized root the node reports against a second source.

   ```bash
   docker compose exec beacon wget -qO- http://127.0.0.1:5052/eth/v1/beacon/states/finalized/finality_checkpoints
   # compare 'finalized.root' with https://hoodi.beaconcha.in/epoch/<epoch> or a second checkpoint provider
   ```

   If they disagree, stop, wipe `data/lighthouse-beacon`, and sync from the other endpoint.
4. The VC starts with no keys and idles. That is fine. Import keys only after both clients are
   synced and the dashboard shows green.

## Alerts

### TargetDown
`docker compose ps`. A container in `Restarting` is crash-looping: `docker compose logs --tail=100 <svc>`.
Common causes: wrong file ownership under `data/` (re-run `make init`), a corrupted database
after a disk-full event (see Disk), an image tag that no longer exists (CI checks this weekly).

### RethLowPeers / BeaconLowPeers
Almost always the firewall or NAT. From another machine: `nc -vz <host> 30303` and `nc -vzu <host> 9000`.
On the host: `sudo ufw status`. Behind a home router, forward 30303 tcp/udp, 9000 tcp/udp, 9001 udp.

### RethNotAdvancing / BeaconHeadStale
The two clients have stopped talking. Check the Engine API link:
`docker compose logs --tail=50 beacon | grep -i -E "execution|engine|jwt"`. A JWT mismatch shows as
`401`; fix by making sure both containers mount the same `jwt.hex` and restart both.
If Reth is still importing blocks but Lighthouse is stale, Lighthouse lost peers or finality
stalled network-wide (check hoodi.beaconcha.in before blaming yourself).

### BeaconNotSynced
If the sync distance is small and shrinking, wait. If it is growing, the EL is behind: Lighthouse
cannot validate blocks whose payloads Reth has not executed. Check `make status` EL `syncing`.

### ValidatorClientNoBeacon
The VC cannot reach `http://beacon:5052` or the beacon reports unsynced. `docker compose restart validator`
after the beacon is healthy. Doppelganger protection then holds duties for 2-3 epochs; that is expected.

### ValidatorAttestationsMissing
Work down this list; the first that is false is the cause.
1. Both clients synced (`make status`).
2. Clock within 0.5 s (`chronyc tracking`).
3. VC logs show duties being fetched (`Published attestation` lines, or `Awaiting activation`).
4. Peers above thresholds.
5. Host not swapping or CPU-starved (`docker stats`).
One or two misses a day on Hoodi is normal noise. Write a postmortem if you miss more than an epoch's worth.

### ValidatorBalanceDropping
Same list as above. Note that doppelganger restarts and the activation period both show as flat,
not falling, balance. A falling balance means the chain is penalizing you: offline from its view.

### DiskWillFillIn4Days / DiskLow
```bash
sudo du -sh data/* | sort -h
docker system df
```
Order of things to reclaim: old Docker images (`docker image prune`), Prometheus retention
(`--storage.tsdb.retention.time` in compose), container logs (capped at 250 MB each by the
logging block). Reth data only grows; if the disk is simply too small, that is a new disk, not a cleanup.

### ClockDrift
`chronyc tracking` and `chronyc sources -v`. If `System time` offset is above 0.1 s, `sudo chronyc makestep`.
A VM with a bad host clock needs a different host.

### HighMemory
`docker stats --no-stream`. Reth on Hoodi should sit under 8 GB and Lighthouse under 4 GB. Anything
far above that is worth a GitHub issue upstream with the version and a heap profile.

## Routine operations

### Upgrade clients
Hoodi gets forks weeks before mainnet, so upgrades here are time-critical. Lighthouse and Reth
release notes name the Hoodi deadline.
```bash
make backup                      # slashing protection export first, always
# edit RETH_IMAGE / LIGHTHOUSE_IMAGE in .env
make upgrade                     # pull + recreate
make status                      # synced again within a minute or two
```
Upgrade the beacon and VC together; they are the same image. Downtime: about one epoch plus
doppelganger's 2-3 epochs.

### Restart the host
`sudo reboot`. The systemd unit brings the stack back. Expect 3-4 epochs of missed duties total.

### Move the validator to a new machine
This is where people get slashed. The rule: the keys must never be live in two places at once.
1. On the old host: `make backup`, then `docker compose stop validator`, then
   `rm -rf data/lighthouse-validator/validators` (yes, delete it; the mnemonic can recreate it).
2. Wait two finalized epochs (~15 min). Confirm on beaconcha.in that the validator went offline.
3. On the new host: `make init && make up`, wait for sync, `make restore FILE=<the export>`,
   then `make import-keys` with keystores regenerated from the mnemonic (`deposit existing-mnemonic`).

### Exit the validator
Hoodi exits are a free rehearsal for the real thing.
```bash
docker compose run --rm --no-deps --entrypoint lighthouse validator \
  account validator exit --keystore /data/validators/<pubkey>/keystore.json \
  --beacon-node http://beacon:5052 --network hoodi --datadir /data
```

## Incident log
Every alert that pages you and every unplanned restart gets an entry in `docs/incidents/`, using
the template. Not because Hoodi matters, but because the writing is the skill.
