# Hash

Compute hashes and IDs of keys, scripts, metadata, anchor data and genesis files.

## Overview

The `hash` command computes the values passed to the various `--*-hash` arguments of other commands. It gathers cardano-cli's hashing commands in one place and uses the same flag names:

| cardano-cli | scm |
|-------------|-----|
| `address key-hash` | `scm hash payment-key` |
| `stake-address key-hash` | `scm hash stake-key` |
| `governance drep id` | `scm hash drep-key` |
| `governance committee key-hash` | `scm hash committee-key` |
| `stake-pool id` | `scm hash pool-id` |
| `node key-hash-VRF` | `scm hash vrf-key` |
| `genesis key-hash` | `scm hash genesis-key` |
| `hash anchor-data` | `scm hash anchor-data` |
| `governance drep metadata-hash` | `scm hash drep-metadata` |
| `stake-pool metadata-hash` | `scm hash pool-metadata` |
| `hash script`, `transaction policyid` | `scm hash script` (alias `policy-id`) |
| `hash genesis-file`, `genesis hash` | `scm hash genesis-file` |

Transaction IDs and script data hashes are under `scm transaction id` and `scm transaction hash-script-data` (see <doc:TransactionCommand>).

```bash
scm hash <subcommand> [options]
scm hash --help
```

Every subcommand shares these options:

| Option | Description |
|--------|-------------|
| `--tool`, `-t` | `swift-cardano` or `cardano-cli`. Prompts (or follows `CARDANO_MULTITOOL_USE_CARDANO_CLI` / `CARDANO_MULTITOOL_USE_SWIFT_CARDANO`) when omitted. |
| `--out-file`, `-o` | Also write the hash to a file. |

When standard output is a terminal, each command shows the tool it uses, what is being hashed (the input, its type and size), how the result is produced (for example, blake2b-224 of the 32-byte public key into a 28-byte key hash), and then the result with any other formats of it, such as the CIP-105 and CIP-129 DRep IDs:

```
Using SwiftCardano to compute the Payment Key Hash

🔎 Info
  Reading the payment credential from an address

  Details:
   ▸ Address: addr1v9dj7z3r5k96dqk8kjre7kzhlzete4crejyl3hm754a3dlss0ue7p
   ▸ Address type: Enterprise address (Mainnet)
   ▸ Payment credential: Key hash
   ▸ Method: No hashing needed: the address stores the 28-byte payment key hash

Payment Key Hash: 5b2f0a23a58ba682c7b4879f5857f8b2bcd703cc89f8df7ea57b16fe

✅  Success
  Payment Key Hash computed.
```

When output is piped, only the hash is printed, so it can be captured:

```bash
POLICY_ID=$(scm hash script --script-file myPolicy.policy.script)
```

Run a subcommand without its input in an interactive terminal to be walked through it.

## Subcommands

### payment-key

Print the hash of a payment verification key. Alias: `address-key`.

```bash
scm hash payment-key --payment-verification-key-file alice.payment.vkey
scm hash payment-key --payment-verification-key addr_vk1...
scm hash payment-key --address-name alice
scm hash payment-key --address addr1v9dj7z3r5k96dqk8kjre7kzhlzete4crejyl3hm754a3dlss0ue7p
```

| Option | Description |
|--------|-------------|
| `--payment-verification-key` | Bech32 (`addr_vk1…`, `addr_xvk1…`) or hex key. |
| `--payment-verification-key-file`, `-f` | Verification key file. |
| `--address-name`, `-a` | Hashes `<name>.payment.vkey` in the current directory. |
| `--address` | Reads the payment credential from an address: Bech32 (`addr1…`, `addr_test1…`), an address file, or an address name (`<name>.payment.addr` or `<name>.addr`). |

With `--address` no key is needed: the hash comes from the address itself. Base, enterprise and pointer addresses all carry a payment credential; for a script address the output is the script hash. cardano-cli has no equivalent command, so with `--tool cardano-cli` the address bytes come from `cardano-cli address info`.

Extended keys are hashed over their 32-byte public key, so a key and its extended form give the same hash. Signing key files are rejected, and a key of another role (for example a DRep key) is hashed with a warning.

### stake-key

Print the hash of a stake verification key. Alias: `stake-address-key`.

```bash
scm hash stake-key --stake-verification-key-file alice.stake.vkey
scm hash stake-key --stake-verification-key stake_vk1...
scm hash stake-key --address-name alice
scm hash stake-key --stake-address stake1uyehkck0lajq8gr28t9uxnuvgcqrc6070x3k9r8048z8y5gh6ffgw
scm hash stake-key --stake-address addr1q...
```

| Option | Description |
|--------|-------------|
| `--stake-verification-key` | Bech32 (`stake_vk1…`, `stake_xvk1…`) or hex key. |
| `--stake-verification-key-file`, `-f` | Verification key file. |
| `--address-name`, `-a` | Hashes `<name>.stake.vkey` in the current directory. |
| `--stake-address` | Reads the stake credential from a stake address (`stake1…`) or a base payment address (`addr1q…`), an address file, or an address name (`<name>.stake.addr`, then the payment address files). |

Enterprise addresses have no stake credential, and pointer addresses only point to a stake registration, so both are rejected.

### drep-key

Print the key hash or ID of a DRep verification key. Alias: `drep-id`.

```bash
scm hash drep-key --drep-verification-key-file myDRep.drep.vkey
scm hash drep-key --drep-verification-key drep_vk1... --output-cip129
scm hash drep-key --drep-key-hash drep1... --output-hex
```

| Option | Description |
|--------|-------------|
| `--drep-verification-key` | Bech32 (`drep_vk1…`, `drep_xvk1…`) or hex key. |
| `--drep-verification-key-file`, `-f` | DRep verification key file. |
| `--drep-key-hash` | A key hash (hex) or DRep ID (CIP-105 or CIP-129), to convert between formats. |
| `--drep-name`, `-d` | Hashes `<name>.drep.vkey` in the current directory. |
| `--output-hex` / `--output-bech32` / `--output-cip129` | Key hash (default), CIP-105 DRep ID, or CIP-129 DRep ID. |

Unlike cardano-cli, which prints the CIP-105 ID by default, `scm hash drep-key` prints the key hash by default. In a terminal all three formats are shown.

### committee-key

Print the hash of a constitutional committee hot or cold verification key.

```bash
scm hash committee-key --verification-key-file cc.hot.vkey
scm hash committee-key --verification-key cc_cold_vk1...
```

| Option | Description |
|--------|-------------|
| `--verification-key` | Bech32 (`cc_hot_vk1…`, `cc_cold_vk1…` or the `xvk` forms) or hex key. |
| `--verification-key-file`, `-f` | Committee hot or cold verification key file. |

In a terminal the CIP-129 committee ID (`cc_hot1…` / `cc_cold1…`) is shown as well.

### pool-id

Print the pool ID of a stake pool cold verification key. Alias: `stake-pool-id`.

```bash
scm hash pool-id --cold-verification-key-file mypool.node.vkey
scm hash pool-id --stake-pool-verification-key pool_vk1... --output-hex
scm hash pool-id --pool-name mypool
```

| Option | Description |
|--------|-------------|
| `--stake-pool-verification-key` | Bech32 (`pool_vk1…`) or hex key. |
| `--stake-pool-verification-extended-key` | Bech32 (`pool_xvk1…`) or hex extended key. |
| `--cold-verification-key-file`, `-f` | Cold verification key file. |
| `--pool-name`, `-p` | Hashes `<name>.node.vkey` in the current directory. |
| `--output-bech32` / `--output-hex` | `pool1…` (default) or hex. |

### vrf-key

Print the hash of a node's VRF verification key, as registered in the pool parameters.

```bash
scm hash vrf-key --verification-key-file mypool.vrf.vkey
scm hash vrf-key --verification-key vrf_vk1...
```

| Option | Description |
|--------|-------------|
| `--verification-key` | Bech32 (`vrf_vk1…`) or hex key. |
| `--verification-key-file`, `-f` | VRF verification key file. |
| `--pool-name`, `-p` | Hashes `<name>.vrf.vkey` in the current directory. |

### genesis-key

Print the hash of a genesis, genesis delegate or genesis UTxO verification key.

```bash
scm hash genesis-key --verification-key-file genesis1.vkey
```

| Option | Description |
|--------|-------------|
| `--verification-key-file`, `-f` | The genesis verification key file. |

Apart from `payment-key` and `stake-key`, which hash any key with a warning (as cardano-cli does), the key commands reject key files of another type.

### anchor-data

Compute the blake2b-256 hash of governance anchor data, such as a CIP-100 document.

```bash
scm hash anchor-data --file-text drep.jsonld
scm hash anchor-data --url https://example.com/drep.jsonld --expected-hash 1a2b...
scm hash anchor-data --url ipfs://bafkrei...
scm hash anchor-data --text "Hello"
```

| Option | Description |
|--------|-------------|
| `--text` | Text to hash as UTF-8. |
| `--file-text` | UTF-8 text file to hash. |
| `--file-binary` | Any file, hashed byte for byte. |
| `--url` | HTTP(S) or `ipfs://` URL to download and hash. |
| `--expected-hash` | Compare with this hash and exit non-zero when they differ. |

Provide exactly one of `--text`, `--file-text`, `--file-binary` or `--url`. `ipfs://` URLs are fetched through the gateway in `IPFS_GATEWAY_URI`, defaulting to `https://ipfs.io/`.

### drep-metadata

Calculate the hash of a DRep metadata file, for the anchor of a DRep registration or update.

```bash
scm hash drep-metadata --drep-metadata-file myDRep.jsonld
scm hash drep-metadata --drep-metadata-url https://example.com/drep.jsonld --expected-hash 1a2b...
```

| Option | Description |
|--------|-------------|
| `--drep-metadata-file`, `-f` | The metadata file. Its exact bytes are hashed. |
| `--drep-metadata-url`, `-u` | HTTP(S) or `ipfs://` URL to download and hash. |
| `--expected-hash` | Compare with this hash and exit non-zero when they differ. |

### pool-metadata

Calculate the hash of a stake pool metadata file. Alias: `stake-pool-metadata`.

```bash
scm hash pool-metadata --pool-metadata-file mypool.metadata.json
scm hash pool-metadata --pool-metadata-url https://example.com/pool.json --expected-hash 1a2b...
```

| Option | Description |
|--------|-------------|
| `--pool-metadata-file`, `-f` | The metadata file. Its exact bytes are hashed. |
| `--pool-metadata-url`, `-u` | HTTP(S) or `ipfs://` URL to download and hash. |
| `--expected-hash` | Compare with this hash and exit non-zero when they differ. |

As in cardano-cli, the metadata is checked before hashing: at most 512 bytes, and a JSON object with string `name` (up to 50 characters), `description` (up to 255), `ticker` (3–5) and `homepage`.

### script

Compute the hash of a script. For a minting policy this is the policy ID. Alias: `policy-id`.

```bash
scm hash script --script-file myPolicy.policy.script
scm hash script --script-file validator.plutus
```

| Option | Description |
|--------|-------------|
| `--script-file`, `-s` | Native script JSON, or a `PlutusScriptV1`/`V2`/`V3` text envelope. |

Native script time locks follow cardano-cli: `"before"` means valid only before the slot (`invalid_hereafter`) and `"after"` means valid from the slot (`invalid_before`).

### genesis-file

Compute the hash of a genesis file, as used for the `*GenesisHash` entries of a node configuration.

```bash
scm hash genesis-file --genesis shelley-genesis.json
```

| Option | Description |
|--------|-------------|
| `--genesis`, `-g` | The genesis file. Its exact bytes are hashed. |

## Notes

- See <doc:TextViewCommand> to inspect key, script and certificate files, including their hashes and derived IDs.
