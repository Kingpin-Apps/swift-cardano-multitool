# Certificates

Create and submit all Cardano certificate types.

## Overview

The `certificates` command covers the full range of Cardano certificates — from basic stake address registration through Conway-era governance certificates for DReps and constitutional committee members.

```bash
scm certificates <subcommand> [options]
scm certificates --help
```

Each subcommand runs an interactive wizard to collect any required parameters that were not provided as CLI flags.

## Stake address certificates

### `stake-address-registration`

Register a stake key on-chain. Required before delegating to a pool or DRep.

```bash
scm certificates stake-address-registration \
  --stake-verification-key-file stake.vkey \
  --out-file stake-registration.cert
```

A deposit is required to register a stake key (defined by the current protocol parameters, typically 2 ADA on mainnet). The deposit is refunded upon deregistration.

### `stake-address-delegation`

Delegate a registered stake key to a stake pool to earn rewards.

```bash
scm certificates stake-address-delegation \
  --stake-verification-key-file stake.vkey \
  --stake-pool-id pool1... \
  --out-file delegation.cert
```

### `stake-address-deregistration`

Deregister a stake key and reclaim the registration deposit.

```bash
scm certificates stake-address-deregistration \
  --stake-verification-key-file stake.vkey \
  --out-file stake-deregistration.cert
```

## Stake pool certificates

### `stake-pool-registration`

Register a new stake pool. Requires cold keys, VRF keys, pool metadata, and relay information.

```bash
scm certificates stake-pool-registration
```

The interactive wizard collects:
- Cold verification key
- VRF verification key
- Pledge amount (in lovelace)
- Cost per epoch (in lovelace)
- Pool margin (percentage)
- Pool reward address
- Pool owners
- Relays (DNS or IP based)
- Pool metadata URL and hash

### `stake-pool-deregistration`

Schedule a stake pool for retirement at a specified epoch.

```bash
scm certificates stake-pool-deregistration \
  --cold-verification-key-file node.vkey \
  --epoch 500 \
  --out-file pool-deregistration.cert
```

## Combined stake/delegation certificates (Conway era)

Conway introduced several atomic certificates that combine registration and delegation in a single operation, saving on transaction fees and deposits.

### `stake-register-delegate`

Register a stake key and immediately delegate to a pool.

### `vote-register-delegate`

Register a stake key and immediately delegate voting power to a DRep.

### `stake-vote-delegate`

Delegate both stake (to a pool) and votes (to a DRep) in one certificate.

### `stake-vote-register-delegate`

Register, delegate stake, and delegate votes — all in one certificate.

### `vote-delegation`

Delegate voting power to a DRep without registering or changing pool delegation.

```bash
scm certificates vote-delegation \
  --stake-verification-key-file stake.vkey \
  --drep-key-hash <drep-key-hash>
```

**DRep target options:**

| Flag | Description |
|------|-------------|
| `--drep-key-hash` | Delegate to a specific DRep by key hash |
| `--always-abstain` | Delegate to the built-in "always abstain" DRep |
| `--always-no-confidence` | Delegate to the built-in "always no confidence" DRep |

## Constitutional committee certificates

### `auth-committee-hot`

Authorize a hot credential for a cold constitutional committee key pair. Hot credentials are used for day-to-day voting without exposing the cold key.

```bash
scm certificates auth-committee-hot \
  --cold-verification-key-file cc-cold.vkey \
  --hot-verification-key-file cc-hot.vkey \
  --out-file auth-committee-hot.cert
```

### `resign-committee-cold`

Resign from the constitutional committee. This permanently removes the associated cold key from the committee.

```bash
scm certificates resign-committee-cold \
  --cold-verification-key-file cc-cold.vkey \
  --out-file resign-committee-cold.cert
```

## DRep certificates

### `register-drep`

Register as a Delegated Representative (DRep). A DRep deposit is required (defined by the protocol parameters).

```bash
scm certificates register-drep \
  --drep-verification-key-file drep.vkey \
  --out-file register-drep.cert
```

### `unregister-drep`

Unregister as a DRep and reclaim the DRep deposit.

```bash
scm certificates unregister-drep \
  --drep-verification-key-file drep.vkey \
  --out-file unregister-drep.cert
```

### `update-drep`

Update DRep metadata (anchor URL and hash).

```bash
scm certificates update-drep \
  --drep-verification-key-file drep.vkey \
  --anchor-url https://example.com/drep-metadata.json \
  --anchor-data-hash <hash> \
  --out-file update-drep.cert
```

## Legacy certificates

### `genesis-key-delegation`

Create a genesis key delegation certificate (Byron / early Shelley era — rarely needed on modern networks).

### `move-instantaneous-rewards`

Create a Move Instantaneous Rewards (MIR) certificate (deprecated in Conway era).

## Notes

- Certificates must be included in a transaction and submitted to the chain. After creating a certificate file, use `scm transaction build` and `scm transaction submit` to submit it.
- Most certificate operations require the corresponding signing key to be provided when building the transaction witness.
- Conway-era certificates (`vote-delegation`, `register-drep`, etc.) are only valid on networks running in the Conway era or later.
