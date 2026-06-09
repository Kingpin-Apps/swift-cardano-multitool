# Transaction

Build, sign, inspect, and submit Cardano transactions.

## Overview

The `transaction` command provides granular control over the full Cardano transaction lifecycle. Use it when the higher-level `send` command doesn't cover your use case — smart-contract interactions, certificates, multi-sig, governance votes, or custom metadata.

```bash
scm transaction <subcommand> [options]
scm transaction --help
```

The `tx` alias is also accepted.

Several subcommands accept either `--tx-file` (a Cardano text-envelope file) or `--cbor-hex` (a raw CBOR hex string) as input; the rest of the docs use `--tx-file` for brevity.

## Transaction construction

### `build`

Build a balanced transaction body from explicit inputs and outputs. Fees are automatically calculated.

```bash
scm transaction build \
  --tx-in <64-hex-tx-hash>#0 \
  --tx-out addr1...+2000000 \
  --change-address addr1... \
  --out-file tx.body
```

`--tx-in` validates as `txHash#index` where `txHash` is exactly 64 hex characters and `index` is a non-negative integer.

**Common options:**

| Option | Description |
|--------|-------------|
| `--tx-in` | Input UTxO (`txhash#index`). Repeatable. |
| `--tx-out` | Output as `ADDRESS VALUE`. Repeatable. |
| `--change-address` | Address where ADA in excess of the tx fee will go. |
| `--read-only-tx-in-reference` | Read-only reference input. Repeatable. |
| `--tx-in-collateral` | Collateral input. Repeatable. |
| `--required-signer` | Required signer key file path. Repeatable. |
| `--required-signer-hash` | Required signer verification key hash. Repeatable. |
| `--certificate-file` | Include a certificate. Repeatable. |
| `--withdrawal` | Include a reward withdrawal as `StakeAddress+Lovelace`. Repeatable. |
| `--mint` | Mint value in multi-asset syntax. Repeatable. |
| `--metadata-json-file` | Attach JSON metadata. Repeatable. |
| `--metadata-cbor-file` | Attach CBOR metadata. Repeatable. |
| `--vote-file` | Include a governance vote. Repeatable. |
| `--invalid-before` / `--invalid-hereafter` | Validity slot window. |
| `--witness-override` | Override the witness count used in fee estimation. |
| `--out-file`, `-o` | Output filepath of the JSON transaction body. |

For advanced Plutus script options (`--spending-tx-in-reference`, `--tx-in-script-file`, etc.), pass `--use-cardano-cli` (from `SharedTransactionOptions`) and any extra cardano-cli arguments through `--extra-args`.

### `sign`

Sign a transaction body with one or more software (`.skey`) or hardware (`.hwsfile`) signing keys.

```bash
scm transaction sign \
  --tx-file tx.body \
  --signing-keys payment.skey \
  --signing-keys stake.skey \
  --out-file tx.signed
```

| Option | Description |
|--------|-------------|
| `--tx-file`, `-t` | Path to the transaction to sign. |
| `--cbor-hex` | Alternative to `--tx-file`: raw transaction CBOR hex. |
| `--signing-keys`, `-s` | Path to a signing key. Repeat for multi-witness transactions. |
| `--out-file`, `-o` | Output path (default: `<input>.signed.tx`). |
| `--use-cardano-cli` | Delegate signing to cardano-cli instead of the native builder. |
| `--no-save` | Don't write the signed transaction to disk. |
| `--submit` | Broadcast the signed transaction immediately. |

### `witness`

Create a transaction witness (a signature) from a signing key without fully assembling the transaction. Used in multi-party signing workflows.

```bash
scm transaction witness \
  --tx-file tx.body \
  --signing-keys payment.skey \
  --out-file payment.witness
```

### `assemble`

Combine a transaction body with one or more witness files to produce a signed transaction.

```bash
scm transaction assemble \
  --tx-file tx.body \
  --witness-file payment.witness \
  --witness-file stake.witness \
  --out-file tx.signed
```

| Option | Description |
|--------|-------------|
| `--tx-file`, `-t` | Path to the transaction body. |
| `--cbor-hex` | Alternative: raw CBOR hex. |
| `--witness-file`, `-w` | Witness file. Repeat for multi-witness assembly. |
| `--out-file`, `-o` | Output path (default: `<input>.signed.tx`). |

### `submit`

Submit a signed transaction to the network.

```bash
scm transaction submit --tx-file tx.signed

# Or submit raw CBOR hex
scm transaction submit --cbor-hex 84a40081825820...
```

On success, the transaction ID is printed and linked to the configured blockchain explorer.

## Fee and balance utilities

### `calculate-min-fee`

Calculate the minimum fee for a transaction body given the current protocol parameters. The `min-fee` alias is also accepted.

```bash
scm transaction calculate-min-fee --tx-file tx.body --witness-count 1

# Include reference script size (Plutus V3 reference-script fee)
scm transaction calculate-min-fee \
  --cbor-hex 84a5... \
  --witness-count 2 \
  --reference-script-size 512
```

| Option | Description |
|--------|-------------|
| `--tx-file`, `-t` | Transaction body file. |
| `--cbor-hex` | Alternative: raw CBOR hex. |
| `--witness-count`, `-w` | Number of Shelley key witnesses that will sign. |
| `--reference-script-size` | Total size in bytes of reference scripts (default `0`). |
| `--tool` | `swift-cardano` (default) or `cardano-cli`. |
| `--json`, `-j` | Output as JSON instead of formatted text. |

### `calculate-min-required-utxo`

Calculate the minimum ADA required for a UTxO output — mandatory when outputs carry native assets. The `min-utxo` alias is also accepted.

```bash
scm transaction calculate-min-required-utxo \
  --tx-out-address addr1... \
  --tx-out-value "2000000 lovelace"

# With an attached datum
scm transaction calculate-min-required-utxo \
  --tx-out-address addr1... \
  --tx-out-value "5000000 lovelace + 100 <policyId>.<assetNameHex>" \
  --tx-out-datum-hash <hex>
```

| Option | Description |
|--------|-------------|
| `--tx-out-address` | Recipient address (bech32). |
| `--tx-out-value` | Output value in multi-asset syntax. |
| `--tx-out-datum-hash` | Datum hash (hex). |
| `--tx-out-datum-hash-file` | JSON datum file to hash. |
| `--tx-out-inline-datum-file` / `--tx-out-inline-datum-value` | Inline datum. |
| `--tx-out-reference-script-file` | Attached reference script. |
| `--tool` | `swift-cardano` or `cardano-cli`. |
| `--json`, `-j` | JSON output. |

## Script utilities

### `hash-script-data`

Calculate the blake2b-256 hash of Plutus script data (datums and redeemers). The `hsd` alias is also accepted.

```bash
scm transaction hash-script-data --script-data-file datum.json
scm transaction hash-script-data --script-data-cbor-file datum.cbor
scm transaction hash-script-data --script-data-value '{"int": 42}'
scm transaction hash-script-data --script-data-cbor-hex 1864
```

| Option | Description |
|--------|-------------|
| `--script-data-file` | JSON file in Cardano detailed-schema format. |
| `--script-data-cbor-file` | CBOR file. |
| `--script-data-value` | Inline JSON value. |
| `--script-data-cbor-hex` | Raw CBOR hex string. |
| `--tool` | `swift-cardano` or `cardano-cli`. |
| `--json`, `-j` | JSON output. |

## Rewards

### `rewards-withdraw`

Build a transaction that withdraws accumulated staking rewards. The stake address is identified by its file base name (without the `.stake.addr` suffix). All shared transaction options apply (`--fee-payment-address`, `--message`, `--submit`, …).

```bash
scm transaction rewards-withdraw \
  --stake-address owner \
  --to-address owner.payment

# Pay fees from a different address, attach a CIP-20 message
scm transaction rewards-withdraw \
  --stake-address owner.stake \
  --to-address addr1... \
  --fee-payment-address fees.payment \
  --message "Rewards for epoch 450" \
  --submit
```

| Option | Description |
|--------|-------------|
| `--stake-address`, `-s` | Stake address file base name (e.g. `owner` for `owner.stake.addr`), bech32 stake address, or `$adahandle`. |
| `--to-address`, `-t` | Where to send the withdrawn rewards. |
| `--fee-payment-address`, `-f` | Address that pays the transaction fee. Defaults to the rewards destination. |
| `--message`, `-m` | CIP-20 transaction message. Repeatable. |
| `--submit` | Broadcast the signed transaction. |

The full available rewards balance is withdrawn automatically. The wizard shows the current rewards balance before proceeding.

> **Conway-era requirement:** A DRep delegation must already exist for the stake address before rewards can be withdrawn.

## Inspection

### `txid`

Compute the transaction ID (hash) from a transaction body or signed transaction. The `id` alias is also accepted.

```bash
scm transaction txid --tx-file tx.signed
scm transaction txid --cbor-hex 84a40081...
scm transaction txid --tx-file tx.signed --json
```

### `view`

Display a human-readable summary of a transaction.

```bash
scm transaction view --tx-file tx.signed
```

### `inspect`

Inspect the detailed CBOR structure of a transaction.

```bash
scm transaction inspect --tx-file tx.signed
scm transaction inspect --tx-file tx.signed --json
```

### `validate`

Validate a transaction against current ledger rules without submitting.

```bash
scm transaction validate --tx-file tx.signed
scm transaction validate --tx-file tx.signed --json
```

Reports validation errors — fee shortfalls, missing witnesses, script failures, etc.

## Typical workflow

```bash
# 1. Build the transaction (queries chain for UTxOs + protocol params)
scm transaction build \
  --tx-in <64-hex-tx-hash>#0 \
  --tx-out addr1...+2000000 \
  --change-address addr1... \
  --out-file tx.body

# 2. Review the transaction
scm transaction view --tx-file tx.body

# 3. Sign
scm transaction sign \
  --tx-file tx.body \
  --signing-keys payment.skey \
  --out-file tx.signed

# 4. Inspect the signed transaction ID before broadcasting
scm transaction txid --tx-file tx.signed

# 5. Submit
scm transaction submit --tx-file tx.signed
```

## Notes

- For air-gapped (offline) signing workflows, use <doc:WorkOfflineCommand> instead of running `sign` and `submit` individually.
- `build` requires chain access (via node socket or API) to query UTxOs and protocol parameters. `sign`, `witness`, `assemble`, `id`, `view`, and `inspect` can run fully offline.
- All amounts are in **lovelace** (1 ADA = 1,000,000 lovelace).
