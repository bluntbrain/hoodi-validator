# Key ceremony

Hoodi ETH is worthless, so nothing here protects money. It protects the habit. Do it exactly as
you would on mainnet, and write down what you did, because "I have done a key ceremony" is a
sentence an infra interviewer will ask you to expand on.

## What gets created

| Artifact | Where it lives afterwards | Who may ever see it |
| --- | --- | --- |
| Mnemonic (24 words) | Paper, two copies, two places. Never typed into a networked machine. | You |
| `keystore-m_12381_3600_0_0_0-<ts>.json` | Validator client datadir (encrypted with the keystore password) | The VC process |
| Keystore password | Password manager | You, the import step |
| `deposit_data-<ts>.json` | The launchpad, once. Then it is public anyway (it is on chain). | Anyone |
| Withdrawal address | A wallet you control on Hoodi | Public |

The mnemonic can regenerate everything else. Nothing else can regenerate the mnemonic.

## Steps

1. **Prepare an offline machine.** A laptop booted from an Ubuntu live USB with Wi-Fi off, or a
   spare machine with the cable pulled. Plug in a second, empty USB stick for the output.
2. **Bring the deposit CLI across on the output stick.** Download
   [ethstaker-deposit-cli v1.3.0](https://github.com/ethstaker/ethstaker-deposit-cli/releases)
   for Linux on your normal machine, verify its SHA-256 against the release page, copy it to the
   stick, then move the stick to the offline machine.
3. **Pick the withdrawal address** on your normal machine first: a Hoodi address in a wallet
   whose seed you hold. Write it down. You will type it into the offline machine, so check it
   twice; a typo here sends the eventual withdrawal nowhere.
4. **Generate keys** on the offline machine:

   ```bash
   ./deposit new-mnemonic \
     --num_validators 1 \
     --chain hoodi \
     --withdrawal_address 0xYOUR_HOODI_ADDRESS
   ```

   For a 0x02 compounding validator (balance can grow past 32 ETH, Pectra feature) add
   `--compounding`. For a first validator, plain 0x01 is simpler to reason about.

   The CLI asks for a keystore password. Use a generated 24+ character one from your password
   manager. It then shows the 24-word mnemonic once and asks you to type it back.
5. **Write the mnemonic on paper, twice.** Store the copies in two places. Do not photograph it.
6. **Copy only `validator_keys/` to the output stick.** It contains the keystore and the deposit
   data. Shut the offline machine down; the live USB forgets everything.
7. **Fund the deposit address.** You need 32 Hoodi ETH plus a little for gas in a wallet that can
   sign a transaction on the launchpad. Sources, slowest to fastest:
   - [hoodi-faucet.pk910.de](https://hoodi-faucet.pk910.de/): proof-of-work faucet; mining in a
     browser tab for a day or two gets there.
   - [faucet.hoodi.ethpandaops.io](https://faucet.hoodi.ethpandaops.io/): small amounts, needs a
     GitHub login.
   - Ask in the EthStaker Discord `#hoodi` channel; operators there hold large balances for
     exactly this purpose. Check [hoodi.ethpandaops.io](https://hoodi.ethpandaops.io) for the
     current list; faucets change.
8. **Make the deposit** at [hoodi.launchpad.ethereum.org](https://hoodi.launchpad.ethereum.org):
   upload `deposit_data-*.json`, connect the funded wallet, and **before signing confirm the
   deposit contract is `0x00000000219ab540356cBB839Cbe05303d7705Fa`** (Hoodi uses the same
   address as mainnet; chain id must read 560048).
9. **Import the keystore on the node.** Copy `keystore-*.json` (not the deposit data, not the
   mnemonic) to `keys-import/` on the host and run `make import-keys`. The script shreds the
   copy afterwards; the VC keeps its own encrypted one.
10. **Wait.** Activation on Hoodi takes from minutes to a day depending on the queue. Watch
    the validator on [hoodi.beaconcha.in](https://hoodi.beaconcha.in) by its public key. The VC
    logs `Validator activated` and the dashboard's effectiveness panels start filling.

## Record

Fill this in and commit it (no secrets in it):

```
date:                 2026-__-__
cli version:          ethstaker-deposit-cli v1.3.0, sha256 verified: yes/no
offline method:       live USB / air-gapped machine
withdrawal creds:     0x01 / 0x02
withdrawal address:   0x...
validator pubkey:     0x...
deposit tx:           https://hoodi.etherscan.io/tx/0x...
activation epoch:     ...
mnemonic copies:      2, locations known to: me
what went wrong:      ...
```
