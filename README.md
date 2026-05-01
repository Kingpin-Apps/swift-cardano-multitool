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

## Commands

`scm` is organized into top-level command groups. Pass `--help` to any command for full usage details.

| Command | Alias | Description |
|---------|-------|-------------|
| [`build`](#build) | — | Build payment and stake addresses from keys |
| [`certificates`](#certificates) | — | Create and submit Cardano certificates |
| [`config`](#config) | `conf` | Manage SCM configuration |
| [`download`](#download) | — | Download network config files and blockchain snapshots |
| [`generate`](#generate) | — | Generate keys, addresses, and cryptographic material |
| [`install`](#install) | — | Install Cardano ecosystem tools |
| [`protect`](#protect) | — | Encrypt and decrypt sensitive files |
| [`query`](#query) | — | Query live blockchain data |
| [`run`](#run) | — | Start Cardano node services |
| [`send`](#send) | — | Send ADA and native assets |
| [`transaction`](#transaction) | — | Build, sign, and submit transactions |
| [`work-offline`](#work-offline) | — | Offline transaction workflows for air-gapped machines |
| [`version`](#version) | — | Show version information |

---

### `build`

Build Cardano addresses from cryptographic keys.

```bash
scm build payment-address   # Build a payment address (optionally with stake)
scm build stake-address     # Build a stake (rewards) address
```

---

### `certificates`

Create and submit all Cardano certificate types, including stake registration, pool registration/deregistration, governance, and Conway-era DRep/committee certificates.

```bash
scm certificates stake-address-registration
scm certificates stake-address-delegation
scm certificates stake-address-deregistration
scm certificates stake-pool-registration
scm certificates stake-pool-deregistration
scm certificates vote-delegation
scm certificates stake-vote-delegate
scm certificates stake-register-delegate
scm certificates vote-register-delegate
scm certificates stake-vote-register-delegate
scm certificates auth-committee-hot
scm certificates resign-committee-cold
scm certificates register-drep
scm certificates unregister-drep
scm certificates update-drep
scm certificates genesis-key-delegation
scm certificates move-instantaneous-rewards
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
```

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
scm query stake-pool             # Stake pool information
scm query kes-period-info        # Operational certificate KES period check
scm query leadership-schedule    # Upcoming/current slot leader schedule
```

---

### `run`

Start Cardano services. Each subcommand launches the service with the parameters from your config file.

```bash
scm run cardano-node     # Start the Cardano node
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

### `work-offline`

Complete transaction workflows for air-gapped (offline) machines. An offline transfer file carries the data between the online and offline environments.

```bash
scm work-offline new            # Create a new offline transfer file
scm work-offline info           # Show info about the current transfer file
scm work-offline sync           # Sync chain data into the transfer file (online machine)
scm work-offline execute        # Execute a transaction using the transfer file (offline machine)
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

Full API and command documentation is available via DocC. Build and open it with:

```bash
swift package generate-documentation --target SwiftCardanoMultitoolLib --include-extended-types
```

Or open the `.docc` catalog in Xcode for rendered documentation.

---

## License

MIT — see [LICENSE](LICENSE).
