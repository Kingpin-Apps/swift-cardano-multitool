# Text View

Decode text envelope files into a readable view.

## Overview

The `text-view` command reads a text envelope file (the `type` / `description` / `cborHex` JSON written by scm and cardano-cli) and shows its contents field by field. It is a friendlier `cardano-cli text-view decode-cbor`: instead of a CBOR dump you get named fields plus identifiers derived from them. Alias: `view`.

```bash
scm text-view <file> [options]
scm text-view --in-file <file> [options]
```

| Option | Description |
|--------|-------------|
| `<file>` / `--in-file`, `-i` | The file to decode. |
| `--output-cbor` | Also show the CBOR hex and indented CBOR diagnostic notation. |
| `--json` | Output JSON instead of formatted text. |
| `--show-secret` | Show signing key material (Bech32 and hex). Hidden by default. |
| `--out-file`, `-o` | Write the output to a file instead of the terminal. |

Run `scm text-view` without a file in an interactive terminal to pick one from the current directory.

## Supported files

| File | Shown |
|------|-------|
| Payment, stake, pool cold, VRF, KES, DRep, committee and genesis keys (normal and extended) | Bech32 and hex key, key hash, and the pool ID, DRep ID (CIP-129 and CIP-105), committee ID or address it identifies. Signing keys show the derived verification key. |
| Certificates | The certificate kind and its fields: stake credentials and addresses, pool IDs, DReps, deposits, anchors, and full pool parameters (pledge, cost, margin, reward account, owners, relays, metadata). |
| Operational certificates and issue counters | KES key, issue counter, KES period, cold key and pool ID. |
| Vote files | Each voter, governance action ID, vote and anchor. |
| Governance proposals | Deposit, return address, anchor and action details. |
| Transactions and transaction bodies | Transaction ID, fee, validity interval, inputs, outputs and assets, mint, certificates, withdrawals, votes, proposals, required signers and witnesses. |
| Transaction witnesses | Verification key, key hash and signature. |
| Plutus scripts | Language version, size and script hash. |
| Native script JSON | Script hash and the script structure. |

Any other text envelope is shown as a generic CBOR tree with a note. Encrypted files (from `scm protect encrypt`) are reported as encrypted; decrypt them first to view their contents.

Addresses derived from keys and credentials use the network of the active configuration and are left out when no configuration is available.

## Examples

```bash
scm text-view alice.payment.vkey
scm text-view pool.cert
scm text-view node.opcert --output-cbor
scm text-view tx.signed --json --out-file tx.json
scm text-view alice.payment.skey --show-secret
```

## Notes

- See <doc:HashCommand> to compute individual hashes for use in other commands.
- For a transaction-focused view with explorer links, see `scm transaction inspect` in <doc:TransactionCommand>.
