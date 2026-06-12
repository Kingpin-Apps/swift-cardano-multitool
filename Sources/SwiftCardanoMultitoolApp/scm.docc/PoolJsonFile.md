# The pool.json File

Understand the per-pool registry file that drives stake pool operations.

## Overview

A `pool.json` file (named `<poolName>.pool.json`) is the central registry for a stake pool managed with `scm`. It stores everything `scm` needs to know about one pool in a single place:

- **Pool registration parameters** — pledge, cost, margin, owners, rewards owner, and relays.
- **Pool metadata** — the display name, ticker, description, homepage, and metadata URLs shown in wallets.
- **Pool IDs** — the pool ID in both hex and bech32 form.
- **Key file locations** — paths to the cold, VRF, KES, payment, and stake key files, plus the operational certificate and counter files.
- **Registration history** — details of the last registration or deregistration performed through `scm`.

The file stores *paths* to key files, never key material itself. Still, it reveals where your signing keys live, so treat it as operationally sensitive.

Several pool-related commands cannot run without it (or fall back to it when other inputs are missing):

| Command | How it uses pool.json |
|---------|----------------------|
| `scm certificate pool-registration` | Loads parameters, metadata, keys, and owners to build the registration certificate; writes registration details back into the file on success. |
| `scm certificate pool-deregistration` | Loads the pool keys to build the retirement certificate; records the deregistration in the file. |
| `scm query stake-pool` | Resolves the pool ID to query on-chain pool state. |
| `scm query kes-period-info` | Locates the latest operational certificate (`op_cert`) to check KES validity. |
| `scm query leadership-schedule` | Reads the VRF signing key path (`vrf_skey`) and pool ID (`id_bech`) to compute the slot leader schedule. |

These commands accept the file either via `--pool-name <name>` (which looks for `<name>.pool.json` in the current working directory) or via an explicit `--pool-json <path>`. Run interactively, they prompt you to select a file instead.

## Creating a pool.json file

Generate one interactively with:

```bash
scm generate pool-json --pool-name mypool
```

The wizard walks through pool parameters, metadata, relays, and key files, and writes `mypool.pool.json` to the current directory. When key files follow the standard naming scheme (below) and live in the current directory, the wizard finds and offers them automatically. If a cold verification key is available, the pool ID is derived and saved to `<poolName>.pool.id` (hex) and `<poolName>.pool.id-bech` (bech32) alongside the JSON file.

The `pool-registration` and `pool-deregistration` certificate commands also offer to create a template pool.json if none is found for the given pool name.

## Standard file naming

`scm` resolves missing file paths from the pool name, looking in the current directory:

| File | Purpose |
|------|---------|
| `<name>.cold.vkey` / `<name>.cold.skey` | Cold (node) key pair |
| `<name>.cold.counter` | Issue counter for operational certificates |
| `<name>.vrf.vkey` / `<name>.vrf.skey` | VRF key pair |
| `<name>.kes-xxx.vkey` / `<name>.kes-xxx.skey` | KES key pair (highest `xxx` wins) |
| `<name>.node-xxx.opcert` | Operational certificate (highest `xxx` wins) |
| `<name>.kes.counter` / `<name>.kes.counter-next` | KES rotation counters |
| `<name>.kes-expire.json` | KES expiry information |
| `<name>.metadata.json` | Pool metadata file (hosted at `meta_url`) |
| `<name>.pool.id` / `<name>.pool.id-bech` | Pool ID in hex / bech32 |

## Field reference

Keys use snake_case. File-path fields may point anywhere; relative paths are resolved against the current working directory.

| Field | Description |
|-------|-------------|
| `name` | Pool name used for file naming (max 50 chars). |
| `owners` | Array of pool owners. Each has `name`, `witness` (`local` or `external`), `stake_vkey`, `stake_skey`. |
| `rewards_owner` | Rewards destination: `name`, `stake_vkey`, `stake_skey`. May be the same as an owner. |
| `pledge` | Pledge in lovelace. |
| `cost` | Fixed cost per epoch in lovelace (minimum 170 ADA). |
| `margin` | Margin as a decimal (`0.10` = 10%, must be ≤ `1.00`). |
| `relays` | Array of relays: `type` (`ip` or `dns`), `host`, `port`, `host_type` (`ipv4`, `ipv6`, `single`, `multi`). |
| `meta_name` | Display name shown in wallets (max 50 chars). |
| `meta_description` | Description shown in wallets (max 255 chars). |
| `meta_ticker` | Ticker (3–5 chars). |
| `meta_homepage` | Pool homepage URL. |
| `meta_url` | URL where the metadata JSON is hosted (max 64 chars). |
| `extended_meta_url` | Optional extended metadata URL. |
| `metadata_hash` | Hash of the hosted metadata file. |
| `id_hex` / `id_bech` | Pool ID in hex / bech32. |
| `id_hex_file` / `id_bech_file` | Paths to the pool ID files. |
| `cold_vkey` / `cold_skey` / `node_counter` | Cold key pair and opcert issue counter paths. |
| `vrf_vkey` / `vrf_skey` | VRF key pair paths. |
| `kes_vkey` / `kes_skey` | Current KES key pair paths. |
| `kes_counter` / `kes_counter_next` / `kes_expire_json` | KES rotation bookkeeping paths. |
| `op_cert` | Current operational certificate path. |
| `payment_addr` / `payment_vkey` / `payment_skey` | Pool payment address and key paths (pays fees and deposits). |
| `stake_addr` / `stake_vkey` / `stake_skey` | Pool stake address and key paths. |
| `registration` / `deregistration` | Records of the last (de)registration performed by `scm`. Managed automatically. |

## Example

```json
{
  "name": "mypool",
  "owners": [
    {
      "name": "owner1",
      "witness": "local",
      "stake_vkey": "owner1.stake.vkey",
      "stake_skey": "owner1.stake.skey"
    }
  ],
  "rewards_owner": {
    "name": "owner1",
    "stake_vkey": "owner1.stake.vkey",
    "stake_skey": "owner1.stake.skey"
  },
  "pledge": 100000000000,
  "cost": 170000000,
  "margin": 0.05,
  "relays": [
    {
      "type": "dns",
      "host": "relay1.mypool.com",
      "port": "3001",
      "host_type": "single"
    }
  ],
  "meta_name": "My Stake Pool",
  "meta_description": "A reliable Cardano stake pool.",
  "meta_ticker": "MYPL",
  "meta_homepage": "https://mypool.com",
  "meta_url": "https://mypool.com/mypool.metadata.json",
  "id_bech": "pool1...",
  "id_hex": "abcdef...",
  "cold_vkey": "mypool.cold.vkey",
  "cold_skey": "mypool.cold.skey",
  "node_counter": "mypool.cold.counter",
  "vrf_vkey": "mypool.vrf.vkey",
  "vrf_skey": "mypool.vrf.skey",
  "kes_vkey": "mypool.kes-001.vkey",
  "kes_skey": "mypool.kes-001.skey",
  "op_cert": "mypool.node-001.opcert"
}
```

## Editing the file

The file is plain JSON and safe to edit by hand — for example to update relays, adjust the pledge before re-registration, or correct a file path after moving keys. Fields like `registration`, the KES key paths, and `op_cert` are maintained by `scm` commands (`certificate pool-registration`, `generate key-rotation`, `generate node-operational-certificate`) and are best left to them.

> Important: Changing values in pool.json does not change anything on-chain. After editing registration parameters or metadata, submit a new registration certificate with `scm certificate pool-registration` for the changes to take effect.
