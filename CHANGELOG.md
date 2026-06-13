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
