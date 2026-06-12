# Send

Transfer ADA and native assets.

## Overview

The `send` command builds and submits transactions to transfer funds from one address to another. It wraps the full transaction pipeline (build → sign → submit) in a single interactive workflow.

```bash
scm send <subcommand> [options]
scm send --help
```

A valid configuration with a running node (or configured API provider) is required to query UTxOs and submit the transaction.

All `send` subcommands compose with `SharedTransactionOptions`, so flags like `--message`, `--metadata-json`, `--utxo-filter`, `--use-cardano-cli`, `--no-save`, and `--submit` are available on every one.

## Subcommands

### lovelaces

Send a specific amount of lovelace (1 ADA = 1,000,000 lovelace) to a recipient address.

```bash
scm send lovelaces \
  --amount 5000000 \
  --to-address addr1... \
  --fee-payment-address owner.payment

# Send the protocol-defined minimum UTXO instead of an exact amount
scm send lovelaces \
  --amount min \
  --to-address recipient.payment \
  --fee-payment-address owner.payment
```

**Options:**

| Option | Description |
|--------|-------------|
| `--amount` | Lovelace amount to send, or `min` for the protocol minimum UTXO. |
| `--to-address`, `-t` | Recipient address (bech32, file stem like `recipient.payment`, key hash, or `$adahandle`). |
| `--fee-payment-address`, `-f` | Sender's address — used to find UTxOs and pay fees. Same input forms as `--to-address`. |
| `--message`, `-m` | Optional transaction message (CIP-20). Repeatable. |
| `--submit` | Broadcast the signed transaction to the chain. |

Native assets at the source are not affected — only lovelace is sent. Change (remaining lovelace and any assets) is returned to the source address.

### assets

Send specific native assets (fungible tokens or NFTs) to a recipient address. The lovelace amount bundled with the assets defaults to the protocol minimum UTXO if not specified.

```bash
scm send assets \
  --policy-id d5e6bf0500378d4f0da4e8dde6becec7621cd8cbf5cbb9b87013d4cc \
  --asset-name-hex 534e454b \
  --amount 100 \
  --to-address addr1... \
  --fee-payment-address owner.payment

# Sweep every unit of a specific asset
scm send assets \
  --policy-id <56-char-hex> \
  --asset-name-hex <hex> \
  --amount all \
  --to-address recipient.payment \
  --fee-payment-address owner.payment
```

**Options:**

| Option | Description |
|--------|-------------|
| `--policy-id` | Policy ID of the asset (56-char hex). |
| `--asset-name-hex` | Asset name in hex. |
| `--amount` | Number of asset units to send, `all`, or `min`. |
| `--lovelace-amount` | Lovelaces to bundle with the asset (default: protocol minimum). |
| `--to-address`, `-t` | Recipient address. |
| `--fee-payment-address`, `-f` | Source address. |
| `--message`, `-m` | Optional transaction message (CIP-20). Repeatable. |

### all

Send the entire balance from an address. Useful for consolidating funds or moving a wallet's full contents.

```bash
# Send all ADA and all assets
scm send all \
  --to-address addr1... \
  --fee-payment-address owner.payment

# Send only the native assets (with minimum ADA), keep remaining ADA at source
scm send all \
  --send-mode assets-only \
  --to-address recipient.payment \
  --fee-payment-address owner.payment

# Send all ADA, keep native assets at source (with minimum ADA)
scm send all \
  --send-mode lovelaces-only \
  --to-address addr1... \
  --fee-payment-address owner.payment
```

**Options:**

| Option | Description |
|--------|-------------|
| `--send-mode` | `all` (default), `assets-only`, or `lovelaces-only`. |
| `--to-address`, `-t` | Recipient address. |
| `--fee-payment-address`, `-f` | Source address. |
| `--message`, `-m` | Optional transaction message (CIP-20). Repeatable. |

`all` and `lovelaces-only` require the SwiftCardano builder and are not compatible with `--use-cardano-cli`.

## Transaction messages

All `send` subcommands accept one or more CIP-20 plaintext messages, stored on-chain in the transaction metadata and visible in blockchain explorers:

```bash
scm send lovelaces \
  --to-address addr1... \
  --amount 2000000 \
  --fee-payment-address owner.payment \
  --message "Payment for invoice #42"
```

Pass `--encryption basic --passphrase <pass>` to encrypt the message payload before it goes on-chain.

## Notes

- Fees are calculated automatically based on the current protocol parameters. The exact fee is shown in the confirmation prompt before submission.
- If the sending address contains multiple UTxOs, the coin selection algorithm picks the optimal set to minimize fees. Constrain selection with `--utxo-filter`, `--utxo-limit`, `--skip-utxo-with-asset`, or `--only-utxo-with-asset`.
- For more complex transaction requirements (multiple recipients, smart contract interactions, certificates), use `scm transaction build` directly.
- All lovelace amounts are in **lovelace**, not ADA. To send 5 ADA, pass `--amount 5000000`.
- Signing keys are resolved automatically from the same on-disk location as the source address — there is no `--signing-key-file` flag.
