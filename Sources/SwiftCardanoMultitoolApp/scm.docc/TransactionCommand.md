# Transaction

Build, sign, inspect, and submit Cardano transactions.

## Overview

The `transaction` command provides granular control over the full Cardano transaction lifecycle. Use it when the higher-level `send` command doesn't cover your use case — such as transactions involving smart contracts, certificates, multi-sig, or custom metadata.

```bash
scm transaction <subcommand> [options]
scm transaction --help
```

## Transaction construction

### `build`

Build a balanced transaction body. `scm` queries the current protocol parameters, selects UTxOs, calculates fees, and produces a transaction body file ready for signing.

```bash
scm transaction build \
  --tx-in <txhash>#<txix> \
  --tx-out addr1...+2000000 \
  --change-address addr1... \
  --out-file tx.body
```

**Common options:**

| Option | Description |
|--------|-------------|
| `--tx-in` | Input UTxO (`txhash#index`). Repeatable. |
| `--tx-out` | Output address+value. Repeatable. |
| `--change-address` | Address to send remaining funds after fees |
| `--certificate-file` | Include a certificate. Repeatable. |
| `--withdrawal` | Include a reward withdrawal (`stake1...+amount`). Repeatable. |
| `--metadata-json-file` | Attach JSON metadata |
| `--script-file` | Include a Plutus or native script |
| `--out-file` | Write the unsigned transaction body to this file |

### `sign`

Sign a transaction body with one or more signing keys to produce a signed transaction.

```bash
scm transaction sign \
  --tx-body-file tx.body \
  --signing-key-file payment.skey \
  --out-file tx.signed
```

Multiple `--signing-key-file` flags can be provided for transactions that require multiple witnesses (e.g., multi-sig or transactions with certificates requiring pool cold key signatures).

### `witness`

Create a transaction witness (a signature) from a signing key without fully assembling the transaction. Used in multi-party signing workflows.

```bash
scm transaction witness \
  --tx-body-file tx.body \
  --signing-key-file payment.skey \
  --out-file payment.witness
```

### `assemble`

Assemble a signed transaction from a transaction body and one or more witness files.

```bash
scm transaction assemble \
  --tx-body-file tx.body \
  --witness-file payment.witness \
  --witness-file stake.witness \
  --out-file tx.signed
```

### `submit`

Submit a signed transaction to the network.

```bash
scm transaction submit --tx-file tx.signed
```

On success, the transaction ID is printed and shown as a link to the configured blockchain explorer.

## Fee and balance utilities

### `calculate-min-fee`

Calculate the minimum fee for a transaction body given the current protocol parameters.

```bash
scm transaction calculate-min-fee \
  --tx-body-file tx.body \
  --protocol-params-file protocol-params.json \
  --tx-in-count 2 \
  --tx-out-count 2 \
  --witness-count 1
```

### `calculate-min-required-utxo`

Calculate the minimum ADA required to be included in a UTxO output (the "minUTxO" amount). This is mandatory for outputs carrying native assets.

```bash
scm transaction calculate-min-required-utxo \
  --protocol-params-file protocol-params.json \
  --tx-out "addr1...+1500000+100 d5e6bf0500378d4f0da4e8dde6becec7621cd8cbf5cbb9b87013d4cc.SNEK"
```

## Script utilities

### `hash-script-data`

Calculate the hash of Plutus script data (datums and redeemers). The hash must be included in the transaction body when spending from script addresses.

```bash
scm transaction hash-script-data \
  --script-data-file datum.json
```

## Rewards

### `rewards-withdraw`

Build a transaction that withdraws accumulated staking rewards to a payment address.

```bash
scm transaction rewards-withdraw \
  --stake-address stake1... \
  --stake-signing-key-file stake.skey \
  --payment-address addr1... \
  --payment-signing-key-file payment.skey
```

The full available rewards balance is withdrawn automatically. The wizard shows the current rewards balance before proceeding.

## Inspection

### `txid`

Compute the transaction ID (hash) from a transaction body or signed transaction file.

```bash
scm transaction txid --tx-file tx.signed
scm transaction txid --tx-body-file tx.body
```

### `view`

Display a human-readable summary of a transaction body or signed transaction.

```bash
scm transaction view --tx-file tx.signed
```

### `inspect`

Inspect the detailed CBOR structure of a transaction.

```bash
scm transaction inspect --tx-file tx.signed
```

### `validate`

Validate a transaction against the current protocol rules without submitting it.

```bash
scm transaction validate --tx-file tx.signed
```

Reports any validation errors, such as fee shortfalls, missing witnesses, or script failures.

## Typical workflow

```bash
# 1. Query protocol parameters (save once and reuse)
scm query protocol-parameters --out-file protocol-params.json

# 2. Build the transaction
scm transaction build \
  --tx-in abc123#0 \
  --tx-out addr1...+2000000 \
  --change-address addr1... \
  --out-file tx.body

# 3. Review the transaction
scm transaction view --tx-body-file tx.body

# 4. Sign
scm transaction sign \
  --tx-body-file tx.body \
  --signing-key-file payment.skey \
  --out-file tx.signed

# 5. Submit
scm transaction submit --tx-file tx.signed
```

## Notes

- For air-gapped (offline) signing workflows, use <doc:WorkOfflineCommand> instead of the individual `sign` and `submit` subcommands.
- The `build` subcommand requires access to the chain (via node socket or API) to query UTxOs and protocol parameters. The `sign` and `assemble` subcommands can run fully offline.
- All amounts are in **lovelace** (1 ADA = 1,000,000 lovelace).
