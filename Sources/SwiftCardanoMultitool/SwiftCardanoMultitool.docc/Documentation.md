# ``SwiftCardanoMultitool``

A Swift library for building Cardano tooling — configuration, chain queries, transaction utilities, and key management.

## Overview

`SwiftCardanoMultitool` is the library target that backs the `scm` CLI. It exposes a public API for embedding Cardano operations into your own Swift executable or service:

- **Configuration** — load ``MultitoolConfig`` from JSON, TOML, or YAML; resolve network settings, API keys, and node paths at runtime.
- **Chain context** — obtain a live `ChainContext` for querying UTxOs, protocol parameters, and chain state via Blockfrost, Koios, Ogmios, or a local node socket.
- **Utility functions** — lovelace ↔ ADA conversion, number formatting, operational certificate validation, KES period checks, file I/O helpers, and more.
- **Full TUI** — call ``runApp()`` to run the complete interactive `scm` terminal UI inside your own executable.

> **Looking for end-user docs?**
> If you want to know how to *use the `scm` CLI tool*, see the `SwiftCardanoMultitool` module documentation (the `scm.docc` catalog), which covers installation, configuration, and every command and subcommand.

## Topics

### Embedding the application

- ``runApp()``

### Configuration

- ``MultitoolConfig``
- ``TokenMetaServerURLs``
- ``AdaHandlePolicyIds``

### Chain context

- <doc:ChainContextGuide>

### Enumerations

- ``Mode``
- ``Tool``
- ``KeyGenMethod``
- ``TransactionType``
- ``WitnessType``
- ``SigningMethod``
- ``SPORelayType``

### Utilities

- ``OpCertUtils``
- ``DateUtils``
- ``FileUtils``
- ``PasswordUtils``

### Errors

- ``SwiftCardanoMultitoolError``
- ``AddressInfoError``
