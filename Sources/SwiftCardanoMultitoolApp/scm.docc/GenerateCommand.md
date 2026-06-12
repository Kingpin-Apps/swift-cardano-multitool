# Generate

Generate cryptographic keys, addresses, and pool metadata.

## Overview

The `generate` command creates all the cryptographic material needed to run a Cardano stake pool or manage a wallet — node cold/KES/VRF keys, operational certificates, payment and stake addresses, minting policies, and pool registration metadata.

```bash
scm generate <subcommand> [options]
scm generate --help
```

The `gen` alias is also accepted.

> **Security:** Private keys (`.skey` files) should be stored securely and never shared. Use `scm protect encrypt` to encrypt sensitive key files at rest, or pass `--key-gen-method enc` to generate them already encrypted.

## Shared conventions

Most generate subcommands derive every output filename from a single `--name` (or `--pool-name`) flag — there is no separate `--out-file` per artifact. For example, `scm generate node-cold-keys --pool-name myPool` writes `myPool.cold.vkey`, `myPool.cold.skey`, and `myPool.cold.counter` into the current working directory.

Common shared options:

| Option | Description |
|--------|-------------|
| `--name`, `-n` / `--pool-name`, `-p` | Base name for the generated files. |
| `--key-gen-method`, `-k` | `cli`, `enc`, `hw`, `hw_multi`, `mnemonics`, or hybrid variants (depending on subcommand). |
| `--tool`, `-t` | `swift-cardano` (default) or `cardano-cli` — which backend to use. |

If both flags are omitted, the subcommand falls back to its interactive wizard.

## Node key generation

### node-cold-keys

Generate a stake pool cold key pair plus an operational-certificate issue counter. The cold key signs operational certificates and pool registration certificates.

```bash
scm generate node-cold-keys \
  --pool-name myPool \
  --key-gen-method cli

# Encrypted signing key (prompts for a password)
scm generate node-cold-keys \
  --pool-name myPool \
  --key-gen-method enc

# Hardware-wallet-backed cold key
scm generate node-cold-keys \
  --pool-name myPool \
  --key-gen-method hw \
  --cold-key-index 0
```

**Options:**

| Option | Description |
|--------|-------------|
| `--pool-name`, `-p` | Base name. Outputs `<name>.cold.vkey`, `<name>.cold.skey` (or `.cold.hwsfile` for `hw`), and `<name>.cold.counter`. |
| `--key-gen-method`, `-k` | `cli`, `enc`, or `hw`. |
| `--cold-key-index`, `-c` | HD index used for hardware wallet derivation (path `1853H/1815H/0H/<index>H`). Defaults to `0`. |
| `--tool`, `-t` | `cardano-cli` or `swift-cardano`. |

> **Best practice:** Generate cold keys on an air-gapped machine and never move the signing key to an internet-connected device.

### node-kes-keys

Generate a Key Evolving Signature (KES) key pair. KES keys sign blocks and must be rotated every `maxKESEvolutions` slots (typically ~90 days).

```bash
scm generate node-kes-keys --pool-name myPool --key-gen-method cli
```

| Option | Description |
|--------|-------------|
| `--pool-name`, `-p` | Outputs `<name>.kes-XXX.vkey` / `<name>.kes-XXX.skey` (the `XXX` suffix is the KES period). |
| `--key-gen-method`, `-k` | `cli` or `enc`. |
| `--tool`, `-t` | Backend to use. |

### node-vrf-keys

Generate a Verifiable Random Function (VRF) key pair. VRF keys prove a pool's right to mint a block in a given slot.

```bash
scm generate node-vrf-keys --pool-name myPool --key-gen-method cli
```

| Option | Description |
|--------|-------------|
| `--pool-name`, `-p` | Outputs `<name>.vrf.vkey` and `<name>.vrf.skey`. |
| `--key-gen-method`, `-k` | `cli` or `enc`. |
| `--tool`, `-t` | Backend to use. |

### node-operational-certificate

Issue a new operational certificate that authorizes the current KES key to sign blocks on behalf of the cold key. Run this each time KES keys are rotated.

```bash
scm generate node-operational-certificate --pool-name myPool

# Reuse a specific counter value instead of reading <pool>.cold.counter
scm generate node-operational-certificate \
  --pool-name myPool \
  --use-op-cert-counter 12
```

| Option | Description |
|--------|-------------|
| `--pool-name`, `-p` | Reads `<name>.cold.skey/vkey` and `<name>.cold.counter`; writes `<name>.node-XXX.opcert`. |
| `--use-op-cert-counter`, `-u` | Override the counter file with an explicit value. |
| `--tool`, `-t` | Backend to use. |

A node will not accept an operational certificate whose counter is below the one already on-chain.

## Address generation

### payment-address-only

Generate a payment key pair and derive an enterprise (payment-only) address. This address cannot receive staking rewards.

```bash
# Library-generated keys
scm generate payment-address-only \
  --address-name owner \
  --key-gen-method cli

# Encrypted .skey
scm generate payment-address-only \
  --address-name owner \
  --key-gen-method enc

# Mnemonic-derived key (CIP-1852)
scm generate payment-address-only \
  --address-name owner \
  --key-gen-method mnemonics \
  --sub-account 0 \
  --index 0
```

| Option | Description |
|--------|-------------|
| `--address-name`, `-a` | Outputs `<name>.payment.vkey`, `<name>.payment.skey` (or `.payment.hwsfile`), and `<name>.payment.addr`. |
| `--key-gen-method`, `-k` | `cli`, `enc`, `hw`, `hw_multi`, or `mnemonics`. |
| `--sub-account`, `-s` | CIP-1852 account index — required for `hw`, `hw_multi`, `mnemonics`. Defaults to `0`. |
| `--index`, `-i` | Leaf index used with `--sub-account`. Defaults to `0`. |
| `--mnemonics`, `-m` | Existing BIP-39 mnemonic. Omit to generate a fresh one. |
| `--language`, `-l` | Mnemonic language (default `english`). |
| `--word-count`, `-w` | Mnemonic length: `12`, `15`, `18`, `21`, or `24` (default). |
| `--tool`, `-t` | Backend to use. |

### payment-and-stake-address

Generate both payment and stake key pairs, then derive a base address (which receives staking rewards) and a stake address (for reward collection and delegation).

```bash
scm generate payment-and-stake-address \
  --address-name owner \
  --key-gen-method cli

# Mnemonic-derived hybrid wallet
scm generate payment-and-stake-address \
  --address-name owner \
  --key-gen-method mnemonics \
  --sub-account 0 \
  --index 0
```

| Option | Description |
|--------|-------------|
| `--address-name`, `-a` | Outputs `<name>.payment.{vkey,skey,addr}` and `<name>.stake.{vkey,skey,addr}`. |
| `--key-gen-method`, `-k` | `cli`, `enc`, `hw`, `hw_multi`, `mnemonics`, or `hybrid` / `hybrid_multi` / `hybrid_enc` / `hybrid_multi_enc`. |
| `--sub-account`, `-s` | CIP-1852 account index for derivation paths. |
| `--index`, `-i` | Leaf index. |
| `--mnemonics`, `-m` / `--language`, `-l` / `--word-count`, `-w` | Mnemonic controls (same semantics as `payment-address-only`). |
| `--tool`, `-t` | Backend to use. |

## Pool metadata

### pool-json

Interactively create a `pool.json` metadata file in the format expected by the Cardano token registry and most explorers. The `pool` alias is also accepted.

```bash
scm generate pool-json --pool-name myPool

# Overwrite an existing file
scm generate pool-json --pool-name myPool --overwrite
```

| Option | Description |
|--------|-------------|
| `--pool-name`, `-p` | Writes `<name>.pool.json` in the current directory. |
| `--overwrite`, `-o` | Replace the file if it exists. |

The wizard collects pool ticker, description, homepage URL, optional logo, relays, and key file locations. After generating, host the file at a public HTTPS URL and include the URL and its hash in your pool registration certificate.

## Maintenance

### key-rotation

Run the full KES key rotation workflow: generate new KES keys, issue a new operational certificate with the incremented counter, and report the new files.

```bash
# Single pool
scm generate key-rotation --pool-name myPool --key-gen-method cli

# Multi-pool layout (pools named myPool1, myPool2, ...)
scm generate key-rotation \
  --pool-name myPool \
  --number-of-pools 3 \
  --key-gen-method cli
```

| Option | Description |
|--------|-------------|
| `--pool-name`, `-p` | Base name. KES files are looked up as `<name>.kes-XXX.skey` etc. |
| `--number-of-pools`, `-n` | Rotate `<name>1`, `<name>2`, ... in one pass. |
| `--key-gen-method`, `-k` | `cli` or `enc`. |
| `--tool`, `-t` | Backend to use. |

The wizard checks the current KES expiry slot from your operational certificate and warns if rotation is urgent.

## Other generators

These subcommands target more specialized workflows; pass `--help` for the full flag set:

| Subcommand | Purpose |
|------------|---------|
| `drep` | Generate Conway-era DRep keys. |
| `policy` | Generate a native-script minting policy and its `.policy.{id,script,vkey,skey}` files. |
| `asset-meta` | Generate signed off-chain asset metadata for the Cardano Token Registry. |
| `ed25519` | Generate a raw Ed25519 keypair with no derivation tree. |
| `derived-key` | Derive any Cardano-role BIP-32 key from a mnemonic. |
| `vote-key` | Generate a CIP-36 Catalyst voting keypair from a mnemonic. |
| `calidus-key` | Generate a CIP-151 Calidus pool-operator keypair from a mnemonic. |
| `byron-key` | Generate a Byron-era (Daedalus) keypair from a mnemonic. |

## Notes

- All generated key files use the standard Cardano `TextEnvelope` JSON format, compatible with `cardano-cli` and the broader Cardano toolchain.
- After generating addresses, use `scm build` to re-derive addresses from existing keys without regenerating them.
- Encrypt sensitive key files with `scm protect encrypt` before storing them on networked machines, or use `--key-gen-method enc` to generate them already encrypted.
