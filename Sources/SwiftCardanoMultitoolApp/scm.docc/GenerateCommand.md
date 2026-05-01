# Generate

Generate cryptographic keys, addresses, and pool metadata.

## Overview

The `generate` command creates all the cryptographic material needed to run a Cardano stake pool or manage a wallet — from node cold/KES/VRF keys through payment addresses and pool registration metadata.

```bash
scm generate <subcommand> [options]
scm generate --help
```

> **Security:** Private keys (`.skey` files) should be stored securely and never shared. Consider using `scm protect encrypt` to encrypt sensitive key files at rest.

## Node key generation

### `node-cold-keys`

Generate a stake pool cold key pair. The cold key signs operational certificates and pool registration certificates.

```bash
scm generate node-cold-keys \
  --cold-verification-key-file node.vkey \
  --cold-signing-key-file node.skey \
  --operational-certificate-issue-counter-file node.counter
```

**Output files:**

| File | Description |
|------|-------------|
| `node.vkey` | Cold verification key (public) — safe to share |
| `node.skey` | Cold signing key (private) — keep offline/encrypted |
| `node.counter` | Operational certificate issue counter |

> **Best practice:** Generate cold keys on an air-gapped machine and never move the signing key to an internet-connected device.

### `node-kes-keys`

Generate a Key Evolving Signature (KES) key pair. KES keys are used for block signing and must be rotated regularly (every `maxKESEvolutions` slots, typically ~90 days).

```bash
scm generate node-kes-keys \
  --kes-verification-key-file kes.vkey \
  --kes-signing-key-file kes.skey
```

KES keys can reside on the hot (block-producing) server because they are short-lived and rotate.

### `node-vrf-keys`

Generate a Verifiable Random Function (VRF) key pair. VRF keys prove a pool's right to mint a block in a given slot.

```bash
scm generate node-vrf-keys \
  --vrf-verification-key-file vrf.vkey \
  --vrf-signing-key-file vrf.skey
```

VRF signing keys reside on the block-producing server.

### `node-operational-certificate`

Issue a new operational certificate that authorizes the KES key to sign blocks on behalf of the cold key. Operational certificates must be regenerated each time KES keys are rotated.

```bash
scm generate node-operational-certificate \
  --kes-verification-key-file kes.vkey \
  --cold-signing-key-file node.skey \
  --operational-certificate-issue-counter-file node.counter \
  --out-file node.cert
```

Each certificate increments the issue counter. A node will not accept certificates with a counter lower than the one already on-chain.

## Address generation

### `payment-address-only`

Generate a payment key pair and derive an enterprise (payment-only) address. This address cannot receive staking rewards.

```bash
scm generate payment-address-only \
  --payment-verification-key-file payment.vkey \
  --payment-signing-key-file payment.skey \
  --out-file payment.addr
```

### `payment-and-stake-address`

Generate both payment and stake key pairs, then derive a base address (which receives staking rewards) and a stake address (for reward collection and delegation).

```bash
scm generate payment-and-stake-address \
  --payment-verification-key-file payment.vkey \
  --payment-signing-key-file payment.skey \
  --stake-verification-key-file stake.vkey \
  --stake-signing-key-file stake.skey \
  --payment-address-file payment.addr \
  --stake-address-file stake.addr
```

## Pool metadata

### `pool-json`

Interactively generate a `pool.json` metadata file in the format expected by the Cardano token registry and most explorers.

```bash
scm generate pool-json
```

The wizard collects:
- Pool name, ticker, description, homepage URL
- Pool logo (optional)

After generating, host the file at a public HTTPS URL and include the URL and its hash in your pool registration certificate.

## Maintenance

### `key-rotation`

Assist with the KES key rotation workflow. This subcommand guides you through:
1. Generating new KES keys
2. Issuing a new operational certificate with the incremented counter
3. Updating the block-producing node

```bash
scm generate key-rotation
```

The wizard checks the current KES expiry slot from your operational certificate and warns if rotation is urgent.

## Notes

- All generated key files use the standard Cardano `TextEnvelope` JSON format, compatible with `cardano-cli` and the broader Cardano toolchain.
- After generating addresses, use `scm build` to re-derive addresses from existing keys without regenerating them.
- Encrypt sensitive key files with `scm protect encrypt` before storing them on networked machines.
