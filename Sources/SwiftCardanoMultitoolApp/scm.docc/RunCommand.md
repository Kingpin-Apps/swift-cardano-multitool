# Run

Start Cardano node services.

## Overview

The `run` command launches Cardano services using the parameters from your `scm` configuration file. Each subcommand starts the corresponding service in the foreground.

```bash
scm run <subcommand> [options]
scm run --help
```

A valid `CARDANO_MULTITOOL_CONFIG` with the appropriate `cardano`, `ogmios`, or `kupo` sections is required before starting services.

## Subcommands

### node

Start the Cardano node process. The node connects to peers via the topology file and begins syncing (or continues from the existing database).

```bash
scm run node
```

The node is started with parameters from the `cardano` section of your config file:
- `node_socket_path` — where the Unix socket will be created
- `node_config_path` — path to `config.json`
- `node_topology_path` — path to `topology.json`
- `node_database_path` — directory for the chain database

The node runs in the foreground. Use a process supervisor (systemd, launchd, tmux) for production deployments.

### db-sync

Start `cardano-db-sync` to synchronize on-chain data to a PostgreSQL database.

```bash
scm run db-sync
```

Requires a running `cardano-node` and a configured PostgreSQL connection. The `cardano-db-sync` binary must be installed — use `scm install cardano-db-sync` first.

### cardano-wallet

Start the Cardano Wallet backend. The wallet exposes a REST API for managing UTxO wallets, constructing transactions, and delegating stake.

```bash
scm run cardano-wallet
```

Requires a running `cardano-node`. The wallet binary must be installed — use `scm install cardano-wallet` first.

### submit-api

Start the lightweight transaction submission API. This HTTP service accepts signed CBOR transactions and forwards them to the node for submission.

```bash
scm run submit-api
```

Useful as a thin submission endpoint that doesn't require exposing the full node socket.

### ogmios

Start Ogmios — a WebSocket bridge that exposes `cardano-node` mini-protocols (chain sync, tx submission, state query) over a JSON API.

```bash
scm run ogmios
```

Parameters are read from the `ogmios` section of your config (`host`, `port`). Requires a running `cardano-node` and the Ogmios binary — use `scm install ogmios` first.

Default port: `1337`

### kupo

Start Kupo — a lightweight UTxO indexer that watches address patterns and maintains a fast-query UTxO set.

```bash
scm run kupo
```

Parameters are read from the `kupo` section of your config (`host`, `port`). Requires a running `cardano-node` and the Kupo binary — use `scm install kupo` first.

Default port: `1442`

## Production deployment

For production use, run services under a process supervisor rather than in the terminal foreground:

**systemd (Linux):**
```ini
[Unit]
Description=Cardano Node
After=network.target

[Service]
ExecStart=/home/cardano/.local/bin/scm run node
Environment=CARDANO_MULTITOOL_CONFIG=/home/cardano/.config/scm/mainnet.json
Restart=always
User=cardano

[Install]
WantedBy=multi-user.target
```

**launchd (macOS):** Create a `.plist` in `~/Library/LaunchAgents/` with equivalent configuration.

## Notes

- All `run` subcommands start the respective service in the foreground and stream its output to the terminal. Press `Ctrl+C` to stop.
- The services must be installed before running. Use `scm install <tool>` to install any missing tools.
- Ensure the `cardano-node` is fully synced (check with `scm query tip`) before starting services that depend on it (db-sync, wallet, ogmios, kupo).
