# Sign

Off-chain signing operations — Ed25519, CIP-8, CIP-30, Catalyst voting, governance metadata.

## Overview

The `sign` command groups every off-chain / off-line signing operation `scm` exposes. It wraps the cardano-signer.js feature surface but is backed entirely by the native `swift-cardano-signer` library — no JavaScript runtime is required.

```bash
scm sign <subcommand> [options]
scm sign --help
```

Every subcommand shares the same output controls (via `SignerOutputOptions`):

| Output flag | Effect |
|-------------|--------|
| *(default)* | Plain text — just the signature / blob. |
| `--json` | Compact JSON envelope. |
| `--json-extended` | JSON with all derived fields (publicKey, signed hash, etc.). |
| `--include-secret` | Include the signing key in the JSON output (use with care). |
| `--out-file`, `-o` | Write the rendered output to a file. |

Payload input is also shared where it applies: `--data` (UTF-8), `--data-hex`, or `--data-file`.

## Subcommands

### default

Sign an arbitrary payload with a plain Ed25519 signing key.

```bash
scm sign default --data "hello" --secret-key payment.skey
scm sign default --data-hex 48656c6c6f --secret-key payment.skey --json-extended
scm sign default --data-file message.txt --secret-key payment.skey --out-file sig.txt
```

| Option | Description |
|--------|-------------|
| `--data` / `--data-hex` / `--data-file` | The payload (choose exactly one). |
| `--secret-key`, `-s` | Path to a `.skey` file or raw hex. |
| `--calidus` | Treat the signing key as a Calidus key and also emit the CIP-151 `calidus_id` (bech32). |

### cip8

Wrap a payload in a CIP-8 `COSE_Sign1` envelope bound to an address derived from the signing key.

```bash
scm sign cip8 --data "hello" --secret-key payment.skey
scm sign cip8 --data-hex 7b22... --secret-key stake.skey --testnet --json-extended
```

| Option | Description |
|--------|-------------|
| `--testnet` | Use the testnet network ID when deriving the signing address. |
| `--attach-cose-key` | Attach the verification key as a separate `COSE_Key` (CIP-30 shape). |

### cip30

Produce a CIP-30 `signData` response — equivalent to `cip8` with `--attach-cose-key` always on, suitable as a drop-in for a wallet's `signData(...)` return value.

```bash
scm sign cip30 --data "hello" --secret-key wallet.skey
scm sign cip30 --data-hex 7b22... --secret-key stake.skey --testnet --json-extended
```

### cip36

Build a CIP-36 Catalyst voting registration (or, with `--deregister`, a deregistration blob).

```bash
# Registration
scm sign cip36 \
  --payment-address addr1... \
  --vote-public-key vote.vkey \
  --secret-key stake.skey

# Deregistration
scm sign cip36 --deregister --secret-key stake.skey
```

| Option | Description |
|--------|-------------|
| `--payment-address` | Rewards address (bech32 or path to `.addr`). Required for registration. |
| `--vote-public-key` | Voting public key — repeat for multi-delegation. Accepts a `.vkey` path or hex. |
| `--vote-weight` | Voting weight per `--vote-public-key` (must match count when more than one). |
| `--vote-purpose` | Voting purpose discriminator. `0` = Catalyst (default). |
| `--nonce` | Monotonic nonce. Defaults to the current mainnet slot height. |
| `--deregister` | Build a deregistration blob instead of a registration. |

### cip88

Build a CIP-88 / CIP-151 Calidus pool-key registration.

```bash
scm sign cip88 \
  --calidus-public-key calidus.vkey \
  --secret-key pool.cold.skey
```

| Option | Description |
|--------|-------------|
| `--calidus-public-key` | Calidus public key (`.vkey` path or raw hex). |
| `--secret-key`, `-s` | Pool cold signing key — `.skey` path or raw hex. |
| `--nonce` | Monotonic nonce. Defaults to current mainnet slot height. |
| `--meta-json` | Emit cardano-cli `detailed-schema` JSON metadata (for `--metadata-json-file`) instead of CBOR-hex auxdata. |

### cip100

Sign a CIP-100 governance metadata JSON-LD document and append an author witness.

```bash
scm sign cip100 \
  --data-file proposal.jsonld \
  --secret-key author.skey \
  --author-name "Alice"
```

| Option | Description |
|--------|-------------|
| `--data` / `--data-file` | The JSON-LD document. |
| `--secret-key`, `-s` | Author signing key (`.skey` path or raw hex). |
| `--author-name` | Display name attached to the author entry. |

## Notes

- The plain `default` mode is content-agnostic — it does not bind the signature to any address or context. Prefer `cip8` / `cip30` for wallet-facing messages where the verifier needs to confirm the signer's address.
- Calidus support (`--calidus` on `default`, plus the dedicated `cip88` subcommand) emits the bech32 `calidus_id` defined by CIP-151.
- See <doc:VerifyCommand> for the corresponding verification operations.
