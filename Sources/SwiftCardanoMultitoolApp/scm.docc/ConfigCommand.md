# Config

Manage SCM configuration files.

## Overview

The `config` command provides tools to create, display, and update the configuration file that `scm` uses to connect to the Cardano network.

```bash
scm config <subcommand> [options]
scm conf <subcommand> [options]   # alias
```

See <doc:Configuration> for a full reference of all configuration fields, environment variables, and file format examples.

## Subcommands

### init

Run the interactive setup wizard to create a new configuration file.

```bash
scm config init
```

The wizard prompts for:

1. **Network** — mainnet, preprod, preview, guildnet, sanchonet, or devkit (a local Yaci DevKit devnet)
2. **Node socket path** — path to the `cardano-node` Unix socket (e.g. `/run/cardano-node/node.socket`)
3. **Node config directory** — directory containing the network's `config.json`, `topology.json`, and genesis files
4. **Blockchain provider** — Blockfrost project ID and/or Koios API key (optional, used for queries without a local node)
5. **Blockchain explorer** — preferred explorer for transaction links in output
6. **Config file format** — JSON, TOML, or YAML
7. **Output path** — where to save the resulting config file

After initialization, set the `CARDANO_MULTITOOL_CONFIG` environment variable to point to the new file:

```bash
export CARDANO_MULTITOOL_CONFIG=~/.config/scm/mainnet.json
```

Choosing `devkit` skips the node socket, config, and topology steps — a Yaci DevKit
devnet has none — and instead sets `mode = "devkit"` with the `[yaci]` endpoints
and protocol magic 42 that DevKit uses by default:

```bash
scm config init --network devkit
```

### show

Display a configuration's contents — or its resolved path — in a readable format.

```bash
scm config show [<type>] [--era <era>] [--path]
```

`<type>` selects what to show:

| Type | Shows |
| --- | --- |
| `config` | The whole `scm` configuration (the file pointed to by `CARDANO_MULTITOOL_CONFIG`, with environment overrides applied). |
| `node` | The Cardano node configuration (`config.json`) from `[cardano].config`. |
| `genesis` | A genesis file. Requires `--era` (`byron`, `shelley`, `alonzo`, or `conway`); the path is resolved from the node config. |
| `topology` | The node topology file from `[cardano].topology`. |

Run `scm config show` with no type to be prompted interactively (and prompted for the era when you pick `genesis`).

By default the file **contents** are printed. Genesis, node, and topology files are pretty-printed structurally, so they keep displaying correctly even as the Cardano node formats gain or drop fields between releases.

Pass `--path` to print the resolved file **path** instead of the contents — handy for scripting:

```bash
scm config show node                   # prints config.json contents
scm config show node --path            # prints the path to config.json
scm config show genesis --era shelley  # prints the Shelley genesis contents
scm config show config --path          # prints the active config file path
```

Genesis files are located via the node config: each era's path is read from the
node `config.json` (e.g. `ShelleyGenesisFile`) and resolved relative to it. Set
the node config path first (see the `set` subcommand below) so genesis
resolution works.

### set

Store the path to a configuration file in the active configuration.

```bash
scm config set [<type>] [--path <path>]
```

`<type>` selects what to set:

| Type | Sets |
| --- | --- |
| `config` | The active `scm` configuration (`CARDANO_MULTITOOL_CONFIG`). Applies to the current session; export the variable to persist it across shells. |
| `node` | The `[cardano].config` path (node `config.json`). |
| `topology` | The `[cardano].topology` path. |

```bash
scm config set node --path /etc/cardano/mainnet/config.json
scm config set topology --path /etc/cardano/mainnet/topology.json
```

Run `scm config set` with no type or path to be prompted interactively.

Genesis files cannot be set directly — their paths are derived from the node
config — so `genesis` is not a settable type. Point `set node` at the
right `config.json` and genesis resolution follows.

A missing target file is only a warning, not an error: the path is still saved so
you can configure paths before the files exist. Writing `node`/`topology`
re-saves the active config file in its existing format (`.json`/`.toml`/`.yaml`),
which reorders keys and drops any comments.

### select

Interactively choose a different named configuration from your configs index.

```bash
scm config select
```

This subcommand is most useful in multi-environment setups where a named-configs index file (pointed to by `CARDANO_MULTITOOL_CONFIGS`) lists multiple network configurations. It presents an interactive picker and updates the active selection.

## Notes

- The `CARDANO_MULTITOOL_CONFIG` environment variable must be set (or the interactive wizard used) for most other `scm` commands to function.
- Environment variables always override the corresponding values in the config file. This allows you to inject secrets (e.g. `BLOCKFROST_PROJECT_ID`) without storing them in the file.
- Config files support JSON, TOML, and YAML — the format is detected from the file extension (`.json`, `.toml`, `.yaml` / `.yml`).
