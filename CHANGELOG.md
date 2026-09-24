## 0.15.0 (2026-09-24)

### Feat

- publish scm as a multi-arch container image

## 0.14.2 (2026-09-24)

## 0.14.1 (2026-09-24)

## 0.14.0 (2026-09-23)

### Feat

- validate certificate, vote and proposal redeemers, and hash bodies faithfully

## 0.13.2 (2026-09-23)

### Fix

- pick up reward redeemer support and Plutus Data equality fix from uplc 0.5.0

## 0.13.1 (2026-09-23)

### Fix

- label the redeemer table as remaining budget and mark unmeasured budgets
- skip gpg tests unless gpg actually works, so CI cannot hang

## 0.13.0 (2026-09-23)

### Feat

- add --yes to protect decrypt for non-interactive use
- honor CARDANO_MULTITOOL_DECRYPT_PASSWORD in protect decrypt
- suggest .json files in envelope file prompts

### Fix

- read the stored envelope in protect encrypt and decrypt
- drop the plaintext cborHex when encrypting a signing key

## 0.12.0 (2026-09-22)

### Feat

- accept versatile address inputs when building transactions
- add yaci devkit chain context and devkit mode

## 0.11.0 (2026-09-16)

### Feat

- use the file path prompt for file and directory selection across commands
- add file path prompt with completion for file selection
- add hash and text-view commands

### Fix

- honor --tool in build and generate wizards
- honor --tool in hash command wizards
- use invalidHereAfter for policy time locks and reject mismatched policy IDs (core 0.5.2)

## 0.10.3 (2026-09-16)

### Fix

- require swift-cardano-utils 0.5.6 (cardano-cli query stake-pools JSON)
- detect pool registration status per pool and never guess the deposit

## 0.10.2 (2026-09-16)

### Fix

- register pools from pool.json hashes when key files are unavailable

## 0.10.1 (2026-09-16)

### Feat

- fetch registered pool params for pool-json and pool-registration

### Fix

- require swift-cardano-chain 0.7.4 (Koios pool metadata mismatch, relay ports)
- pass absolute paths to cardano-cli

## 0.9.1 (2026-09-16)

### Fix

- allow pool retirement without a pool.json via --pool-operator and --cold-signing-key

## 0.9.0 (2026-09-14)

### Feat

- accept enterprise <name>.addr files wherever a payment address name is given

### Fix

- require swift-cardano-chain 0.7.3 (Koios protocol parameters crash)
- bump swift-cardano-core to 0.5.1 to fix redeemer decode crash

## 0.8.3 (2026-09-03)

### Fix

- correct zero ADA balances when using the Koios backend

## 0.8.2 (2026-06-25)

### Fix

- make CODESIGN_IDENTITY lazy so release-universal builds without it

## 0.8.1 (2026-06-25)

### Feat

- config init autodetects node socket (CARDANO_NODE_SOCKET_PATH) and share/<network> config+topology; dry-run no longer requires a config path

### Fix

- use fflush(nil) so Submit builds on Linux (global 'stdout' var is not concurrency-safe under strict concurrency)
- rewards-withdraw usage example shows --stake-address (not the nonexistent --stake-address-name)

## 0.8.0 (2026-06-25)

### Feat

- add 'query stake-pool --strict' for off-chain metadata verification (lenient by default)
- add send ada command (amount denominated in ADA)
- add config node-config, genesis, and topology subcommands

### Fix

- config show degrades gracefully in non-interactive sessions instead of fatalError on the wizard prompt
- sign cip36 accepts the extended .vote.vkey from generate vote-key (unwrap 64-byte key to 32-byte voting key)
- key-rotation builds sub-commands via parse([]) so opcert generation runs (was: unset-arg trap, no opcert)
- build stake-address via cli uses stake-address builder (not payment) and avoids double-write
- absolutize pool.json key paths and build-address vkey paths passed to cardano-cli
- absolutize file paths passed to cardano-cli (cli runs in cardano.working_dir, not user cwd)
- node opcert generation — JSON-safe KES expire date + use temp file path (not file:// URL)
- match witness output file by full name (transaction witness crashed on force-unwrap)
- don't reject send-all sweep on zero fee-payment change output
- make pool.json round-trip robust (optional FilePath keys, ISO-8601 dates)
- sign pool registration with each owner's stake key (MissingVKeyWitnessesUTXOW)
- parse always-abstain/always-no-confidence for --drep arguments
- always surface transaction submission failures (emit to stderr before exit)
- correct asset mint/burn usage examples to use --amount
- add --cold-signing-key to committee auth/resign certificate commands
- add --drep-signing-key to update and unregister drep commands
- join credential file paths with a separator in argument parsers
- add --drep-signing-key and resolve .drep.vkey credential file path
- don't fail delegation when on-chain pool-list check errors
- load Conway Unregister cert in stake deregistration tx flow
- lovelace amount units, payment-address-only addr file, cli stake addr build, blockfrost 404 empty
- load Conway Register cert and use --signing-keys in certificate tx flow
- auto-proceed transaction submission confirmations when non-interactive
- gate certificate prompts behind isInteractiveSession to avoid non-interactive crashes
- remove leftover try after path-helper refactor
- route query/governance/transaction prompts through isInteractiveSession to avoid non-interactive crashes
- tolerate relative paths in path-styled output via pathComponent helper
- replace non-interactive prompt crashes with clean errors and relative-path support
- resolve tool and apply key-gen defaults so generate/build don't crash non-interactively
- accept advertised --tool value and correct certificate usage strings
- ignore empty blockfrost/koios config values and emit placeholders
- avoid spurious offline fallback and duplicate lite-mode retry

### Refactor

- rename config show/set type 'node-config' to 'node'
- unify config show/set with a type argument and wizards

## 0.7.0 (2026-06-13)

### Feat

- derive DRep and policy mnemonic keys via swift-cardano-signer

## 0.6.0 (2026-06-12)

### Feat

- support message encryption on Linux via swift-crypto

### Fix

- correct misspelled --block-poducer flag to --block-producer
- replace Apple-only APIs with cross-platform equivalents
- guard Apple-only imports for Linux compatibility
- update dependencies

## 0.5.0 (2026-06-09)

### Feat

- add Query PoolCalidusKey command
- add Governance CIP-129 encode/decode and Canonize commands
- add Byron, Calidus, BIP-32 derived, Ed25519, and CIP-36 vote keys
- add Sign and Verify commands with CIP-8/30/36/88/100 subcommands
- add SignerUtils shared signing helpers
- Add VoteUtils for governance voting logic and MintBurnUtils tests

### Fix

- parse govActionDeposits keys via GovActionID(argument:)
- align asset usage strings and error messages with --fee-payment-address
- expose singular --message and --witness-file CLI flags
- make PoolJSON --overwrite a proper boolean flag
- register transaction id subcommand as txid with id alias
- correct rewards-wirhdraw enum rawValue typo
- dispatch StakePoolDeregistrationCertificate for pool-deregistration
- add DRep key generation
- add more query commands

## 0.4.2 (2026-05-31)

### Feat

- **generate**: add mnemonics method to payment-address-only

### Fix

- update dependencies to remove OpenSSL linking error
- add more tests
- **certs**: resolve $adahandle in pool-registration cert
- **certs**: resolve $adahandle in pool-deregistration cert
- **certs**: resolve $adahandle in resign-committee-cold cert
- **certs**: resolve $adahandle in update-drep cert
- **certs**: resolve $adahandle in unregister-drep cert
- **certs**: resolve $adahandle in register-drep cert
- **certs**: resolve $adahandle in move-instantaneous-rewards cert
- **certs**: resolve $adahandle in genesis-key-delegation cert
- **certs**: resolve $adahandle in auth-committee-hot cert
- **certs**: resolve $adahandle in vote-register-delegate cert
- **certs**: resolve $adahandle in stake-vote-register-delegate cert
- **certs**: resolve $adahandle in stake-vote-delegate cert
- **certs**: resolve $adahandle in stake-register-delegate cert
- **certs**: resolve $adahandle in vote-delegation cert
- **certs**: resolve $adahandle in stake-address-deregistration cert
- **certs**: resolve $adahandle in stake-address-delegation cert
- **certs**: resolve $adahandle in stake-address-registration cert
- **rewards-withdraw**: resolve $adahandle before dereferencing addresses
- **send**: resolve $adahandle before dereferencing destination/fee address

### Refactor

- **adahandle**: add resolveStakeAdaHandle helper for stake-side arguments
- **generate**: route mnemonic keygen through wallet pkg; add hybrid payment coverage

## 0.3.1 (2026-05-29)

### Fix

- regenerate Version.swift after 0.3.0 bump

## 0.3.0 (2026-05-29)

### Feat

- widen money/slot/epoch types for core 0.4.x
- drop Lib suffix from library product

### Fix

- refactor transaction validation and error handling

## 0.2.0 (2026-05-15)

### Feat

- implement `install` command for Cardano ecosystem tools and update dependencies

### Fix

- improve swift version compatibility
- add more chain context
- improve validate display and use Utils struct
- Implement the `query stake-pool` command, update `query tip` configuration with usage and discussion, and refactor `query address` to use an argument.
- add generate pool json wizardry
- updated packages and new commands
- Implement node KES key generation command, add SwiftKES dependency, and update SwiftCardanoCore.
- latest changes
- add config show and select
- rename and add more commands

### Refactor

- add some better text and rename for easier use
- Replace boolean `useCardanoCLI` flag with a `tool` option for selecting address building method.
- Replace boolean `useCardanoCLI` flag with a `tool` option for selecting the key generation method in VRF and payment/stake address subcommands.
- Replace `useCardanoCLI` flag with a generic `tool` option and `getToolToUse()` method for key generation.
