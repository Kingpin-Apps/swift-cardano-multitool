# Query

Query live data from the Cardano blockchain.

## Overview

The `query` command retrieves on-chain data from a running `cardano-node` or a configured API provider. It covers everything from the current chain tip and epoch information through address UTxOs, protocol parameters, governance state, and the leadership schedule for stake pool operators.

```bash
scm query <subcommand> [options]
scm query --help
```

A running node (or a configured Blockfrost/Koios API key) is required for all subcommands. Set `CARDANO_MULTITOOL_CONFIG` before running queries.

## Chain state

### tip

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

### epoch

Get the current epoch.

```bash
scm query epoch
```

### era

Get the current Cardano era (Byron, Shelley, Allegra, Mary, Alonzo, Babbage, Conway).

```bash
scm query era
```

### protocol-parameters

Retrieve the current protocol parameters from the chain.

```bash
scm query protocol-parameters
scm query protocol-parameters --file-name protocol-params.json
```

**Options:**

| Option | Description |
|--------|-------------|
| `--file-name`, `-f` | The file to save the protocol parameters to. |
| `--save` / `--no-save` | Whether to save the output to a file (default: `--save`). |

Protocol parameters are required for building transactions and calculating fees.

## Addresses and assets

### address

Query the UTxO set for a Cardano address. Returns all unspent outputs, their ADA amounts, and any native assets.

```bash
scm query address addr1...
```

The address is passed as a positional argument. ADA handles are also supported where the handle can be resolved to an underlying address.

### asset-meta

Query off-chain metadata for a native asset from the Cardano Token Registry. The `assetmeta` alias is also accepted.

```bash
scm query asset-meta <56-120-hex-subject>
scm query asset-meta myPolicy.MYTOK.asset
```

The positional argument is an asset subject (56–120 hex chars: policy ID + asset name hex) or a path to a `.asset` JSON sidecar file produced by `scm asset`.

## Stake pools

### stake-pool

Query information about a specific stake pool. The `pool` alias is also accepted.

```bash
scm query stake-pool --pool-operator pool1...
scm query stake-pool --pool-name myPool
```

**Options:**

| Option | Description |
|--------|-------------|
| `--pool-operator`, `-o` | The pool: bech32 (`pool1...`), hex hash, or `.node.vkey` file. |
| `--pool-name`, `-p` | Pool name — resolves `<poolName>.vrf.skey` and `<poolName>.pool.id-bech` in the current directory. |
| `--pool-json`, `-j` | Path to the `pool.json` file. |

### kes-period-info

Check the KES period status for a node's operational certificate. Critical for stake pool operators to detect and plan KES key rotations before the certificate expires.

```bash
scm query kes-period-info --pool-name myPool
scm query kes-period-info --op-cert myPool.node-012.opcert
```

**Options:**

| Option | Description |
|--------|-------------|
| `--pool-name`, `-p` | Pool name — finds the latest `<poolName>.node-XXX.opcert`. |
| `--pool-json`, `-j` | Path to the `pool.json` file. |
| `--pool-operator`, `-o` | The pool operator: bech32, hex hash, or `.node.vkey` file. |
| `--op-cert` | Explicit path to the OpCert file. |
| `--which-period`, `-w` | `current` (default) or `next`. |

> **Warning:** If KES periods remaining reaches zero, the node will stop minting blocks. Rotate your KES keys before this happens using `scm generate key-rotation`.

### leadership-schedule

Query the leadership schedule for a stake pool — the slots where the pool has been (or will be) elected as the slot leader. Requires an online cardano-cli context (running node) and may take several minutes.

```bash
scm query leadership-schedule --pool-name myPool
scm query leadership-schedule --pool-json myPool.pool.json --which-epoch next
scm query leadership-schedule --pool-name myPool --export-ics --maintenance-schedule
```

**Options:**

| Option | Description |
|--------|-------------|
| `--pool-name`, `-p` | Pool name — resolves `<poolName>.vrf.skey` and `<poolName>.pool.id-bech`. |
| `--pool-json`, `-j` | Path to the `pool.json` file. |
| `--pool-operator`, `-o` | The pool operator: bech32, hex hash, or `.node.vkey` file. |
| `--vrf-skey`, `-v` | Explicit path to the VRF signing key file (`.vrf.skey`). |
| `--which-epoch`, `-w` | `current` (default) or `next`. |
| `--export-ics`, `-e` | Export the schedule to an iCal (`.ics`) file. |
| `--maintenance-schedule`, `-m` | Show the two largest gaps between scheduled blocks. |
| `--output-file` | Path for the `.ics` export (default: `leadership-schedule.ics`). |

The next epoch's schedule can only be determined ~1.5 days into the current epoch.

## Governance

### drep

Query on-chain registration, anchor metadata, and CIP-100 signatures for a DRep.

```bash
scm query drep drep1...
scm query drep myDRep.drep.vkey
```

The positional argument accepts bech32 (`drep1…`, `drep_script1…`, `drep_always_abstain`, `drep_always_no_confidence`), a hex hash, or a `.drep` / `.drep.id` / `.drep.vkey` file.

### committee-member

Query on-chain state for a constitutional-committee member by cold or hot credential. The `committee` and `cc` aliases are also accepted.

```bash
scm query committee-member cc_cold1...
scm query committee-member myCC.cc-hot.vkey
```

### governance-action

Query on-chain state for a governance action. The `gov-action` and `ga` aliases are also accepted.

```bash
scm query governance-action gov_action1...
scm query governance-action <txHash>#0
```

### vote

Query votes on governance actions, filtered by voter, action ID, or action type. The `votes` alias is also accepted.

```bash
scm query vote --voter drep1...
scm query vote --action-id gov_action1...
scm query vote --action-type treasury-withdrawal --all
```

**Options:**

| Option | Description |
|--------|-------------|
| `--voter` | Filter to one voter: bech32 (`drep1…`, `pool1…`, `cc_cold1…`, `cc_hot1…`, `stake1…`), 56-char hex hash, or a key file. |
| `--action-id` | Filter to one governance action: bech32, hex, or `<txHash>#<index>`. |
| `--action-type` | Filter by type: `parameter-change`, `hard-fork`, `treasury-withdrawal`, `no-confidence`, `update-committee`, `new-constitution`, `info`. |
| `--all` | Include historical (expired/dropped/enacted) actions, not just active ones. |

### calidus-key

Query on-chain CIP-88 Calidus pool-key registrations via Koios.

```bash
scm query calidus-key all
scm query calidus-key pool1...
scm query calidus-key calidus1...
scm query calidus-key myPool
```

The positional filter accepts `all`, a pool or calidus bech32 ID, a 64-char hex public key, a file path, or a bare name resolved against `<name>.calidus.id`, `<name>.calidus.vkey`, or `<name>.node.vkey` in the working directory.

## Notes

- Queries require the node to be fully synced with the network for accurate results. Use `scm query tip` to check sync status first.
- Some queries (like `leadership-schedule`) require both the running node socket and specific private key material. Keep your VRF signing key accessible on the block-producing server.
- If Blockfrost or Koios is configured, many queries can fall back to those APIs when the local node socket is unavailable.
