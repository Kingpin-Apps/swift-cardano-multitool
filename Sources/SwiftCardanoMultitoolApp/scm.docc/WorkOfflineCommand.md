# Work Offline

Offline transaction workflows for air-gapped machines.

## Overview

The `work-offline` command implements a complete workflow for constructing and signing Cardano transactions on an air-gapped (offline) machine — a machine that has never been and never will be connected to the internet, keeping private keys completely isolated.

```bash
scm work-offline <subcommand> [options]
scm work-offline --help
```

The workflow uses an **offline transfer file** (a JSON bundle) to safely ferry chain data from an online machine to the offline machine, and signed transactions back for submission. No private keys ever leave the offline machine.

## The offline transfer model

```
Online machine                      Offline machine
─────────────────                   ─────────────────
scm work-offline new         →      (transfer file created)
scm work-offline sync        →      (UTxOs, params added)
                                    (copy file to offline)
                             ←      scm work-offline execute
                                    (tx signed offline)
                                    (copy file to online)
scm transaction submit       ←      (tx submitted online)
```

## Setup

The path to the transfer file is configured in your `scm` config under `offline_file`, defaulting to `./offline-transfer.json`. Set `CARDANO_MULTITOOL_CONFIG` before running these commands.

## Subcommands

### `new`

Create a new offline transfer file.

```bash
scm work-offline new
```

This initializes an empty transfer bundle at the path configured in `offline_file`. Run this once before starting a new offline signing session.

### `info`

Display the current contents of the transfer file — pending transactions, attached files, and synced chain data.

```bash
scm work-offline info
```

### `sync`

Sync the transfer file with live chain data from a running node. Run this on the **online** machine before transferring the file to the offline machine.

```bash
scm work-offline sync \
  --address addr1... \
  --address addr1...
```

Sync fetches and embeds:
- UTxO sets for the specified addresses
- Current protocol parameters
- Current tip (slot, epoch, era)

After syncing, copy the transfer file to the offline machine (via USB drive or QR code).

### `execute`

Build and sign a transaction on the **offline** machine using the chain data embedded in the transfer file.

```bash
scm work-offline execute
```

The wizard walks through:
1. Selecting the transaction type (send lovelaces, send assets, certificate, etc.)
2. Constructing the transaction from embedded UTxOs and protocol parameters
3. Collecting signing key files from the local (air-gapped) filesystem
4. Signing the transaction — entirely offline
5. Embedding the signed transaction in the transfer file

After executing, copy the transfer file back to the online machine.

### `attach`

Attach additional files to the transfer file (e.g. unsigned certificate files or metadata JSON files created on the online machine that need to be signed offline).

```bash
scm work-offline attach --file stake-registration.cert
```

Attached files are embedded in the transfer file and can be accessed on the offline machine during `execute`.

### `extract`

Extract files that have been embedded in the transfer file to the local filesystem.

```bash
scm work-offline extract --out-dir ./extracted
```

Useful for extracting the signed transaction from the transfer file on the online machine before submitting it.

### `clear-tx`

Remove all pending (unsigned or signed) transactions from the transfer file, without affecting attached files or chain data.

```bash
scm work-offline clear-tx
```

### `clear-history`

Clear the transaction history log from the transfer file.

```bash
scm work-offline clear-history
```

### `clear-files`

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
scm work-offline sync --address addr1qx...

# 3. Copy the transfer file to a USB drive
cp offline-transfer.json /Volumes/USB/
```

**Offline (air-gapped) machine — signing:**

```bash
# 4. Copy the transfer file from the USB drive
cp /Volumes/USB/offline-transfer.json .

# 5. Build and sign the transaction offline
scm work-offline execute

# 6. Copy the updated transfer file back to the USB drive
cp offline-transfer.json /Volumes/USB/
```

**Online machine — submission:**

```bash
# 7. Copy the signed transfer file back
cp /Volumes/USB/offline-transfer.json .

# 8. Extract the signed transaction
scm work-offline extract --out-dir .

# 9. Submit the signed transaction
scm transaction submit --tx-file tx.signed
```

## Notes

- The offline machine should never have network access. Its sole purpose is to hold keys and produce signatures.
- The transfer file is a plain JSON file. Inspect it with `scm work-offline info` at any point to understand its contents.
- The sync data embedded in the transfer file has a time-to-live — synced UTxOs may become stale if the transfer takes too long. Re-sync if the signing session is delayed by many hours.
- For the highest security, generate your keys on the offline machine and never let the signing keys leave it.
