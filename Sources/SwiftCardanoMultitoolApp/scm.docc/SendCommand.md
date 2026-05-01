# Send

Transfer ADA and native assets.

## Overview

The `send` command builds and submits transactions to transfer funds from one address to another. It wraps the full transaction pipeline (build → sign → submit) in a single interactive workflow.

```bash
scm send <subcommand> [options]
scm send --help
```

A valid configuration with a running node (or configured API provider) is required to query UTxOs and submit the transaction.

## Subcommands

### `lovelaces`

Send a specific amount of lovelace (1 ADA = 1,000,000 lovelace) to a recipient address.

```bash
scm send lovelaces \
  --from-address addr1... \
  --payment-signing-key-file payment.skey \
  --to-address addr1... \
  --amount 5000000
```

**Options:**

| Option | Description |
|--------|-------------|
| `--from-address` | Sender's address (used to find UTxOs) |
| `--payment-signing-key-file` | Signing key for the sender's address |
| `--to-address` | Recipient address (bech32) |
| `--amount` | Amount to send in lovelace |
| `--message` | Optional transaction message (CIP-20) |

The tool automatically calculates fees, selects UTxOs (coin selection), and builds a balanced transaction. You are shown a summary for confirmation before submission.

### `assets`

Send specific native assets (fungible tokens or NFTs) to a recipient address. The minimum ADA required to carry the assets is calculated automatically.

```bash
scm send assets \
  --from-address addr1... \
  --payment-signing-key-file payment.skey \
  --to-address addr1... \
  --asset "d5e6bf0500378d4f0da4e8dde6becec7621cd8cbf5cbb9b87013d4cc.SNEK" \
  --asset-amount 100
```

**Options:**

| Option | Description |
|--------|-------------|
| `--from-address` | Sender's address |
| `--payment-signing-key-file` | Signing key for the sender's address |
| `--to-address` | Recipient address |
| `--asset` | Asset ID in `policyId.assetName` format |
| `--asset-amount` | Number of asset units to send |
| `--ada-amount` | ADA to include alongside the assets (defaults to minimum required) |
| `--message` | Optional transaction message (CIP-20) |

### `all`

Send the entire balance (all ADA and native assets) from an address to a recipient. Useful for consolidating funds or moving a wallet's full contents.

```bash
scm send all \
  --from-address addr1... \
  --payment-signing-key-file payment.skey \
  --to-address addr1...
```

**Options:**

| Option | Description |
|--------|-------------|
| `--from-address` | Source address |
  `--payment-signing-key-file` | Signing key for the source address |
| `--to-address` | Recipient address |
| `--message` | Optional transaction message (CIP-20) |

The tool sweeps all UTxOs from the source address. Transaction fees are deducted from the ADA balance. If the address holds native assets, the minimum ADA required to carry those assets is also retained.

## Transaction messages

All `send` subcommands support attaching a text message to the transaction via CIP-20:

```bash
scm send lovelaces \
  --to-address addr1... \
  --amount 2000000 \
  --message "Payment for invoice #42"
```

Messages are stored on-chain in the transaction metadata and visible in blockchain explorers.

## Notes

- Fees are calculated automatically based on the current protocol parameters. The exact fee is shown in the confirmation prompt before submission.
- If the sending address contains multiple UTxOs, the coin selection algorithm picks the optimal set to minimize fees.
- For more complex transaction requirements (multiple recipients, smart contract interactions, certificates), use `scm transaction build` directly.
- ADA amounts in `--amount` flags are always in **lovelace**. To send 5 ADA, pass `--amount 5000000`.
