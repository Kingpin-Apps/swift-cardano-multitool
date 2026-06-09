# Version

Show the application's version and chain-context information.

## Overview

The `version` command prints the running `scm` build version alongside a snapshot of the resolved chain context — the loaded config, selected network, blockchain backend, and (when reachable) the connected node tip. It's the fastest way to confirm that a fresh install is wired up correctly.

```bash
scm version
scm --version
```

Both forms emit the same one-time output. Unlike most `scm` commands, `version` has no subcommands and no flags — it loads `MultitoolConfig`, resolves a chain context, and prints. If the configured node or API provider is unreachable the command still succeeds and prints the local version, noting that no context is available.

## Sample output

```
scm 1.x.y
Network:  mainnet
Backend:  swift-cardano
Tip:      slot 123_456_789 (epoch 512, era Conway)
```

The exact fields depend on the loaded configuration — see <doc:Configuration> for what determines the network and backend.

## Notes

- Useful as a smoke test in CI: a non-zero exit indicates the binary itself is broken, while a successful run that omits chain-context lines indicates a configuration or connectivity issue with the configured provider.
- The version printed here is baked in at build time from the package's `Version.swift`; rebuild after pulling new code to see updated information.
