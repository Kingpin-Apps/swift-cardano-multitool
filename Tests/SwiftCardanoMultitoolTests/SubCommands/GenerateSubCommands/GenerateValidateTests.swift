import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

/// `validate()` tests for the heavier `generate` subcommands.
///
/// ArgumentParser runs `validate()` as part of `parse(_:)`, so these exercise the real
/// method-restriction and range-bound logic with no I/O, crypto, or chain access. The
/// `validate()` methods also backfill default sub-account/index values, which the tests
/// assert on the parsed instance.

@Suite("GenerateMainCommand.DRepKeys validate()")
struct DRepKeysValidateTests {

    @Test("hw backfills sub-account and index to 0")
    func hwBackfillsDefaults() throws {
        let cmd = try GenerateMainCommand.DRepKeys.parse(["--key-gen-method", "hw"])
        #expect(cmd.subAccount == 0)
        #expect(cmd.index == 0)
    }

    @Test("hybrid methods are rejected")
    func rejectsHybrid() {
        #expect(throws: (any Error).self) {
            _ = try GenerateMainCommand.DRepKeys.parse(["--key-gen-method", "hybrid"])
        }
    }

    @Test("negative sub-account is rejected")
    func rejectsNegativeSubAccount() {
        #expect(throws: (any Error).self) {
            _ = try GenerateMainCommand.DRepKeys.parse(["--key-gen-method", "cli", "--sub-account", "-1"])
        }
    }

    @Test("out-of-range index is rejected")
    func rejectsOutOfRangeIndex() {
        #expect(throws: (any Error).self) {
            _ = try GenerateMainCommand.DRepKeys.parse(["--key-gen-method", "cli", "--index", "2147483648"])
        }
    }

    @Test("cli without derivation indices parses cleanly")
    func cliParsesClean() throws {
        let cmd = try GenerateMainCommand.DRepKeys.parse(["--key-gen-method", "cli"])
        #expect(cmd.subAccount == nil)
        #expect(cmd.index == nil)
    }
}

@Suite("GenerateMainCommand.Policy validate()")
struct PolicyValidateTests {

    @Test("mnemonics backfills sub-account to 0")
    func mnemonicsBackfillsSubAccount() throws {
        let cmd = try GenerateMainCommand.Policy.parse(["--key-gen-method", "mnemonics"])
        #expect(cmd.subAccount == 0)
    }

    @Test("hybrid methods are rejected")
    func rejectsHybrid() {
        #expect(throws: (any Error).self) {
            _ = try GenerateMainCommand.Policy.parse(["--key-gen-method", "hybrid_multi"])
        }
    }

    @Test("--slot-limit of 0 is rejected")
    func rejectsZeroSlotLimit() {
        #expect(throws: (any Error).self) {
            _ = try GenerateMainCommand.Policy.parse(["--key-gen-method", "cli", "--slot-limit", "0"])
        }
    }

    @Test("a positive slot-limit parses")
    func positiveSlotLimitParses() throws {
        let cmd = try GenerateMainCommand.Policy.parse(["--key-gen-method", "cli", "--slot-limit", "100"])
        #expect(cmd.slotLimit == 100)
    }
}

@Suite("GenerateMainCommand.NodeColdKeys validate()")
struct NodeColdKeysValidateTests {

    @Test("hw backfills cold-key-index to 0")
    func hwBackfillsIndex() throws {
        let cmd = try GenerateMainCommand.NodeColdKeys.parse(["--key-gen-method", "hw"])
        #expect(cmd.coldKeyIndex == 0)
    }

    @Test("hw_multi and hybrid methods are rejected")
    func rejectsUnsupported() {
        #expect(throws: (any Error).self) {
            _ = try GenerateMainCommand.NodeColdKeys.parse(["--key-gen-method", "hw_multi"])
        }
        #expect(throws: (any Error).self) {
            _ = try GenerateMainCommand.NodeColdKeys.parse(["--key-gen-method", "hybrid"])
        }
    }

    @Test("negative cold-key-index is rejected")
    func rejectsNegativeIndex() {
        #expect(throws: (any Error).self) {
            _ = try GenerateMainCommand.NodeColdKeys.parse(["--key-gen-method", "cli", "--cold-key-index", "-1"])
        }
    }
}

@Suite("GenerateMainCommand.NodeKESKeys / NodeVRFKeys validate()")
struct NodeKesVrfValidateTests {

    @Test("KES rejects hardware methods, accepts cli")
    func kesMethodRestriction() throws {
        #expect(throws: (any Error).self) {
            _ = try GenerateMainCommand.NodeKESKeys.parse(["--key-gen-method", "hw"])
        }
        let cmd = try GenerateMainCommand.NodeKESKeys.parse(["--key-gen-method", "cli"])
        #expect(cmd.keyGenMethod == .cli)
    }

    @Test("VRF rejects hardware methods, accepts enc")
    func vrfMethodRestriction() throws {
        #expect(throws: (any Error).self) {
            _ = try GenerateMainCommand.NodeVRFKeys.parse(["--key-gen-method", "hybrid_enc"])
        }
        let cmd = try GenerateMainCommand.NodeVRFKeys.parse(["--key-gen-method", "enc"])
        #expect(cmd.keyGenMethod == .enc)
    }
}

@Suite("GenerateMainCommand.PaymentAddressOnly validate()")
struct PaymentAddressOnlyValidateTests {

    @Test("hybrid methods are redirected to payment-and-stake-address")
    func rejectsHybrid() {
        #expect(throws: (any Error).self) {
            _ = try GenerateMainCommand.PaymentAddressOnly.parse(["--key-gen-method", "hybrid"])
        }
    }

    @Test("hw backfills sub-account and index to 0")
    func hwBackfillsDefaults() throws {
        let cmd = try GenerateMainCommand.PaymentAddressOnly.parse(["--key-gen-method", "hw"])
        #expect(cmd.subAccount == 0)
        #expect(cmd.index == 0)
    }

    @Test("negative sub-account is rejected")
    func rejectsNegativeSubAccount() {
        #expect(throws: (any Error).self) {
            _ = try GenerateMainCommand.PaymentAddressOnly.parse(["--key-gen-method", "cli", "--sub-account", "-1"])
        }
    }
}
