## 0.4.1 (2026-05-30)

### Feat

- **generate**: add mnemonics method to payment-address-only

### Fix

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
