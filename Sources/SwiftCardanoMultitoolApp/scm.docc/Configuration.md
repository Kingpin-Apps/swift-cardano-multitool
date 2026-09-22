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
| `CARDANO_NODE_SOCKET_PATH` | Node socket path autodetected by `config init` (falls back to `CARDANO_SOCKET_PATH`). |
| `CARDANO_SOCKET_PATH` | Fallback node socket path used by `config init` autodetection. |
| `IPFS_GATEWAY_URI` | Gateway for `ipfs://` URLs in `scm hash` (default `https://ipfs.io/`), as in `cardano-cli`. |

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
    "socket": "/run/cardano-node/node.socket",
    "config": "/opt/cardano/config/mainnet/config.json",
    "topology": "/opt/cardano/config/mainnet/topology.json",
    "database": "/opt/cardano/db"
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
socket = "/run/cardano-node/node.socket"
config = "/opt/cardano/config/mainnet/config.json"

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
| `mode` | String | `"auto"` | Operation mode: `auto`, `online`, `offline`, `lite`, or `devkit` |
| `offline_file` | String | `./offline-transfer.json` | Path to the offline transfer file used by `work-offline` |
| `blockchain_explorer` | String | `"cexplorer"` | Explorer for transaction links: `cexplorer`, `cardanoscan`, `pooltool`, `eutxo`, `adastat` |
| `log_level` | String | `"info"` | Logging verbosity: `trace`, `debug`, `info`, `notice`, `warning`, `error`, `critical` |
| `show_version_info` | Bool | `true` | Display version alongside tool output |
| `query_token_registry` | Bool | `true` | Fetch token metadata from the token registry |
| `crop_tx_output` | Bool | `true` | Truncate long transaction output in the terminal |
| `max_retry_attempts` | Int | `5` | Maximum number of retries for API calls |
| `base_retry_delay` | Int (ms) | `200` | Base delay for exponential backoff between retries |

### cardano section

| Field | Description |
|-------|-------------|
| `network` | Network name: `mainnet`, `preprod`, `preview`, `guildnet`, `sanchonet`, or a bare protocol magic such as `42` for a devnet |
| `socket` | Path to the `cardano-node` Unix socket |
| `config` | Path to the node's `config.json` |
| `topology` | Path to the node's `topology.json` |
| `database` | Path to the node's chain database directory |

### mithril section

| Field | Description |
|-------|-------------|
| `aggregator_endpoint` | Mithril aggregator API URL |
| `genesis_verification_key` | Genesis verification key for the target network |

### ogmios section

| Field | Default | Description |
|-------|---------|-------------|
| `host` | `localhost` | Ogmios host |
| `port` | `1337` | Ogmios port |

### kupo section

| Field | Default | Description |
|-------|---------|-------------|
| `host` | `localhost` | Kupo host |
| `port` | `1442` | Kupo port |

### yaci section

Read only when `mode` is `devkit`. Every field is optional; the defaults match a
[Yaci DevKit](https://github.com/bloxbean/yaci-devkit) started on the local machine.

| Field | Default | Description |
|-------|---------|-------------|
| `api_url` | `http://localhost:8080` | Yaci Store REST API, where chain data is read from |
| `admin_url` | `http://localhost:10000` | DevKit admin (cluster) API, where genesis and cost models come from |
| `network_magic` | `42` | The devnet's protocol magic |

## Developing against a Yaci DevKit devnet

Yaci DevKit starts a pre-funded local Cardano network in seconds, with epochs
measured in minutes rather than days — useful for exercising a whole delegation
or governance lifecycle in one sitting. Generate a config for it with:

```bash
scm config init --network devkit
```

That sets `mode = "devkit"`, points `[cardano] network` at magic 42, and fills in
the `[yaci]` endpoints. There is no API key, no node socket, and no Ogmios process
to run — though `scm transaction build` needs DevKit started with
`ogmios_enabled=true` for script evaluation.

`devkit` is only ever used when asked for: `auto` never falls back to it, so a
leftover `[yaci]` block cannot silently redirect a mainnet command at a devnet.
Keep `[cardano] network` matching the devnet's magic — it is what `scm` uses to
build addresses and explorer links, and `scm` warns if it is left on mainnet.

Yaci Store indexes certificates and outputs rather than ledger state, so the
treasury and SPO stake distribution are unavailable, and governance actions always
read as still open even once they have concluded.

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
