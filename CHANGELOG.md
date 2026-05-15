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
