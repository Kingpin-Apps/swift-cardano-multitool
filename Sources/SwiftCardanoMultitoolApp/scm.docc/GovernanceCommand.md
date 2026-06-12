# Governance

Cast votes and submit Conway-era governance proposals.

## Overview

The `governance` command groups the full set of Conway-era on-chain governance operations: casting votes, creating each variety of governance action, submitting pre-built actions, and a pair of utility commands for CIP-100 / CIP-129 metadata identifiers.

```bash
scm governance <subcommand> [options]
scm governance --help
```

Each create-style subcommand can run with `--generate-only` to emit just a `.action` file (no transaction). `submit-action` then takes one or more such files and builds + signs + submits the proposal transaction. Any subcommand that accepts an anchor downloads and blake2b-256 hash-verifies the CIP-100 document before broadcasting — disable with `--skip-anchor-verify`.

## Voting

### vote

Cast a single Conway-era vote. The voter role (DRep / SPO / CC hot) is inferred from the voter vkey's file extension; override with `--voter-role`.

```bash
scm governance vote gov_action1xyz... yes \
  --voter-vkey-file myDRep.drep.vkey \
  --fee-payment-address owner.payment \
  --submit
```

**Positional arguments:**

| Argument | Description |
|----------|-------------|
| `<govActionId>` | Governance action ID: bech32 (`gov_action1…`), hex, or `txHash#index`. |
| `<choice>` | Vote choice: `yes`, `no`, or `abstain`. |

**Key options:**

| Option | Description |
|--------|-------------|
| `--voter-vkey-file` | Voter verification key (`.drep.vkey` / `.node.vkey` / `.cc-hot.vkey`). |
| `--voter-role` | Override the voter role inferred from the vkey filename. |
| `--anchor-url` | Optional CIP-100 vote-rationale anchor URL. |
| `--anchor-hash` | 64-hex anchor blake2b-256 hash (required if `--anchor-url` is set). |
| `--skip-anchor-verify` | Skip download + blake2b + CIP-100 verification of the anchor. |
| `--ttl-extra` / `--ttl-override` | TTL controls (default: tip + 500 slots). |

## Governance actions

All create-style subcommands accept the shared anchor (`--anchor-url`, `--anchor-hash`), deposit (`--deposit`), `--deposit-return-stake-address`, and `--generate-only` flags via `SharedGovernanceActionOptions`.

### info-action

Build and submit a Conway info-action — a metadata-only proposal with no on-chain effect.

```bash
scm governance info-action \
  --anchor-url ipfs://... \
  --anchor-hash <64-hex> \
  --deposit-return-stake-address owner.stake \
  --fee-payment-address owner.payment \
  --submit
```

### treasury-withdrawal

Withdraw lovelace from the treasury to one or more stake addresses. `--withdrawal` is repeatable.

```bash
scm governance treasury-withdrawal \
  --withdrawal stake1...:1000000000 \
  --anchor-url ipfs://... --anchor-hash <64-hex> \
  --deposit-return-stake-address owner.stake \
  --fee-payment-address owner.payment \
  --submit
```

| Option | Description |
|--------|-------------|
| `--withdrawal` | `<stakeAddrOrFile>:<lovelaces>` — repeat for multiple recipients. |
| `--guardrails-script-hash` | 56-hex hash — required when the constitution has a guardrails script. |

### no-confidence

Submit a no-confidence motion against the current constitutional committee.

```bash
scm governance no-confidence \
  --anchor-url ipfs://... --anchor-hash <64-hex> \
  --prev-action-id gov_action1... \
  --deposit-return-stake-address owner.stake \
  --fee-payment-address owner.payment \
  --submit
```

`--prev-action-id` is the most recent enacted Committee action. It is required on the SwiftCardano path and optional when `--use-cardano-cli` is set (the CLI infers it from gov-state).

### new-constitution

Propose a new constitution document.

### hard-fork-initiation

Propose advancing the protocol to a new major version. Pass `--major <version>` and the previous hard-fork action ID via `--prev-action-id`.

### update-committee

Propose adding or removing committee members and updating the voting threshold.

### parameter-change

Propose changes to one or more protocol parameters.

### submit-action

Submit one or more previously generated `.action` files in a single transaction. Deposit and return-stake-address are read directly from each action file.

```bash
# Single action
scm governance submit-action \
  --action-file mywallet_info_20260604.action \
  --fee-payment-address mywallet.payment --submit

# Multiple actions in one tx
scm governance submit-action \
  --action-file proposal-a.action \
  --action-file proposal-b.action \
  --fee-payment-address owner.payment --submit
```

## Utilities

### canonize

Compute the URDNA2015 canonical form and blake2b-256 hash of a CIP-100 JSON-LD document — useful when preparing or auditing an anchor hash.

```bash
scm governance canonize --data-file proposal.jsonld
scm governance canonize --data-file proposal.jsonld --json-extended
```

### cip129 encode / cip129 decode

Encode or decode CIP-129 / CIP-151 bech32 governance identifiers (`drep`, `cc_cold`, `cc_hot`, `calidus`).

```bash
# Encode a 28-byte key hash
scm governance cip129 encode --prefix drep --key-hash <56-hex>
scm governance cip129 encode --prefix drep --key-hash <56-hex> --script

# Decode a bech32 ID
scm governance cip129 decode --id drep1ygx...
```

| Option | Description |
|--------|-------------|
| `--prefix` | One of `drep`, `ccCold`, `ccHot`, `calidus`. |
| `--key-hash` | 28-byte Blake2b-224 key hash as hex (56 chars). |
| `--script` | Encode as a script-form ID (not valid for `calidus`). |

## Notes

- A `.action` file produced with `--generate-only` is portable: it can be reviewed offline, signed under a separate identity, and submitted later with `submit-action`.
- Anchors are downloaded over HTTP(S) or IPFS — if the URL is unreachable, pass `--skip-anchor-verify` (at your own risk) or pre-fetch the document and rebuild the action against a local path.
- See <doc:SignCommand> for producing the CIP-100 author witnesses an anchor references, and <doc:CertificatesCommand> for the underlying DRep / CC certificates.
