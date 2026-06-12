# Swift Cardano Multitool (`scm`)

A comprehensive command-line tool for managing the Cardano blockchain ecosystem — built in Swift with an interactive terminal UI.

`scm` covers the full lifecycle of Cardano operations: installing and running node software, generating and managing keys, building and submitting transactions, querying on-chain data, and working offline with air-gapped machines.

---

## Requirements

| Requirement | Version |
|-------------|---------|
| macOS | 15+ |
| Swift | 6.2+ |

> Linux builds are supported but require Swift 6.2+ on a compatible distribution (Ubuntu 22.04 / 24.04 recommended).

---

## Installation

### Option 1 — Build from source

Clone the repository and build with Swift Package Manager:

```bash
git clone https://github.com/Kingpin-Apps/swift-cardano-multitool.git
cd swift-cardano-multitool
swift build -c release
```

The compiled binary is at `.build/release/scm`. Copy it somewhere on your `PATH`:

```bash
cp .build/release/scm ~/.local/bin/scm
```

### Option 2 — Build & install with `just`

If you have [just](https://github.com/casey/just) installed, the `Justfile` automates building a universal binary (arm64 + x86_64), codesigning, and installing:

```bash
# Install to ~/.local/bin (default)
CODESIGN_IDENTITY="Developer ID Application: ..." just install

# Install to a custom directory
INSTALL_DIR=/usr/local/bin CODESIGN_IDENTITY="..." just install
```

Other useful `just` targets:

| Target | Description |
|--------|-------------|
| `just run` | Run in development mode |
| `just build` | Debug build |
| `just release` | Release build for current arch |
| `just release-universal` | Universal binary (arm64 + x86_64) |
| `just test` | Run the test suite |
| `just sign` | Build universal + codesign |
| `just notarize` | Build, sign, and notarize for Gatekeeper |
| `just uninstall` | Remove from `$INSTALL_DIR` |

### Verify the installation

```bash
scm --version
scm --help
```

---

## Quick Start

Run `scm` with no arguments to open the interactive main menu:

```
scm
```

You will see the SCM banner and an interactive selection list of all available commands. Use arrow keys to navigate and Return to select.

To run a specific command directly (non-interactive), pass the command and subcommand as arguments:

```bash
scm query tip
scm config init
scm install cardano-node
```

---

## Configuration

Most commands require a configuration file that tells `scm` how to connect to the network, where your keys live, and which blockchain provider to use.

### Environment variables

| Variable | Description |
|----------|-------------|
| `CARDANO_MULTITOOL_CONFIG` | Path to the main config file (JSON, TOML, or YAML) |
| `CARDANO_MULTITOOL_CONFIGS` | Path to a named-configs index file (multi-environment setups) |
| `BLOCKFROST_PROJECT_ID` | Blockfrost API project ID |
| `CARDANO_MULTITOOL_DECRYPT_PASSWORD` | Pre-supply a decryption password (skips interactive prompt) |
| `CARDANO_MULTITOOL_SKIP_PROMPT` | Set to `1` to skip interactive confirmations |
| `CARDANO_MULTITOOL_USE_CARDANO_CLI` | Set to `1` to force cardano-cli backend |
| `CARDANO_MULTITOOL_USE_SWIFT_CARDANO` | Set to `1` to force Swift Cardano backend |

### Initialize a config file

```bash
scm config init
```

This wizard walks you through creating a config file for your chosen network (mainnet, preprod, preview) and saves it at a path you specify.

### Config file format

The config file supports JSON, TOML, and YAML. Example (JSON):

```json
{
  "cardano": {
    "network": "mainnet",
    "node_socket_path": "/run/cardano-node/node.socket",
    "node_config_path": "/opt/cardano/config/mainnet/config.json"
  },
  "blockfrost_project_id": "mainnetXXXXXXXXXXXXXXXX",
  "mode": "auto",
  "blockchain_explorer": "cexplorer",
  "log_level": "info"
}
```

Point `scm` at your config before running other commands:

```bash
export CARDANO_MULTITOOL_CONFIG=~/.config/scm/mainnet.json
scm query tip
```

---

## The pool.json File

Stake pool operations are driven by a per-pool registry file named `<poolName>.pool.json`. It is the single source of truth for one pool and contains:

- **Registration parameters** — pledge, cost, margin, owners, rewards owner, and relays
- **Pool metadata** — display name, ticker, description, homepage, and metadata URLs shown in wallets
- **Pool IDs** — in both hex and bech32 form
- **Key file locations** — paths to the cold, VRF, KES, payment, and stake keys, the operational certificate, and counter files
- **Registration history** — details of the last registration/deregistration performed through `scm`

The file stores *paths* to key files, never the keys themselves — but it reveals where your signing keys live, so treat it as sensitive.

Create one with the interactive wizard:

```bash
scm generate pool-json --pool-name mypool
```

This writes `mypool.pool.json` to the current directory, auto-discovering key files that follow the standard naming scheme (`mypool.cold.vkey`, `mypool.vrf.skey`, `mypool.kes-001.skey`, etc.).

Commands that require (or fall back to) a pool.json file:

| Command | Usage |
|---------|-------|
| `scm certificate pool-registration` | Builds the registration certificate from the file and records the registration back into it |
| `scm certificate pool-deregistration` | Builds the retirement certificate and records the deregistration |
| `scm query stake-pool` | Resolves the pool ID to query on-chain state |
| `scm query kes-period-info` | Locates the latest operational certificate for KES checks |
| `scm query leadership-schedule` | Reads the VRF signing key and pool ID to compute the slot schedule |

Each accepts `--pool-name <name>` (looks for `<name>.pool.json` in the current directory) or `--pool-json <path>`, and prompts interactively otherwise.

The file is plain JSON and safe to edit by hand, but fields like `registration`, KES paths, and `op_cert` are maintained automatically by `scm` commands. Note that editing the file changes nothing on-chain — submit a new registration certificate to apply parameter or metadata changes. See the full field reference in the DocC article *The pool.json File* (`scm.docc/PoolJsonFile.md`).

---

## Commands

`scm` is organized into top-level command groups. Pass `--help` to any command for full usage details.

| Command | Alias | Description |
|---------|-------|-------------|
| [`asset`](#asset) | — | Mint and burn native assets |
| [`build`](#build) | — | Build payment and stake addresses from keys |
| [`certificate`](#certificate) | `cert` | Generate Cardano certificates for stake, pools, and governance |
| [`config`](#config) | `conf` | Manage SCM configuration |
| [`download`](#download) | — | Download network config files and blockchain snapshots |
| [`generate`](#generate) | `gen` | Generate keys, addresses, and cryptographic material |
| [`governance`](#governance) | — | Cast votes and submit Conway-era governance proposals |
| [`install`](#install) | — | Install Cardano ecosystem tools |
| [`protect`](#protect) | — | Encrypt and decrypt sensitive files |
| [`query`](#query) | — | Query live blockchain data |
| [`run`](#run) | — | Start Cardano node services |
| [`send`](#send) | — | Send ADA and native assets |
| [`sign`](#sign) | — | Sign messages, governance metadata, and registrations |
| [`transaction`](#transaction) | `tx` | Build, sign, and submit transactions |
| [`verify`](#verify) | — | Verify signatures and signed metadata |
| [`work-offline`](#work-offline) | `offline` | Offline transaction workflows for air-gapped machines |
| [`version`](#version) | — | Show version information |

---

### `asset`

Mint and burn native assets under a local minting policy generated via `scm generate policy`. Both subcommands wrap the full build–sign–submit pipeline and update a `<policyName>.<assetName>.asset` audit sidecar on success.

```bash
scm asset mint   # Mint a native asset
scm asset burn   # Burn a native asset
```

Each subcommand accepts either a combined positional identifier (`policyName.assetName amount`) or the explicit flag form:

```bash
scm asset mint myPolicy.MYTOK 1000 --fee-payment-address owner.payment --submit
scm asset burn --policy-name myPolicy --asset-name MYTOK --amount 200 \
  --fee-payment-address owner.payment --submit
```

---

### `build`

Build Cardano addresses from cryptographic keys.

```bash
scm build payment-address   # Build a payment address (optionally with stake)
scm build stake-address     # Build a stake (rewards) address
```

---

### `certificate`

Create all Cardano certificate types — stake registration/delegation, pool registration/deregistration, and Conway-era governance (DRep, vote delegation, constitutional committee). The `cert` alias is also accepted.

```bash
scm certificate stake-address-registration
scm certificate stake-address-delegation
scm certificate stake-address-deregistration
scm certificate pool-registration
scm certificate pool-deregistration
scm certificate vote-delegation
scm certificate stake-vote-delegation
scm certificate stake-register-delegation
scm certificate vote-register-delegation
scm certificate stake-vote-register-delegation
scm certificate auth-committee-hot
scm certificate resign-committee-cold
scm certificate register-drep
scm certificate unregister-drep
scm certificate update-drep
scm certificate genesis-key-delegation
scm certificate move-instantaneous-rewards
```

---

### `config`

Manage your SCM configuration files.

```bash
scm config init    # Interactive setup wizard — creates a new config file
scm config show    # Display the current configuration
scm config select  # Change individual configuration values interactively
```

---

### `download`

Download files needed to run a Cardano node.

```bash
scm download configuration-files   # Download node config files for a network
scm download database-snapshot     # Download a Mithril-certified blockchain snapshot
```

---

### `generate`

Generate cryptographic material for operating a Cardano node or wallet.

```bash
# Node key material
scm generate node-cold-keys
scm generate node-kes-keys
scm generate node-vrf-keys
scm generate node-operational-certificate

# Address keys
scm generate payment-address-only
scm generate payment-and-stake-address

# Pool metadata & maintenance
scm generate pool-json
scm generate key-rotation

# Governance & minting
scm generate drep          # Conway-era DRep keys
scm generate policy        # Native-script minting policy

# Specialized key material
scm generate asset-meta    # Signed Cardano Token Registry metadata
scm generate ed25519       # Raw Ed25519 keypair
scm generate derived-key   # BIP-32 key for any Cardano role from a mnemonic
scm generate vote-key      # CIP-36 Catalyst voting keypair
scm generate calidus-key   # CIP-151 Calidus pool-operator keypair
scm generate byron-key     # Byron-era (Daedalus) keypair
```

---

### `governance`

Cast votes and submit Conway-era governance-action proposals. Each `create-*` style subcommand can run with `--generate-only` to emit just a `.action` file, which `submit-action` later bundles into a transaction.

```bash
# Cast a vote on an existing action
scm governance vote gov_action1... yes \
  --voter-vkey-file myDRep.drep.vkey \
  --fee-payment-address owner.payment --submit

# Build + submit governance actions
scm governance info-action
scm governance treasury-withdrawal
scm governance no-confidence
scm governance new-constitution
scm governance hard-fork-initiation
scm governance update-committee
scm governance parameter-change

# Submit one or more pre-built .action files
scm governance submit-action --action-file proposal.action \
  --fee-payment-address owner.payment --submit

# CIP-100 / CIP-129 utilities
scm governance canonize --data-file proposal.jsonld
scm governance cip129 encode --prefix drep --key-hash <56-hex>
scm governance cip129 decode --id drep1...
```

Any subcommand that accepts an anchor (`--anchor-url` + `--anchor-hash`) will download and blake2b-256 verify the CIP-100 document before broadcasting. Pass `--skip-anchor-verify` to bypass.

---

### `install`

Download and install Cardano ecosystem tools from their official sources. Supports binary downloads from GitHub Releases and Docker/Apple Container images.

```bash
scm install cardano-node       # Core node software
scm install cardano-cli        # Command-line interface
scm install cardano-db-sync    # PostgreSQL sync service
scm install cardano-wallet     # Wallet backend
scm install cardano-hw-cli     # Hardware wallet CLI (Ledger/Trezor)
scm install cardano-signer     # Transaction signing tool
scm install cardano-submit-api # Transaction submission API
scm install kupo               # Lightweight chain indexer
scm install ogmios             # WebSocket bridge for cardano-node
scm install mithril            # Fast bootstrap via certified snapshots
```

---

### `protect`

Encrypt and decrypt sensitive files (keys, configs) using a password.

```bash
scm protect encrypt   # Encrypt a file with a password
scm protect decrypt   # Decrypt an encrypted file
```

Set `CARDANO_MULTITOOL_DECRYPT_PASSWORD` to skip the interactive password prompt in scripts.

---

### `query`

Query live data from a running Cardano node.

```bash
scm query tip                    # Current chain tip (slot, block hash, era)
scm query address                # UTxO set for an address
scm query epoch                  # Current epoch information
scm query era                    # Current era
scm query protocol-parameters    # Current protocol parameters
scm query asset-meta             # Token Registry metadata for a native asset
scm query stake-pool             # Stake pool information
scm query kes-period-info        # Operational certificate KES period check
scm query leadership-schedule    # Upcoming/current slot leader schedule
scm query drep                   # DRep registration and metadata
scm query committee-member       # Constitutional-committee member state
scm query governance-action      # Governance action state
scm query vote                   # Votes filtered by voter, action, or type
scm query calidus-key            # CIP-88 Calidus pool-key registrations
```

---

### `run`

Start Cardano services. Each subcommand launches the service with the parameters from your config file.

```bash
scm run node     # Start the Cardano node
scm run db-sync          # Start cardano-db-sync
scm run cardano-wallet   # Start the Cardano wallet backend
scm run submit-api       # Start the transaction submit API
scm run ogmios           # Start Ogmios
scm run kupo             # Start Kupo
```

---

### `send`

Build and submit a transaction to transfer ADA or native assets.

```bash
scm send lovelaces   # Send a specific lovelace amount
scm send assets      # Send specific native assets
scm send all         # Send the entire wallet balance
```

---

### `sign`

Off-chain signing operations — plain Ed25519, CIP-8 / CIP-30 wallet messages, CIP-36 Catalyst voting registrations, CIP-88 Calidus pool-key registrations, and CIP-100 governance metadata witnesses.

```bash
scm sign default --data "hello" --secret-key payment.skey
scm sign cip8    --data "hello" --secret-key payment.skey
scm sign cip30   --data "hello" --secret-key wallet.skey
scm sign cip36   --payment-address addr1... --vote-public-key vote.vkey --secret-key stake.skey
scm sign cip88   --calidus-public-key calidus.vkey --secret-key pool.cold.skey
scm sign cip100  --data-file proposal.jsonld --secret-key author.skey --author-name "Alice"
```

All `sign` subcommands share a `--json` / `--json-extended` / `--out-file` output group and accept the payload as either `--data` (UTF-8), `--data-hex`, or `--data-file`.

---

### `transaction`

Low-level transaction operations for full control over the build–sign–submit pipeline.

```bash
# Construction
scm transaction build
scm transaction sign
scm transaction assemble
scm transaction witness
scm transaction submit

# Fee & minimum UTxO estimation
scm transaction calculate-min-fee
scm transaction calculate-min-required-utxo

# Script data
scm transaction hash-script-data

# Rewards withdrawal
scm transaction rewards-withdraw

# Inspection
scm transaction txid
scm transaction view
scm transaction inspect
scm transaction validate
```

---

### `verify`

Verify signatures and signed metadata produced by `scm sign` (or compatible cardano-signer outputs). Exits 0 on a valid signature, non-zero otherwise.

```bash
scm verify default --data "hello" --public-key payment.vkey --signature 8a5fd6...
scm verify cip8    --cose-sign1 84582a... --cose-key a401...
scm verify cip30   --cose-sign1 84582a... --cose-key a401...
scm verify cip100  --data-file proposal-signed.jsonld
```

---

### `work-offline`

Complete transaction workflows for air-gapped (offline) machines. An offline transfer file carries the data between the online and offline environments.

```bash
scm work-offline new            # Create a new offline transfer file
scm work-offline info           # Show info about the current transfer file
scm work-offline sync           # Sync chain data into the transfer file (online machine)
scm work-offline execute        # Submit a queued transaction from the transfer file (online machine)
scm work-offline attach         # Attach files to the transfer file
scm work-offline extract        # Extract files from the transfer file
scm work-offline clear-tx       # Clear pending transactions from the transfer file
scm work-offline clear-history  # Clear transaction history from the transfer file
scm work-offline clear-files    # Remove attached files from the transfer file
```

---

### `version`

Display the current `scm` version and build information.

```bash
scm version
scm --version
```

---

## Blockchain Explorers

`scm` integrates with multiple Cardano blockchain explorers for enriched output. Configure your preferred explorer in the config file or via interactive prompts:

- [Cexplorer](https://cexplorer.io) (default)
- [Cardanoscan](https://cardanoscan.io)
- [Pool Tool](https://pooltool.io)
- [Eutxo](https://eutxo.org)
- [AdaStat](https://adastat.net)

---

## Documentation

Full API and command documentation is available via DocC:

```bash
# Library API documentation
swift package generate-documentation --target SwiftCardanoMultitool

# CLI command documentation (the scm.docc catalog)
swift package generate-documentation --target SwiftCardanoMultitoolApp
```

Or open the package in Xcode and use Product → Build Documentation.

---

## License

MIT — see [LICENSE](LICENSE).
