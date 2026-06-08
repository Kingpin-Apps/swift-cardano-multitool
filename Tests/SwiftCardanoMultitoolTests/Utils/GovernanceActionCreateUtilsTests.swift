import Foundation
import Testing
import ArgumentParser
import SystemPackage
import SwiftCardanoCore
@testable import SwiftCardanoMultitool

@Suite("GovernanceActionCreateUtils")
struct GovernanceActionCreateUtilsTests {

    // MARK: - parseScriptHash

    @Test("parseScriptHash returns nil for nil input")
    func nilInputReturnsNil() throws {
        let result = try parseScriptHash(nil)
        #expect(result == nil)
    }

    @Test("parseScriptHash returns nil for empty input")
    func emptyInputReturnsNil() throws {
        let result = try parseScriptHash("")
        #expect(result == nil)
    }

    @Test("parseScriptHash returns nil for whitespace-only input")
    func whitespaceReturnsNil() throws {
        let result = try parseScriptHash("   ")
        #expect(result == nil)
    }

    @Test("parseScriptHash accepts a valid 56-char hex")
    func acceptsValidHex() throws {
        let hex = String(repeating: "a", count: 56)
        let result = try parseScriptHash(hex)
        #expect(result?.payload == hex.hexStringToData)
    }

    @Test("parseScriptHash lowercases mixed-case input")
    func lowercasesInput() throws {
        let hex = String(repeating: "A", count: 56)
        let result = try parseScriptHash(hex)
        let expected = String(repeating: "a", count: 56).hexStringToData
        #expect(result?.payload == expected)
    }

    @Test("parseScriptHash rejects wrong-length hex")
    func rejectsShortHex() {
        let hex = String(repeating: "a", count: 55)
        #expect(throws: (any Error).self) {
            _ = try parseScriptHash(hex)
        }
    }

    @Test("parseScriptHash rejects non-hex characters")
    func rejectsNonHex() {
        let hex = "z" + String(repeating: "a", count: 55)
        #expect(throws: (any Error).self) {
            _ = try parseScriptHash(hex)
        }
    }

    // MARK: - parseUnitInterval

    @Test("parseUnitInterval parses numerator/denominator form")
    func parsesRational() throws {
        let r = try parseUnitInterval("2/3")
        #expect(r.numerator == 2)
        #expect(r.denominator == 3)
    }

    @Test("parseUnitInterval parses a plain decimal")
    func parsesDecimal() throws {
        let r = try parseUnitInterval("0.5")
        #expect(r.denominator == 1_000_000)
        #expect(r.numerator == 500_000)
    }

    @Test("parseUnitInterval rejects denominator 0")
    func rejectsZeroDenominator() {
        #expect(throws: (any Error).self) {
            _ = try parseUnitInterval("1/0")
        }
    }

    @Test("parseUnitInterval rejects garbage")
    func rejectsGarbage() {
        #expect(throws: (any Error).self) {
            _ = try parseUnitInterval("abc")
        }
    }

    @Test("parseUnitInterval rejects decimal > 1")
    func rejectsAboveOne() {
        #expect(throws: (any Error).self) {
            _ = try parseUnitInterval("1.5")
        }
    }

    @Test("parseUnitInterval rejects negative decimal")
    func rejectsNegative() {
        #expect(throws: (any Error).self) {
            _ = try parseUnitInterval("-0.5")
        }
    }

    // MARK: - parseColdCredential

    @Test("parseColdCredential accepts a 56-char hex hash as a key credential")
    func acceptsKeyHash() throws {
        let hex = String(repeating: "a", count: 56)
        let (cred, lower) = try parseColdCredential(hex, isScript: false)
        #expect(lower == hex)
        if case .verificationKeyHash = cred.credential {
            // OK
        } else {
            Issue.record("Expected verificationKeyHash, got \(cred.credential)")
        }
    }

    @Test("parseColdCredential treats isScript as scriptHash")
    func acceptsScriptHash() throws {
        let hex = String(repeating: "b", count: 56)
        let (cred, _) = try parseColdCredential(hex, isScript: true)
        if case .scriptHash = cred.credential {
            // OK
        } else {
            Issue.record("Expected scriptHash, got \(cred.credential)")
        }
    }

    @Test("parseColdCredential rejects too-short input")
    func rejectsBadLength() {
        #expect(throws: (any Error).self) {
            _ = try parseColdCredential("aa", isScript: false)
        }
    }

    // MARK: - parseGovActionID

    @Test("parseGovActionID returns nil for nil input")
    func govActionNilInputReturnsNil() throws {
        let r = try parseGovActionID(nil)
        #expect(r == nil)
    }

    @Test("parseGovActionID returns nil for empty input")
    func govActionEmptyReturnsNil() throws {
        let r = try parseGovActionID("")
        #expect(r == nil)
    }

    @Test("parseGovActionID rejects garbage input")
    func rejectsGarbageGovActionID() {
        #expect(throws: (any Error).self) {
            _ = try parseGovActionID("not-a-gov-action-id")
        }
    }
}

// MARK: - Test fixtures

private enum GovFixtures {
    /// Stable 64-hex tx hash used as a GovActionID transaction component.
    static let txHashHex = String(repeating: "a", count: 64)

    static func sampleGovActionID(index: UInt16 = 0) -> GovActionID {
        GovActionID(
            transactionID: TransactionId(payload: txHashHex.hexStringToData),
            govActionIndex: index
        )
    }
}

// MARK: - buildGovAction

@Suite("buildGovAction")
struct BuildGovActionTests {

    @Test(".infoAction returns the matching GovAction variant")
    func infoActionBuilds() throws {
        let result = try buildGovAction(payload: .infoAction)
        guard case .infoAction = result else {
            Issue.record("expected .infoAction, got \(result)")
            return
        }
    }

    @Test(".noConfidence with prev ID returns NoConfidence variant")
    func noConfidenceWithPrevID() throws {
        let prev = GovFixtures.sampleGovActionID()
        let result = try buildGovAction(payload: .noConfidence(prevActionID: prev))
        guard case .noConfidence = result else {
            Issue.record("expected .noConfidence, got \(result)")
            return
        }
    }

    @Test(".noConfidence without prev ID throws")
    func noConfidenceThrowsWithoutPrevID() {
        #expect(throws: (any Error).self) {
            _ = try buildGovAction(payload: .noConfidence(prevActionID: nil))
        }
    }

    @Test(".hardForkInitiation with nil prev ID is allowed (genesis case)")
    func hardForkInitiationAllowsNilPrev() throws {
        let result = try buildGovAction(payload: .hardForkInitiation(
            prevActionID: nil, major: 10, minor: 0
        ))
        guard case .hardForkInitiationAction = result else {
            Issue.record("expected .hardForkInitiationAction, got \(result)")
            return
        }
    }

    @Test(".hardForkInitiation with prev ID succeeds")
    func hardForkInitiationWithPrev() throws {
        let prev = GovFixtures.sampleGovActionID()
        let result = try buildGovAction(payload: .hardForkInitiation(
            prevActionID: prev, major: 11, minor: 0
        ))
        guard case .hardForkInitiationAction = result else {
            Issue.record("expected .hardForkInitiationAction, got \(result)")
            return
        }
    }

    @Test(".newConstitution with prev ID, URL, and hash builds the action")
    func newConstitutionBuilds() throws {
        let prev = GovFixtures.sampleGovActionID()
        let result = try buildGovAction(payload: .newConstitution(
            prevActionID: prev,
            constitutionUrl: "https://example.com/constitution.json",
            constitutionHash: String(repeating: "0", count: 64),
            scriptHash: nil
        ))
        guard case .newConstitution = result else {
            Issue.record("expected .newConstitution, got \(result)")
            return
        }
    }

    @Test(".newConstitution without prev ID throws")
    func newConstitutionRequiresPrevID() {
        #expect(throws: (any Error).self) {
            _ = try buildGovAction(payload: .newConstitution(
                prevActionID: nil,
                constitutionUrl: "https://example.com/c.json",
                constitutionHash: String(repeating: "0", count: 64),
                scriptHash: nil
            ))
        }
    }

    @Test(".treasuryWithdrawal with empty withdrawals builds an empty action")
    func treasuryWithdrawalEmpty() throws {
        let result = try buildGovAction(payload: .treasuryWithdrawal(
            withdrawals: [], guardrailsScriptHash: nil
        ))
        guard case .treasuryWithdrawalsAction = result else {
            Issue.record("expected .treasuryWithdrawalsAction, got \(result)")
            return
        }
    }

    @Test(".updateCommittee with prev ID and empty change sets builds the action")
    func updateCommitteeEmpty() throws {
        let prev = GovFixtures.sampleGovActionID()
        let threshold = try parseUnitInterval("2/3")
        let result = try buildGovAction(payload: .updateCommittee(
            prevActionID: prev,
            threshold: threshold,
            additions: [],
            removals: []
        ))
        guard case .updateCommittee = result else {
            Issue.record("expected .updateCommittee, got \(result)")
            return
        }
    }

    @Test(".parameterChange without prev ID throws")
    func parameterChangeRequiresPrevID() {
        let update = ProtocolParamUpdate()
        #expect(throws: (any Error).self) {
            _ = try buildGovAction(payload: .parameterChange(
                prevActionID: nil, update: update, guardrailsScriptHash: nil
            ))
        }
    }

    @Test(".parameterChange with prev ID and a minimal update builds the action")
    func parameterChangeBuilds() throws {
        let prev = GovFixtures.sampleGovActionID()
        let update = ProtocolParamUpdate()
        let result = try buildGovAction(payload: .parameterChange(
            prevActionID: prev, update: update, guardrailsScriptHash: nil
        ))
        guard case .parameterChangeAction = result else {
            Issue.record("expected .parameterChangeAction, got \(result)")
            return
        }
    }
}

// MARK: - GovernanceActionPayload.type

@Suite("GovernanceActionPayload.type")
struct GovernanceActionPayloadTypeTests {

    @Test("type returns the matching GovernanceActionType for every variant")
    func typeMapping() throws {
        let update = ProtocolParamUpdate()
        let prev = GovFixtures.sampleGovActionID()
        let threshold = try parseUnitInterval("2/3")

        #expect(GovernanceActionPayload.infoAction.type == .infoAction)
        #expect(GovernanceActionPayload.noConfidence(prevActionID: nil).type == .noConfidence)
        #expect(GovernanceActionPayload.hardForkInitiation(prevActionID: nil, major: 10, minor: 0).type == .hardForkInitiation)
        #expect(GovernanceActionPayload.newConstitution(prevActionID: prev, constitutionUrl: "https://x", constitutionHash: String(repeating: "0", count: 64), scriptHash: nil).type == .newConstitution)
        #expect(GovernanceActionPayload.treasuryWithdrawal(withdrawals: [], guardrailsScriptHash: nil).type == .treasuryWithdrawal)
        #expect(GovernanceActionPayload.updateCommittee(prevActionID: prev, threshold: threshold, additions: [], removals: []).type == .updateCommittee)
        #expect(GovernanceActionPayload.parameterChange(prevActionID: prev, update: update, guardrailsScriptHash: nil).type == .parameterChange)
    }
}

// MARK: - SharedGovernanceActionOptions.validateAnchorFlags

@Suite("SharedGovernanceActionOptions.validateAnchorFlags")
struct SharedGovernanceActionOptionsTests {

    /// Test wrapper so we can parse SharedGovernanceActionOptions through ArgumentParser.
    private struct ProbeCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "probe")
        @OptionGroup var opts: SharedGovernanceActionOptions
        mutating func run() async throws {}
    }

    @Test("validates when both anchor flags are nil")
    func bothNilPasses() throws {
        let cmd = try ProbeCommand.parse([])
        try cmd.opts.validateAnchorFlags()
    }

    @Test("validates when both anchor flags are provided")
    func bothProvidedPasses() throws {
        let cmd = try ProbeCommand.parse([
            "--anchor-url", "https://example.com/a.json",
            "--anchor-hash", String(repeating: "a", count: 64)
        ])
        try cmd.opts.validateAnchorFlags()
    }

    @Test("throws when only --anchor-url is set")
    func onlyUrlThrows() throws {
        let cmd = try ProbeCommand.parse(["--anchor-url", "https://example.com/a.json"])
        #expect(throws: (any Error).self) {
            try cmd.opts.validateAnchorFlags()
        }
    }

    @Test("throws when only --anchor-hash is set")
    func onlyHashThrows() throws {
        let cmd = try ProbeCommand.parse([
            "--anchor-hash", String(repeating: "a", count: 64)
        ])
        #expect(throws: (any Error).self) {
            try cmd.opts.validateAnchorFlags()
        }
    }
}

// MARK: - loadProtocolParamUpdate

@Suite("loadProtocolParamUpdate")
struct LoadProtocolParamUpdateTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-tests-ppupd-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("throws when the file does not exist")
    func throwsOnMissingFile() {
        let bogus = FilePath("/tmp/scm-ppupd-missing-\(UUID().uuidString).json")
        #expect(throws: (any Error).self) {
            _ = try loadProtocolParamUpdate(from: bogus)
        }
    }

    @Test("throws on malformed JSON")
    func throwsOnMalformedJSON() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("bad.json")
        try Data("{ not valid json".utf8).write(to: url)
        #expect(throws: (any Error).self) {
            _ = try loadProtocolParamUpdate(from: FilePath(url.path))
        }
    }

    @Test("decodes an empty JSON object as a no-op ProtocolParamUpdate")
    func decodesEmptyObject() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("empty.json")
        try Data("{}".utf8).write(to: url)
        let update = try loadProtocolParamUpdate(from: FilePath(url.path))
        // No assertions on field shapes — successful decode is the contract.
        _ = update
    }
}
