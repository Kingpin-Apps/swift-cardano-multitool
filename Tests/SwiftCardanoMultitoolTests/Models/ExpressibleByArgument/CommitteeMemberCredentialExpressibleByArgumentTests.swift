import Foundation
import Testing
@testable import SwiftCardanoMultitool

@Suite("CommitteeMemberCredential+ExpressibleByArgument")
struct CommitteeMemberCredentialExpressibleByArgumentTests {

    @Test("a bare 56-char hex hash parses as .ambiguousHash")
    func bareHexIsAmbiguous() {
        let hex = String(repeating: "a", count: 56)
        let parsed = CommitteeMemberCredential(argument: hex)
        guard case .ambiguousHash(let data) = parsed else {
            Issue.record("expected .ambiguousHash, got \(String(describing: parsed))")
            return
        }
        #expect(data.count == 28)
    }

    @Test("hex with 0x prefix is also routed to .ambiguousHash")
    func hexWith0xPrefix() {
        let hex = "0x" + String(repeating: "b", count: 56)
        let parsed = CommitteeMemberCredential(argument: hex)
        guard case .ambiguousHash(let data) = parsed else {
            Issue.record("expected .ambiguousHash, got \(String(describing: parsed))")
            return
        }
        #expect(data.count == 28)
    }

    @Test("rejects garbage that is neither bech32 nor hex")
    func rejectsGarbage() {
        let parsed = CommitteeMemberCredential(argument: "wat-is-this")
        #expect(parsed == nil)
    }

    @Test("trims surrounding whitespace before parsing hex")
    func trimsWhitespace() {
        let hex = "  " + String(repeating: "f", count: 56) + "  "
        let parsed = CommitteeMemberCredential(argument: hex)
        #expect(parsed != nil)
    }

    @Test("rejects empty input")
    func rejectsEmpty() {
        #expect(CommitteeMemberCredential(argument: "") == nil)
    }

    @Test("rejects odd-length hex")
    func rejectsOddLengthHex() {
        let hex = String(repeating: "a", count: 55)
        #expect(CommitteeMemberCredential(argument: hex) == nil)
    }

    @Test("rejects an unrecognized bech32 prefix")
    func rejectsBadPrefix() {
        #expect(CommitteeMemberCredential(argument: "cc_cold1invalidxxx") == nil)
    }
}
