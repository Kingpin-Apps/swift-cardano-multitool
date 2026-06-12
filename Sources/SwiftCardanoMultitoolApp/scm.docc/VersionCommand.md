# Version

Show the application's version and chain-context information.

## Overview

The `version` command prints the running `scm` build version alongside a snapshot of the resolved environment — the active chain context, scripts mode, and platform. It's the fastest way to confirm that a fresh install is wired up correctly.

```bash
scm version
scm --version
```

`scm version` loads `MultitoolConfig`, resolves a chain context, and prints the full info block; the `--version` flag (available on every command) prints just the bare version number. `version` itself has no subcommands and no flags.

## Sample output

```
SwiftCardanoMultitool v1.x.y
Chain Context: CardanoCliChainContext
Scripts-Mode: Auto
Platform: Version 15.5 (Build ...)
```

When the chain context is backed by cardano-cli, the installed `cardano-cli` and `cardano-node` versions are also shown. The exact fields depend on the loaded configuration — see <doc:Configuration> for what determines the network and backend.

## Notes

- Useful as a smoke test in CI: a non-zero exit indicates the binary itself is broken, while a successful run that omits chain-context lines indicates a configuration or connectivity issue with the configured provider.
- The version printed here is baked in at build time from the package's `Version.swift`; rebuild after pulling new code to see updated information.
