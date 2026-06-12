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

1. **Network** — mainnet, preprod, preview, guildnet, or sanchonet
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

### show

Display the currently loaded configuration in a readable format.

```bash
scm config show
```

This reads the file pointed to by `CARDANO_MULTITOOL_CONFIG` (and any environment variable overrides) and prints all resolved values. Useful for verifying that your config is loaded correctly before running other commands.

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
