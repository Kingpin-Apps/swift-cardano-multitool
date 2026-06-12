# Verify

Verify signatures and signed metadata.

## Overview

The `verify` command is the mirror of `scm sign` — it validates signatures produced by `scm sign …` and any compatible cardano-signer output. The process exits with status `0` on a valid signature and a non-zero status otherwise, so `verify` composes cleanly with shell pipelines and CI checks.

```bash
scm verify <subcommand> [options]
scm verify --help
```

Every subcommand shares the same output controls as `sign`:

| Output flag | Effect |
|-------------|--------|
| *(default)* | Plain text — `true` / `false`. |
| `--json` | Compact JSON envelope. |
| `--json-extended` | JSON with all derived fields. |
| `--out-file`, `-o` | Write the rendered output to a file. |

## Subcommands

### default

Verify a detached Ed25519 signature against a payload and verification key.

```bash
scm verify default \
  --data "hello" \
  --public-key payment.vkey \
  --signature 8a5fd6...
```

| Option | Description |
|--------|-------------|
| `--data` / `--data-hex` / `--data-file` | The original payload (choose exactly one). |
| `--public-key`, `-p` | Verification key — `.vkey` path or raw hex. |
| `--signature` | 64-byte Ed25519 signature as hex. |

### cip8

Verify a CIP-8 `COSE_Sign1` signed message.

```bash
scm verify cip8 \
  --cose-sign1 84582a... \
  --cose-key a401...
```

| Option | Description |
|--------|-------------|
| `--cose-sign1` | Hex-encoded `COSE_Sign1` message. |
| `--cose-key` | Hex-encoded `COSE_Key` — optional when the key is embedded in the message. |

### cip30

Verify a CIP-30 `signData` response. The `COSE_Key` is required since CIP-30 separates it from the `COSE_Sign1` message.

```bash
scm verify cip30 \
  --cose-sign1 84582a... \
  --cose-key a401...
```

### cip100

Verify every author witness signature in a CIP-100 governance metadata document. Returns success only if **all** author witnesses validate.

```bash
scm verify cip100 --data-file proposal-signed.jsonld
scm verify cip100 --data-file proposal-signed.jsonld --json-extended
```

| Option | Description |
|--------|-------------|
| `--data` / `--data-file` | The signed JSON-LD document. |

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | Signature is valid. |
| non-zero | Signature is invalid, malformed, or required inputs are missing. |

## Notes

- Pair `verify` with `sign` for round-trip tests in CI — e.g. signing a known payload and verifying it should always return `true`.
- For CIP-100, the `--json-extended` output enumerates each author witness's result individually, which is useful when only a subset of authors are expected to have signed.
- See <doc:SignCommand> for producing the signatures verified here.
