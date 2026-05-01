# Chain Context Guide

Obtain a live blockchain connection for querying UTxOs, protocol parameters, and chain state.

## Overview

`SwiftCardanoMultitoolLib` abstracts over multiple Cardano data providers through the `ChainContext` protocol from `SwiftCardanoChain`. Call ``getContext(config:)`` with a loaded ``MultitoolConfig`` and you get back a ready-to-use context — the correct provider is chosen automatically based on your configuration and the active ``Mode``.

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
            .product(name: "SwiftCardanoMultitoolLib", package: "swift-cardano-multitool"),
        ]
    ),
]
```

## Loading a config and obtaining a context

```swift
import SwiftCardanoMultitoolLib

// Load config from the path in $CARDANO_MULTITOOL_CONFIG
let config = try await MultitoolConfig.load()

// Obtain a ChainContext (Blockfrost, Koios, Ogmios, or local node socket)
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
| `offline` | No network provider — for air-gapped use only |

## Loading config programmatically

You can construct a ``MultitoolConfig`` directly without a file:

```swift
import SwiftCardanoMultitoolLib
import SwiftCardanoChain

let config = MultitoolConfig(
    blockfrostProjectId: "mainnetXXXXXXXXXXXXXXXX",
    cardano: CardanoConfig(
        network: .mainnet,
        nodeSocketPath: "/run/cardano-node/node.socket"
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
import SwiftCardanoMultitoolLib
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
import SwiftCardanoMultitoolLib

@main
struct MyApp {
    static func main() async {
        await runApp()
    }
}
```

This is exactly what the `scm` binary does.
