# Work Offline

Offline transaction workflows for air-gapped machines.

## Overview

The `work-offline` command implements a complete workflow for constructing and signing Cardano transactions on an air-gapped (offline) machine — a machine that has never been and never will be connected to the internet, keeping private keys completely isolated. The `offline` alias is also accepted.

```bash
scm work-offline <subcommand> [options]
scm work-offline --help
```

The workflow uses an **offline transfer file** (a JSON bundle) to safely ferry chain data from an online machine to the offline machine, and signed transactions back for submission. No private keys ever leave the offline machine.

## The offline transfer model

```
Online machine                        Offline machine
─────────────────                     ─────────────────
scm work-offline new
scm work-offline sync          →      (copy file to offline machine)

                                      scm send / scm transaction …
                                      (built + signed offline; the
                                      "submitted" tx is queued into
                                      the transfer file)

scm work-offline execute       ←      (copy file back online)
(queued tx broadcast on-chain)
```

On the offline machine, set `mode` to `offline` in your config (or let `auto` detect the missing network). Regular commands like `scm send` and `scm transaction` then read UTxOs and protocol parameters from the transfer file instead of the network, and `--submit` queues the signed transaction into the file rather than broadcasting it.

## Setup

The path to the transfer file is configured in your `scm` config under `offline_file`, defaulting to `./offline-transfer.json`. Most subcommands also accept `--in-file` to point at a different transfer file. Set `CARDANO_MULTITOOL_CONFIG` before running these commands.

## Subcommands

### new

Create a new offline transfer file.

```bash
scm work-offline new
scm work-offline new --out-file my-transfer.json
```

| Option | Description |
|--------|-------------|
| `--out-file`, `-o` | Output path for the new transfer file. |

This initializes an empty transfer bundle. Run this once before starting a new offline signing session.

### info

Display the current contents of the transfer file — protocol parameters, history, addresses with balances, attached files, and queued transactions.

```bash
scm work-offline info
```

### sync

Add UTxO data (payment address) or rewards data (stake address) to the transfer file. Run this on the **online** machine — once per address — before transferring the file to the offline machine.

```bash
scm work-offline sync --address-file owner.payment.addr
scm work-offline sync --address-file owner.stake.addr
```

| Option | Description |
|--------|-------------|
| `--address-file`, `-a` | Path to the `.addr` file to sync (payment or stake address). |
| `--in-file`, `-i` | Path to the offline transfer file. |

Sync also embeds the current protocol parameters and chain tip. After syncing, copy the transfer file to the offline machine (via USB drive, for example).

### execute

Submit a queued transaction from the transfer file. Run this on the **online** machine after the transaction was built and signed offline. The UTxO state is verified before submission.

```bash
scm work-offline execute
scm work-offline execute --tx-index 1
```

| Option | Description |
|--------|-------------|
| `--tx-index`, `-t` | Index of the queued transaction to execute (0-based, default: 0). |
| `--in-file`, `-i` | Path to the offline transfer file. |

On success the transaction is removed from the queue and recorded in the transfer file's history.

### attach

Embed a file into the transfer file (base64-encoded) — e.g. certificate or metadata files created on the online machine that are needed during offline signing.

```bash
scm work-offline attach --file stake-registration.cert
```

| Option | Description |
|--------|-------------|
| `--file`, `-f` | Path to the file to attach. |
| `--in-file`, `-i` | Path to the offline transfer file. |

### extract

Decode all embedded files from the transfer file and write them to a directory.

```bash
scm work-offline extract --out-dir ./extracted
```

| Option | Description |
|--------|-------------|
| `--out-dir`, `-o` | Directory to extract files into (default: current directory). |
| `--in-file`, `-i` | Path to the offline transfer file. |

### clear-tx

Remove all queued transactions from the transfer file, without affecting attached files or chain data.

```bash
scm work-offline clear-tx
```

### clear-history

Clear the history entries from the transfer file, leaving a single "history cleared" entry.

```bash
scm work-offline clear-history
```

### clear-files

Remove all attached files from the transfer file.

```bash
scm work-offline clear-files
```

## Full example workflow

**Online machine — initial setup:**

```bash
# 1. Initialize the transfer file
scm work-offline new

# 2. Sync UTxOs and protocol parameters into the transfer file
scm work-offline sync --address-file owner.payment.addr

# 3. Copy the transfer file to a USB drive
cp offline-transfer.json /Volumes/USB/
```

**Offline (air-gapped) machine — signing:**

```bash
# 4. Copy the transfer file from the USB drive
cp /Volumes/USB/offline-transfer.json .

# 5. Build and sign a transaction offline; --submit queues it
#    into the transfer file instead of broadcasting
scm send lovelaces \
  --amount 5000000 \
  --to-address addr1... \
  --fee-payment-address owner.payment \
  --submit

# 6. Copy the updated transfer file back to the USB drive
cp offline-transfer.json /Volumes/USB/
```

**Online machine — submission:**

```bash
# 7. Copy the signed transfer file back
cp /Volumes/USB/offline-transfer.json .

# 8. Review the queued transaction
scm work-offline info

# 9. Broadcast it
scm work-offline execute
```

## Notes

- The offline machine should never have network access. Its sole purpose is to hold keys and produce signatures.
- The transfer file is a plain JSON file. Inspect it with `scm work-offline info` at any point to understand its contents.
- The sync data embedded in the transfer file can become stale — synced UTxOs may be spent by other transactions if the transfer takes too long. `execute` verifies the UTxO state before submitting; re-sync if the signing session is delayed by many hours.
- For the highest security, generate your keys on the offline machine and never let the signing keys leave it.
