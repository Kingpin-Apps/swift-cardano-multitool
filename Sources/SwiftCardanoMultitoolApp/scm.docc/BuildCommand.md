# Build

Build Cardano payment and stake addresses from cryptographic keys.

## Overview

The `build` command derives human-readable Cardano addresses from verification keys. It supports both enterprise payment addresses (payment key only) and base addresses (payment + stake key).

```bash
scm build <subcommand> [options]
scm build --help
```

## Subcommands

### `payment-address`

Build a payment address from a payment verification key. Optionally combine with a stake verification key to create a base address (which can receive staking rewards).

```bash
scm build payment-address \
  --payment-verification-key-file payment.vkey \
  --stake-verification-key-file stake.vkey \
  --out-file payment.addr
```

**Options:**

| Option | Description |
|--------|-------------|
| `--payment-verification-key-file` | Path to the payment verification key (`.vkey`) |
| `--stake-verification-key-file` | Path to the stake verification key (optional — omit for an enterprise address) |
| `--out-file` | Write the resulting address to this file |
| `--network` | Override the network from your config (`mainnet`, `preprod`, `preview`) |

**Address types produced:**

| Keys provided | Address type |
|---------------|-------------|
| Payment key only | Enterprise address (no staking rewards) |
| Payment + Stake keys | Base address (receives staking rewards) |

### `stake-address`

Build a stake (rewards) address from a stake verification key. The stake address is used to collect rewards and delegate to a pool.

```bash
scm build stake-address \
  --stake-verification-key-file stake.vkey \
  --out-file stake.addr
```

**Options:**

| Option | Description |
|--------|-------------|
| `--stake-verification-key-file` | Path to the stake verification key (`.vkey`) |
| `--out-file` | Write the resulting stake address to this file |
| `--network` | Override the network from your config |

## Notes

- Key files are expected in the standard Cardano `TextEnvelope` JSON format produced by `cardano-cli` and `scm generate`.
- The network encoded in the address must match the network your node and config are set to. Sending to an address on the wrong network will result in a failed transaction.
- To generate the underlying key pairs before building addresses, see <doc:GenerateCommand>.
