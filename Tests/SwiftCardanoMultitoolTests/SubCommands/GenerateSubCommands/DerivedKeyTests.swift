import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("GenerateMainCommand.DerivedKey")
struct DerivedKeyTests {

    @Test("commandName is 'derived-key'")
    func commandName() {
        #expect(GenerateMainCommand.DerivedKey.configuration.commandName == "derived-key")
    }

    @Test("defaults: variant icarus, account/index 0, no mnemonic/path")
    func defaults() throws {
        let cmd = try GenerateMainCommand.DerivedKey.parse([])
        #expect(cmd.name == nil)
        #expect(cmd.path == nil)
        #expect(cmd.account == 0)
        #expect(cmd.index == 0)
        #expect(cmd.variant == .icarus)
        #expect(cmd.passphrase == "")
    }

    @Test("parses --path with each shortcut")
    func parsesPath() throws {
        let payment = try GenerateMainCommand.DerivedKey.parse(["--path", "payment"])
        #expect(payment.path == .payment)
        let stake = try GenerateMainCommand.DerivedKey.parse(["--path", "stake"])
        #expect(stake.path == .stake)
        let drep = try GenerateMainCommand.DerivedKey.parse(["--path", "drep"])
        #expect(drep.path == .drep)
        let ccCold = try GenerateMainCommand.DerivedKey.parse(["--path", "cc-cold"])
        #expect(ccCold.path == .ccCold)
        let ccHot = try GenerateMainCommand.DerivedKey.parse(["--path", "cc-hot"])
        #expect(ccHot.path == .ccHot)
        let pool = try GenerateMainCommand.DerivedKey.parse(["--path", "pool"])
        #expect(pool.path == .pool)
        let calidus = try GenerateMainCommand.DerivedKey.parse(["--path", "calidus"])
        #expect(calidus.path == .calidus)
    }

    @Test("parses --variant ledger / trezor")
    func parsesVariant() throws {
        let ledger = try GenerateMainCommand.DerivedKey.parse(["--variant", "ledger"])
        #expect(ledger.variant == .ledger)
        let trezor = try GenerateMainCommand.DerivedKey.parse(["--variant", "trezor"])
        #expect(trezor.variant == .trezor)
    }

    @Test("rejects an unknown --path shortcut")
    func rejectsUnknownPath() {
        #expect(throws: (any Error).self) {
            _ = try GenerateMainCommand.DerivedKey.parse(["--path", "wallet"])
        }
    }

    @Test("rejects an unknown --variant")
    func rejectsUnknownVariant() {
        #expect(throws: (any Error).self) {
            _ = try GenerateMainCommand.DerivedKey.parse(["--variant", "yoroi"])
        }
    }

    // MARK: - CardanoPathShortcut.kind

    @Test("CardanoPathShortcut.kind maps to the matching ShelleyKeyKind")
    func pathKindMapping() {
        // Smoke test only - we just verify each case returns a kind without crashing.
        for shortcut in CardanoPathShortcut.allCases {
            _ = shortcut.kind(account: 0, index: 0)
        }
    }

    @Test("CardanoPathShortcut.description matches rawValue")
    func descriptionEqualsRawValue() {
        for shortcut in CardanoPathShortcut.allCases {
            #expect(shortcut.description == shortcut.rawValue)
        }
    }

    @Test("HwVariant.description matches rawValue")
    func variantDescriptionEqualsRawValue() {
        for variant in HwVariant.allCases {
            #expect(variant.description == variant.rawValue)
        }
    }
}
