# Chain Context Guide

Obtain a live blockchain connection for querying UTxOs, protocol parameters, and chain state.

## Overview

`SwiftCardanoMultitool` abstracts over multiple Cardano data providers through the `ChainContext` protocol from `SwiftCardanoChain`. Call ``getContext(config:)`` with a loaded ``MultitoolConfig`` and you get back a ready-to-use context — the correct provider is chosen automatically based on your configuration and the active ``Mode``.

> Note: `ChainContext` is defined in the `SwiftCardanoChain` module. Add `SwiftCardanoChain` to your target's dependencies to access its types directly.

## Adding the dependency

In your `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/Kingpin-Apps/swift-cardano-multitool.git",
        from: "0.1.0"
    ),
],
targets: [
    .target(
        name: "MyTarget",
        dependencies: [
            .product(name: "SwiftCardanoMultitool", package: "swift-cardano-multitool"),
        ]
    ),
]
```

## Loading a config and obtaining a context

```swift
import SwiftCardanoMultitool

// Load config from the path in $CARDANO_MULTITOOL_CONFIG
let config = try await MultitoolConfig.load()

// Obtain a ChainContext (Blockfrost, Koios, Ogmios, Yaci DevKit, or local node socket)
let context = try await getContext(config: config)

// Query the current protocol parameters
let params = try await getProtocolParameters(context: context, config: config)
print("Min fee A:", params.minFeeA)
```

## Supported providers

The provider returned by ``getContext(config:)`` depends on your ``MultitoolConfig`` and ``Mode``:

| Mode | Provider selected |
|------|-------------------|
| `auto` | Tries Ogmios/Kupo → Blockfrost → Koios in order |
| `online` | Requires a local node socket (Ogmios or direct) |
| `lite` | Uses Blockfrost or Koios (no local node required) |
| `devkit` | A local Yaci DevKit devnet, read through its Yaci Store and admin APIs |
| `offline` | No network provider — for air-gapped use only |

`devkit` is only ever reached by asking for it. `auto` never falls through to it,
so a `[yaci]` block left over from a devnet session cannot silently redirect a
mainnet command at a throw-away chain.

## Developing against a Yaci DevKit devnet

[Yaci DevKit](https://github.com/bloxbean/yaci-devkit) starts a pre-funded local
Cardano network in seconds, with epochs measured in minutes rather than days. Set
`mode` to `devkit` and `scm` reads it through the Yaci Store REST API that DevKit
embeds, taking genesis and cost models from DevKit's admin (cluster) API.

Generate a ready-to-use config with:

```bash
scm config init --network devkit
```

Or write the block by hand — every field is optional and the defaults match a
DevKit started on the local machine:

```toml
mode = "devkit"

[cardano]
# The devnet's protocol magic. DevKit's default is 42.
network = 42
era = "conway"
ttl_buffer = 3600

[yaci]
api_url = "http://localhost:8080"       # Yaci Store
admin_url = "http://localhost:10000"    # DevKit admin / cluster API
network_magic = 42
```

There is no API key, no node socket, and no Ogmios process to run — but
`evaluateTx` needs DevKit started with `ogmios_enabled=true`.

> Important: `network` under `[cardano]` is what the rest of `scm` uses to build
> addresses and explorer links, so it must match the devnet's magic. `scm` warns
> if it is left on mainnet while `mode` is `devkit`.

Yaci Store indexes certificates and outputs rather than ledger state, so some
queries are reconstructions and a few have no data source at all — notably the
treasury and the SPO stake distribution, which throw `notImplemented`, and
governance action outcomes, which always read as still open. See
`SwiftCardanoChain`'s *Using YaciDevkit* article for the full capability table.

## Loading config programmatically

You can construct a ``MultitoolConfig`` directly without a file:

```swift
import SwiftCardanoMultitool
import SwiftCardanoChain
import SystemPackage

let config = MultitoolConfig(
    blockfrostProjectId: "mainnetXXXXXXXXXXXXXXXX",
    cardano: CardanoConfig(
        socket: FilePath("/run/cardano-node/node.socket"),
        network: .mainnet,
        era: .conway,
        ttlBuffer: 3600
    ),
    mode: .lite,
    tokenMetaServer: TokenMetaServerURLs(),
    adaHandlePolicy: AdaHandlePolicyIds()
)

let context = try await getContext(config: config)
```

## Loading config from a file

Config files can be JSON, TOML, or YAML. The format is inferred from the file extension:

```swift
import SwiftCardanoMultitool
import SystemPackage

// From the CARDANO_MULTITOOL_CONFIG environment variable
let config = try await MultitoolConfig.load()

// From an explicit path
let config = try await MultitoolConfig.load(from: FilePath("/home/user/.config/scm/mainnet.toml"))
```

Environment variables override individual fields:

| Variable | Overrides |
|----------|-----------|
| `BLOCKFROST_PROJECT_ID` | `config.blockfrostProjectId` |
| `CARDANO_MULTITOOL_CONFIG` | Path used by `MultitoolConfig.load()` |

## Querying chain state

```swift
// Query UTxOs and rewards for a stake address
let stakeInfo = try await stakeAddressInfoSummary(
    stakeAddress: stakeAddr,
    context: context,
    config: config
)

// Query UTxOs for a payment address
let utxos = try await utxoSummary(
    address: paymentAddr,
    context: context,
    config: config
)

// Query current chain state (tip, era, epoch)
let chainState = try await queryChainState(context: context, config: config)
```

## Embedding the full TUI

If you just want to run the complete `scm` interactive application inside your own executable, call ``runApp()``:

```swift
import SwiftCardanoMultitool

@main
struct MyApp {
    static func main() async {
        await runApp()
    }
}
```

This is exactly what the `scm` binary does.
