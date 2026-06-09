import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("SendMainCommand.Assets")
struct SendAssetsTests {

    @Test("validate accepts a 56-character hex policy ID")
    func validatesValidPolicyId() throws {
        let policyId = String(repeating: "ab", count: 28)
        let cmd = try SendMainCommand.Assets.parse(["--policy-id", policyId])
        #expect(cmd.policyId == policyId)
    }

    @Test("validate rejects a short policy ID")
    func validateRejectsShortPolicyId() {
        #expect(throws: (any Error).self) {
            _ = try SendMainCommand.Assets.parse(["--policy-id", "abc"])
        }
    }

    @Test("validate rejects a non-hex policy ID of correct length")
    func validateRejectsNonHexPolicyId() {
        let bad = String(repeating: "z", count: 56)
        #expect(throws: (any Error).self) {
            _ = try SendMainCommand.Assets.parse(["--policy-id", bad])
        }
    }

    @Test("validate rejects a non-hex asset name")
    func validateRejectsNonHexAssetName() {
        #expect(throws: (any Error).self) {
            _ = try SendMainCommand.Assets.parse([
                "--policy-id", String(repeating: "ab", count: 28),
                "--asset-name-hex", "MyToken"
            ])
        }
    }

    @Test("validate accepts 'all' and 'min' as amount specials")
    func validatesAmountSpecials() throws {
        let cmdAll = try SendMainCommand.Assets.parse(["--amount", "all"])
        #expect(cmdAll.amount == "all")
        let cmdMin = try SendMainCommand.Assets.parse(["--amount", "min"])
        #expect(cmdMin.amount == "min")
    }

    @Test("validate rejects amount that is neither a positive integer nor a special")
    func validateRejectsBadAmount() {
        #expect(throws: (any Error).self) {
            _ = try SendMainCommand.Assets.parse(["--amount", "zero"])
        }
    }
}
