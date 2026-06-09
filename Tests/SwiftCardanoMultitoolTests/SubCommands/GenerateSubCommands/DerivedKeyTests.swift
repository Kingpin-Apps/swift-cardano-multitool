import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("GenerateMainCommand.DerivedKey")
struct DerivedKeyTests {

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

    @Test("CardanoPathShortcut.kind maps to the matching ShelleyKeyKind")
    func pathKindMapping() {
        for shortcut in CardanoPathShortcut.allCases {
            _ = shortcut.kind(account: 0, index: 0)
        }
    }
}
