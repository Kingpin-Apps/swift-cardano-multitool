# Query

Query live data from the Cardano blockchain.

## Overview

The `query` command retrieves on-chain data from a running `cardano-node`. It covers everything from the current chain tip and epoch information through address UTxOs, protocol parameters, and the leadership schedule for stake pool operators.

```bash
scm query <subcommand> [options]
scm query --help
```

A running node (or a configured Blockfrost/Koios API key) is required for all subcommands. Set `CARDANO_MULTITOOL_CONFIG` before running queries.

## Subcommands

### `tip`

Query the current tip of the blockchain — the most recent block the node has processed.

```bash
scm query tip
```

**Output includes:**
- Slot number
- Block number
- Block hash
- Era name
- Epoch number
- Sync progress percentage (when available)

### `address`

Query the UTxO set for a Cardano address. Returns all unspent outputs, their ADA amounts, and any native assets.

```bash
scm query address --address addr1...
```

**Options:**

| Option | Description |
|--------|-------------|
| `--address` | The address to query (bech32 or hex format) |
| `--json` | Output raw JSON |

ADA handles are also supported where the handle can be resolved to an underlying address.

### `epoch`

Query information about the current or a specific epoch.

```bash
scm query epoch
scm query epoch --epoch 480
```

**Output includes:**
- Epoch number
- Start and end slot
- Number of blocks produced
- Active stake (when available)

### `era`

Query the current Cardano era (Byron, Shelley, Allegra, Mary, Alonzo, Babbage, Conway).

```bash
scm query era
```

### `protocol-parameters`

Retrieve the current protocol parameters from the chain.

```bash
scm query protocol-parameters
scm query protocol-parameters --out-file protocol-params.json
```

**Options:**

| Option | Description |
|--------|-------------|
| `--out-file` | Save the raw JSON output to a file |

Protocol parameters are required for building transactions and calculating fees.

### `stake-pool`

Query information about a specific stake pool.

```bash
scm query stake-pool --pool-id pool1...
```

**Output includes:**
- Pool ticker and name
- Current pledge and margin
- Active and live stake
- Block production statistics
- Saturation percentage
- Retirement epoch (if retiring)

### `kes-period-info`

Check the KES period status for a node's operational certificate. Critical for stake pool operators to detect and plan KES key rotations before the certificate expires.

```bash
scm query kes-period-info \
  --op-cert-file node.cert
```

**Output includes:**
- Current KES period
- KES periods remaining before expiry
- Expected expiry date
- Whether the certificate is valid

> **Warning:** If KES periods remaining reaches zero, the node will stop minting blocks. Rotate your KES keys before this happens using `scm generate key-rotation`.

### `leadership-schedule`

Query the leadership schedule for a stake pool — the slots where the pool has been (or will be) elected as the slot leader.

```bash
scm query leadership-schedule \
  --cold-verification-key-file node.vkey \
  --vrf-signing-key-file vrf.skey
```

**Options:**

| Option | Description |
|--------|-------------|
| `--cold-verification-key-file` | Pool cold verification key |
| `--vrf-signing-key-file` | Pool VRF signing key |
| `--current` | Query the current epoch schedule (default) |
| `--next` | Query the next epoch schedule |

The schedule can only be determined at the start of an epoch (~1.5 days into the epoch for the next epoch). Results include slot numbers and estimated times formatted as calendar entries.

## Notes

- Queries require the node to be fully synced with the network for accurate results. Use `scm query tip` to check sync status first.
- Some queries (like `leadership-schedule`) require both the running node socket and specific private key material. Keep your VRF signing key accessible on the block-producing server.
- If Blockfrost or Koios is configured, some queries (`address`, `tip`, `epoch`) can fall back to those APIs when the local node socket is unavailable.
