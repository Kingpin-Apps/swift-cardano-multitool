import Foundation
import Testing
import SwiftCardanoCore
@testable import SwiftCardanoMultitool

@Suite("CommitteeUtils")
struct CommitteeUtilsTests {

    @Test("ambiguous-hash variant prints summary without throwing")
    func ambiguousHashDoesNotThrow() throws {
        let input: CommitteeMemberCredential = .ambiguousHash(Data(repeating: 0xab, count: 28))
        try committeeMemberIdSummary(input: input)
    }

    @Test("cold key credential summary does not throw for a valid 28-byte hash")
    func coldKeyHashSummary() throws {
        let hex = String(repeating: "a", count: 56)
        let (cold, _) = try parseColdCredential(hex, isScript: false)
        try committeeMemberIdSummary(input: .cold(cold))
    }

    @Test("cold script credential summary does not throw")
    func coldScriptHashSummary() throws {
        let hex = String(repeating: "b", count: 56)
        let (cold, _) = try parseColdCredential(hex, isScript: true)
        try committeeMemberIdSummary(input: .cold(cold))
    }

    @Test("hot key credential summary does not throw")
    func hotKeyHashSummary() throws {
        let hex = String(repeating: "c", count: 56)
        let hot = CommitteeHotCredential(
            credential: .verificationKeyHash(
                VerificationKeyHash(payload: hex.hexStringToData)
            )
        )
        try committeeMemberIdSummary(input: .hot(hot))
    }

    @Test("hot script credential summary does not throw")
    func hotScriptHashSummary() throws {
        let hex = String(repeating: "d", count: 56)
        let hot = CommitteeHotCredential(
            credential: .scriptHash(ScriptHash(payload: hex.hexStringToData))
        )
        try committeeMemberIdSummary(input: .hot(hot))
    }
}
