# Configuration

Set up your environment and configuration file for `scm`.

## Overview

`scm` is driven by a configuration file that specifies network settings, API credentials, and tool paths. The file can be JSON, TOML, or YAML. Environment variables can override any individual value in the file.

## Environment variables

| Variable | Description |
|----------|-------------|
| `CARDANO_MULTITOOL_CONFIG` | **Required for most commands.** Path to the main config file. |
| `CARDANO_MULTITOOL_CONFIGS` | Path to a named-configs index file (for multi-environment setups). |
| `BLOCKFROST_PROJECT_ID` | Blockfrost API project ID (overrides `blockfrost_project_id` in the file). |
| `CARDANO_MULTITOOL_DECRYPT_PASSWORD` | Pre-supply a decryption password to skip the interactive prompt. |
| `CARDANO_MULTITOOL_SKIP_PROMPT` | Set to `1` / `true` / `yes` to suppress interactive confirmations. |
| `CARDANO_MULTITOOL_USE_CARDANO_CLI` | Set to `1` to force the `cardano-cli` execution backend. |
| `CARDANO_MULTITOOL_USE_SWIFT_CARDANO` | Set to `1` to force the Swift Cardano execution backend. |

## Creating a config file

The fastest way to create a config file is the interactive wizard:

```bash
scm config init
```

This walks you through network selection, node socket path, key directories, blockchain provider, and API credentials, then writes a config file at a path of your choice.

## Config file reference

The following is a fully annotated JSON example. Omit any optional field to use its default.

```json
{
  "blockfrost_project_id": "mainnetXXXXXXXXXXXXXXXX",
  "koios_api_key": "eyJhbGc...",

  "cardano": {
    "network": "mainnet",
    "node_socket_path": "/run/cardano-node/node.socket",
    "node_config_path": "/opt/cardano/config/mainnet/config.json",
    "node_topology_path": "/opt/cardano/config/mainnet/topology.json",
    "node_database_path": "/opt/cardano/db"
  },

  "mithril": {
    "aggregator_endpoint": "https://aggregator.release-mainnet.api.mithril.network/aggregator",
    "genesis_verification_key": "..."
  },

  "ogmios": {
    "host": "localhost",
    "port": 1337
  },

  "kupo": {
    "host": "localhost",
    "port": 1442
  },

  "mode": "auto",

  "offline_file": "./offline-transfer.json",

  "blockchain_explorer": "cexplorer",

  "token_meta_server": {
    "mainnet": "https://tokens.cardano.org/metadata/",
    "preprod": "https://metadata.cardano-testnet.iohkdev.io/metadata/",
    "preview": "https://metadata.cardano-testnet.iohkdev.io/metadata/"
  },

  "ada_handle_policy": {
    "mainnet": "f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a",
    "preprod": "f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a",
    "preview": "f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a"
  },

  "log_level": "info",
  "show_version_info": true,
  "query_token_registry": true,
  "crop_tx_output": true,
  "max_retry_attempts": 5,
  "base_retry_delay": 200
}
```

### TOML equivalent

The same config expressed in TOML:

```toml
blockfrost_project_id = "mainnetXXXXXXXXXXXXXXXX"

[cardano]
network = "mainnet"
node_socket_path = "/run/cardano-node/node.socket"
node_config_path = "/opt/cardano/config/mainnet/config.json"

[ogmios]
host = "localhost"
port = 1337

[kupo]
host = "localhost"
port = 1442

mode = "auto"
blockchain_explorer = "cexplorer"
log_level = "info"
```

## Field reference

### Top-level

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `blockfrost_project_id` | String | — | Blockfrost API project ID |
| `koios_api_key` | String | — | Koios API key |
| `mode` | String | `"auto"` | Operation mode: `auto`, `online`, `offline`, or `lite` |
| `offline_file` | String | `./offline-transfer.json` | Path to the offline transfer file used by `work-offline` |
| `blockchain_explorer` | String | `"cexplorer"` | Explorer for transaction links: `cexplorer`, `cardanoscan`, `pooltool`, `eutxo`, `adastat` |
| `log_level` | String | `"info"` | Logging verbosity: `trace`, `debug`, `info`, `notice`, `warning`, `error`, `critical` |
| `show_version_info` | Bool | `true` | Display version alongside tool output |
| `query_token_registry` | Bool | `true` | Fetch token metadata from the token registry |
| `crop_tx_output` | Bool | `true` | Truncate long transaction output in the terminal |
| `max_retry_attempts` | Int | `5` | Maximum number of retries for API calls |
| `base_retry_delay` | Int (ms) | `200` | Base delay for exponential backoff between retries |

### `cardano` section

| Field | Description |
|-------|-------------|
| `network` | Network name: `mainnet`, `preprod`, `preview`, `guildnet` |
| `node_socket_path` | Path to the `cardano-node` Unix socket |
| `node_config_path` | Path to the node's `config.json` |
| `node_topology_path` | Path to the node's `topology.json` |
| `node_database_path` | Path to the node's LevelDB database directory |

### `mithril` section

| Field | Description |
|-------|-------------|
| `aggregator_endpoint` | Mithril aggregator API URL |
| `genesis_verification_key` | Genesis verification key for the target network |

### `ogmios` section

| Field | Default | Description |
|-------|---------|-------------|
| `host` | `localhost` | Ogmios host |
| `port` | `1337` | Ogmios port |

### `kupo` section

| Field | Default | Description |
|-------|---------|-------------|
| `host` | `localhost` | Kupo host |
| `port` | `1442` | Kupo port |

## Multi-environment (named configs)

For operators managing multiple networks, use a named-configs index file alongside individual network configs:

```json
{
  "configs": {
    "mainnet": "/home/user/.config/scm/mainnet.json",
    "preprod": "/home/user/.config/scm/preprod.json",
    "preview":  "/home/user/.config/scm/preview.json"
  }
}
```

Point to this index with `CARDANO_MULTITOOL_CONFIGS`, then switch between them with:

```bash
scm config select
```

## Viewing the active config

```bash
scm config show
```

This prints all loaded values (including any environment variable overrides) in a readable format.
