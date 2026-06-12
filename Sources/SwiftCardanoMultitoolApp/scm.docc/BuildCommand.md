# Build

Build Cardano payment and stake addresses from cryptographic keys.

## Overview

The `build` command derives human-readable Cardano addresses from verification key files. It supports both enterprise payment addresses (payment key only) and base addresses (payment + stake key).

```bash
scm build <subcommand> [options]
scm build --help
```

Keys can be located two ways: by **address name** (preferred — `--address-name owner` resolves `owner.payment.vkey` / `owner.stake.vkey` in the current directory) or by explicit paths to the verification key files.

## Subcommands

### payment-address

Build a payment address from a payment verification key. When a stake verification key is also available, a base address (which can receive staking rewards) is produced. The `payment` alias is also accepted.

```bash
# By address name — resolves owner.payment.vkey / owner.stake.vkey
scm build payment-address --address-name owner

# By explicit key file paths
scm build payment-address \
  --payment-vkey payment.vkey \
  --stake-vkey stake.vkey
```

**Options:**

| Option | Description |
|--------|-------------|
| `--address-name`, `-a` | Base name — key files are resolved as `<name>.payment.vkey` and `<name>.stake.vkey` in the current directory. |
| `--payment-vkey`, `-p` | Explicit path to the payment verification key file. |
| `--stake-vkey`, `-s` | Explicit path to the stake verification key file (omit for an enterprise address). |
| `--tool`, `-t` | `swift-cardano` (default) or `cardano-cli` — which backend to use. |

**Address types produced:**

| Keys provided | Address type |
|---------------|-------------|
| Payment key only | Enterprise address (no staking rewards) |
| Payment + Stake keys | Base address (receives staking rewards) |

### stake-address

Build a stake (rewards) address from a stake verification key. The stake address is used to collect rewards and delegate to a pool. The `stake` alias is also accepted.

```bash
scm build stake-address --address-name owner

# Or by explicit key file path
scm build stake-address --stake-vkey stake.vkey
```

**Options:**

| Option | Description |
|--------|-------------|
| `--address-name`, `-a` | Base name — resolves `<name>.stake.vkey` in the current directory. |
| `--stake-vkey`, `-s` | Explicit path to the stake verification key file. |
| `--tool`, `-t` | `swift-cardano` (default) or `cardano-cli`. |

## Notes

- Key files are expected in the standard Cardano `TextEnvelope` JSON format produced by `cardano-cli` and `scm generate`.
- The network encoded in the address is taken from your active configuration — make sure `CARDANO_MULTITOOL_CONFIG` points to the right network before building.
- To generate the underlying key pairs before building addresses, see <doc:GenerateCommand>.
