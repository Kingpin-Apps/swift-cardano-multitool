# Install

Install Cardano ecosystem tools.

## Overview

The `install` command downloads and installs tools from the Cardano ecosystem. It supports fetching pre-built binaries from GitHub Releases and pulling Docker / Apple Container images.

```bash
scm install <subcommand> [options]
scm install --help
```

The interactive wizard for each tool asks for:
- Install method (binary, Docker, or Apple Container where supported)
- Version (latest or a specific tag)
- Installation directory (default: `~/.local/bin`)

## Subcommands

### `cardano-node`

The core Cardano node — validates blocks, maintains the chain state, and provides the Unix socket used by most other tools.

- **GitHub source:** `IntersectMBO/cardano-node`
- **Docker image:** `ghcr.io/intersectmbo/cardano-node`

```bash
scm install cardano-node
```

### `cardano-cli`

The official Cardano command-line interface. `scm` uses `cardano-cli` internally when the `CARDANO_MULTITOOL_USE_CARDANO_CLI` backend is active.

- **GitHub source:** `IntersectMBO/cardano-cli`

```bash
scm install cardano-cli
```

### `cardano-db-sync`

Synchronizes the Cardano blockchain to a PostgreSQL database, enabling rich SQL queries over on-chain data.

- **GitHub source:** `IntersectMBO/cardano-db-sync`

```bash
scm install cardano-db-sync
```

### `cardano-wallet`

The Cardano Wallet backend — provides a REST API for managing wallet funds, constructing transactions, and delegating stake.

- **GitHub source:** `cardano-foundation/cardano-wallet`

```bash
scm install cardano-wallet
```

### `cardano-hw-cli`

Command-line interface for Ledger and Trezor hardware wallets. Used to sign transactions with hardware keys without exposing private key material to the host machine.

- **GitHub source:** `vacuumlabs/cardano-hw-cli`

```bash
scm install cardano-hw-cli
```

### `cardano-signer`

A standalone tool for signing transactions, messages, and CIP-8/CIP-30 payloads using Cardano keys. Useful for off-chain signing workflows.

- **GitHub source:** `gitmachtl/cardano-signer`

```bash
scm install cardano-signer
```

### `cardano-submit-api`

A lightweight HTTP API for submitting signed transactions to the network via a local `cardano-node` socket.

- **GitHub source:** `IntersectMBO/cardano-node` (distributed as part of the node release)

```bash
scm install cardano-submit-api
```

### `kupo`

A lightweight Cardano chain indexer optimized for UTxO lookups. Kupo watches specific address patterns and maintains an indexed set of UTxOs accessible via an HTTP API.

- **GitHub source:** `CardanoSolutions/kupo`
- **Docker image:** `cardanosolutions/kupo`

```bash
scm install kupo
```

### `ogmios`

A WebSocket bridge interface for `cardano-node`. Ogmios exposes the node's mini-protocols (local chain sync, local tx submission, local state query) over a JSON/WebSocket API, enabling web applications and other non-Haskell clients to interact with the node.

- **GitHub source:** `CardanoSolutions/ogmios`
- **Docker image:** `cardanosolutions/ogmios`

```bash
scm install ogmios
```

### `mithril`

The Mithril client — downloads and verifies certified snapshots of the Cardano chain state, enabling fast node bootstrapping without syncing from genesis.

- **GitHub source:** `input-output-hk/mithril`
- **Docker image:** `ghcr.io/input-output-hk/mithril-client`

```bash
scm install mithril
```

## Install methods

| Method | Description | macOS | Linux |
|--------|-------------|-------|-------|
| Binary | Pre-built binary from GitHub Releases | ✓ | ✓ |
| Docker | Pull and run via Docker Engine | ✓ | ✓ |
| Apple Container | macOS-native container runtime | ✓ | — |

The binary method installs the tool directly to the target directory. Docker and Apple Container methods pull images for containerized deployment.

## Default install directory

Binaries are installed to `~/.local/bin` by default. Ensure this directory is on your `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

To override the install directory interactively, the wizard prompts for a custom path.

## Notes

- Binary downloads come from each tool's official GitHub Releases page. `scm` verifies the download before installation.
- Platform detection is automatic — `scm` selects the appropriate binary for your CPU architecture (arm64 or x86_64) and OS.
- After installing tools, use `scm run` to start them with the correct configuration from your `scm` config file.
