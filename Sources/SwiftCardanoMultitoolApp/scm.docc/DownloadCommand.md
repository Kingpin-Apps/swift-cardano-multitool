# Download

Download Cardano node configuration files and blockchain database snapshots.

## Overview

The `download` command simplifies the setup of a new Cardano node by fetching official network configuration files and, optionally, a pre-synced database snapshot so the node doesn't have to sync from genesis.

```bash
scm download <subcommand> [options]
scm download --help
```

## Subcommands

### configuration-files

Download the official node configuration files for a Cardano network from `book.world.dev.cardano.org`.

```bash
scm download configuration-files
scm download configuration-files --network preprod --db-sync
```

**Options:**

| Option | Description |
|--------|-------------|
| `--network`, `-n` | Network to download configs for: `mainnet`, `preprod`, `preview`, `guildnet`, `sanchonet`. |
| `--block-poducer` | Download the block-producer node config instead of the relay config. |
| `--db-sync` | Also download configs for cardano-db-sync. |
| `--submit-api` | Also download configs for cardano-submit-api. |

Any missing parameters (like the output directory) are collected interactively.

Files downloaded:

| File | Description |
|------|-------------|
| `config.json` | Main node configuration |
| `topology.json` | Peer topology |
| `shelley-genesis.json` | Shelley era genesis parameters |
| `byron-genesis.json` | Byron era genesis parameters |
| `alonzo-genesis.json` | Alonzo era genesis parameters |
| `conway-genesis.json` | Conway era genesis parameters |

After downloading, point your config at the directory:

```bash
# In your scm config file:
# "node_config_path": "/path/to/config/mainnet/config.json"
```

### database-snapshot

Download a Mithril-certified blockchain snapshot to bootstrap a node without syncing from genesis.

```bash
scm download database-snapshot
scm download database-snapshot --network preprod
```

Mithril is a stake-based threshold multi-signature scheme that certifies snapshots of the Cardano chain state. Downloading a certified snapshot lets you start a node fully synced in minutes rather than days.

**Options:**

| Option | Description |
|--------|-------------|
| `--network`, `-n` | Network to download the snapshot for (defaults to the configured network). |

The snapshot is fetched and verified through the Mithril aggregator configured in the `mithril` section of your config file; remaining parameters are collected interactively.

> **Important:** Verify your Mithril aggregator endpoint and genesis verification key in your config before downloading. Using an untrusted aggregator could result in a corrupt database.

After extraction, configure your `cardano-node` to use the downloaded database directory.

## Notes

- An internet connection is required for both subcommands.
- The `download database-snapshot` subcommand requires Mithril client to be installed. Install it with `scm install mithril` first.
- Downloaded configuration files are pinned to a specific network. Do not mix mainnet config files with a preprod node or vice versa.
