# Certificates

Create and submit all Cardano certificate types.

## Overview

The `certificate` command covers the full range of Cardano certificates — from basic stake address registration through Conway-era governance certificates for DReps and constitutional committee members. The `cert` alias is also accepted.

```bash
scm certificate <subcommand> [options]
scm certificate --help
```

Each subcommand runs an interactive wizard to collect any required parameters that were not provided as CLI flags.

## Shared options

Every certificate subcommand accepts the same core flags plus the full set of shared transaction options:

| Option | Description |
|--------|-------------|
| `--out-file`, `-o` | File to save the certificate to. Defaults to `{addressName}-{timestamp}.{type}.cert`. |
| `--generate-transaction`, `-g` | Also build a transaction that submits the certificate on-chain. |
| `--fee-payment-address`, `-f` | Address that pays the transaction fee (with `--generate-transaction`). |
| `--message`, `-m` | CIP-20 transaction message. Repeatable. |
| `--metadata-json` / `--metadata-cbor` | Attach metadata files to the transaction. Repeatable. |
| `--utxo-filter` / `--utxo-limit` / `--skip-utxo-with-asset` / `--only-utxo-with-asset` | UTxO selection controls. |
| `--use-cardano-cli` | Build the transaction with cardano-cli instead of SwiftCardano. |
| `--save` / `--no-save` | Whether to write the built transaction to disk (default: `--save`). |
| `--submit` | Broadcast the transaction to the configured network. |

Stake addresses are passed as a file base name — e.g. `--stake-address owner` resolves `owner.stake.addr` (or `owner.stake` / `owner.addr`) in the current directory.

## Stake address certificates

### stake-address-registration

Register a stake key on-chain. Required before delegating to a pool or DRep. The `stake-reg` alias is also accepted.

```bash
scm certificate stake-address-registration \
  --stake-address owner \
  --out-file stake-registration.cert
```

A deposit is required to register a stake key (defined by the current protocol parameters, typically 2 ADA on mainnet). The deposit is refunded upon deregistration.

### stake-address-delegation

Delegate a registered stake key to a stake pool to earn rewards. The `stake-deleg` alias is also accepted.

```bash
scm certificate stake-address-delegation \
  --stake-address owner \
  --pool-operator pool1...
```

| Option | Description |
|--------|-------------|
| `--stake-address`, `-s` | Stake address file base name. |
| `--pool-operator`, `-p` | Target pool: bech32 (`pool1...`), hex hash, or `.node.vkey` file. |

### stake-address-deregistration

Deregister a stake key and reclaim the registration deposit. The `stake-dereg` alias is also accepted.

```bash
scm certificate stake-address-deregistration --stake-address owner
```

## Stake pool certificates

### pool-registration

Register (or re-register) a stake pool from a `pool.json` metadata file. The `pool-reg` alias is also accepted.

```bash
scm certificate pool-registration --pool-name myPool
```

| Option | Description |
|--------|-------------|
| `--pool-name`, `-p` | Pool name — looks for `<poolName>.pool.json` in the current directory. |
| `--pool-json`, `-j` | Explicit path to the `pool.json` file. |
| `--force` | Set the transaction's registration type instead of detecting it from the chain: `registration` (new or retired pool, pays the pool deposit) or `reregistration` (registered pool, no deposit). The wizard offers the same choice. The wrong type makes the transaction fail. |

Create the `pool.json` file first with `scm generate pool-json` — it captures pledge, margin, cost, owners, relays, metadata URL, and key file locations.

#### Updating a registered pool without a pool.json

Pass `--pool-operator` (or choose **Registered Pool** in the wizard) to start from the pool's on-chain parameters. Interactively, you pick which parameters to change — pledge, cost, margin, relays, owners, reward account, VRF key, metadata — and are walked through only those; everything else keeps its registered value. The changes are shown against the registered values before the certificate is written, and you can save the result to a `pool.json`.

The same edits can be made non-interactively with flags. `--relay` and `--owner` are repeatable and replace the registered lists:

```bash
scm certificate pool-registration \
  --pool-operator pool1... \
  --pledge 50K --cost 340 --margin 1.5% \
  --relay dns:relay1.example.com:3001 --relay ipv4:203.0.113.7:3001 \
  --metadata-url https://example.com/pool.json --metadata-file pool.json \
  --generate-transaction --fee-payment-address myWallet
```

| Option | Description |
|--------|-------------|
| `--pool-operator` | Registered pool: pool ID (`pool1...` or hex), cold verification key (`pool_vk1...` or hex), `.pool.id` file, or cold `.vkey` file. |
| `--pledge`, `--cost` | ADA amounts (`50K`, `1.5M`) or lovelace (`340000000 lovelace`). |
| `--margin` | Decimal (`0.015`), percentage (`1.5%`), or fraction (`3/200`). |
| `--relay` | `ipv4:1.2.3.4:3001`, `ipv6:[2001:db8::1]:3001`, `dns:relay.example.com:3001`, or `srv:_cardano._tcp.example.com`. |
| `--owner`, `--reward-account` | Stake address, stake key hash, or stake `.vkey` file. |
| `--vrf-vkey` | New VRF verification key file. |
| `--metadata-url` | New metadata URL, with `--metadata-hash`, `--metadata-file` (hashes a local copy), or neither (downloads the URL). `scm hash pool-metadata` computes and checks the hash separately. |
| `--cold-signing-key`, `--owner-signing-key` | Signing keys for the transaction. Keys in the current directory that match the registered hashes are found automatically. |

On-chain parameters only contain hashes, so no key files are needed to build the certificate. With `--use-cardano-cli`, the certificate is built by `cardano-cli` only when all verification key files are found locally; otherwise it is built natively (the certificate is identical). Every owner must still sign the transaction.

### pool-deregistration

Schedule a stake pool for retirement at a specified epoch. The `pool-dereg` alias is also accepted.

```bash
scm certificate pool-deregistration \
  --pool-name myPool \
  --epoch 500
```

| Option | Description |
|--------|-------------|
| `--pool-name`, `-p` / `--pool-json`, `-j` | Pool identified by name or `pool.json` path. |
| `--pool-operator` | Pool identified without a `pool.json`: bech32 pool ID (`pool1...`), hex hash, `.pool.id` file, or `.node.vkey` file. |
| `--cold-signing-key` | Pool cold signing key (`.node.skey`) used to witness the transaction when no `pool.json` is used. |
| `--epoch`, `-e` | The epoch in which the pool retires. |

No `pool.json`? Identify the pool by its operator and pick the cold key and fee payment wallet directly (the interactive wizard offers the same choices under **Pool Operator**):

```bash
scm certificate pool-deregistration \
  --pool-operator pool1... \
  --cold-signing-key myPool.node.skey \
  --generate-transaction \
  --fee-payment-address myWallet
```

## Combined stake/delegation certificates (Conway era)

Conway introduced several atomic certificates that combine registration and delegation in a single operation, saving on transaction fees and deposits.

### stake-register-delegation

Register a stake key and immediately delegate to a pool (`stake-reg-deleg`).

### vote-register-delegation

Register a stake key and immediately delegate voting power to a DRep (`vote-reg-deleg`).

### stake-vote-delegation

Delegate both stake (to a pool) and votes (to a DRep) in one certificate (`stake-vote-deleg`).

### stake-vote-register-delegation

Register, delegate stake, and delegate votes — all in one certificate (`stake-vote-reg-deleg`).

### vote-delegation

Delegate voting power to a DRep without registering or changing pool delegation (`vote-deleg`).

```bash
scm certificate vote-delegation \
  --stake-address owner \
  --drep drep1...
```

| Option | Description |
|--------|-------------|
| `--stake-address`, `-s` | Stake address file base name. |
| `--drep`, `-d` | DRep target: bech32 (`drep1...`), hex hash, `.drep.vkey` file, `always-abstain`, or `always-no-confidence`. |

## Constitutional committee certificates

### auth-committee-hot

Authorize a hot credential for a cold constitutional committee key pair (`auth-cc-hot`). Hot credentials are used for day-to-day voting without exposing the cold key.

```bash
scm certificate auth-committee-hot \
  --committee-cold-credential cc_cold1... \
  --committee-hot-credential cc_hot1...
```

| Option | Description |
|--------|-------------|
| `--committee-cold-credential` | Cold credential: bech32 (`cc_cold1...`), hex hash, or `.cc-cold.vkey` file. |
| `--committee-hot-credential` | Hot credential: bech32 (`cc_hot1...`), hex hash, or `.cc-hot.vkey` file. |

### resign-committee-cold

Resign from the constitutional committee (`resign-cc-cold`). This permanently removes the associated cold key from the committee. An optional anchor can link the resignation to off-chain metadata.

```bash
scm certificate resign-committee-cold \
  --committee-cold-credential cc_cold1...
```

## DRep certificates

All DRep subcommands take `--drep-credential` — a bech32 ID (`drep1...`), hex hash, or `.drep.vkey` file.

### register-drep

Register as a Delegated Representative (`drep-reg`). The DRep deposit is required and deducted from the fee payment address. An optional anchor (URL + metadata hash) links the registration to off-chain CIP-100 metadata. Compute the metadata hash with `scm hash drep-metadata --drep-metadata-file myDRep.jsonld`; `scm hash drep-key` prints the DRep key hash and IDs.

```bash
scm certificate register-drep --drep-credential drep1...
```

### unregister-drep

Unregister as a DRep and reclaim the DRep deposit (`drep-unreg`).

```bash
scm certificate unregister-drep --drep-credential drep1...
```

### update-drep

Update the metadata anchor of an already-registered DRep (`drep-update`).

```bash
scm certificate update-drep --drep-credential drep1...
```

## Legacy certificates

### genesis-key-delegation

Create a genesis key delegation certificate (`gen-deleg`) — Byron / early Shelley era, rarely needed on modern networks.

### move-instantaneous-rewards

Create a Move Instantaneous Rewards certificate (`mir`) — deprecated in the Conway era.

## Notes

- Pass `--generate-transaction --submit` to create the certificate, wrap it in a balanced transaction, sign, and broadcast in one step. Without those flags only the `.cert` file is written — include it later with `scm transaction build --certificate-file`.
- Most certificate operations require the corresponding signing key to be available on disk next to the verification key when building the transaction witness.
- Conway-era certificates (`vote-delegation`, `register-drep`, etc.) are only valid on networks running in the Conway era or later.
- Check a certificate before submitting it with `scm text-view <file>.cert`, which shows its fields (pool parameters, credentials, deposits, anchors) in readable form. See <doc:TextViewCommand>.
- Pool IDs, VRF key hashes and metadata hashes can be computed separately with `scm hash pool-id`, `scm hash vrf-key` and `scm hash pool-metadata`. See <doc:HashCommand>.
