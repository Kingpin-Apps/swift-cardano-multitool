import Foundation
import Testing
@testable import SwiftCardanoMultitool

@Suite("Prompts.parseVoterArgument")
struct PromptsParseVoterArgumentTests {

    @Test("empty input parses to .none")
    func emptyIsNone() throws {
        let voter = try parseVoterArgument("")
        #expect(voter.isNone)
    }

    @Test("whitespace-only input parses to .none")
    func whitespaceIsNone() throws {
        let voter = try parseVoterArgument("   ")
        #expect(voter.isNone)
    }

    @Test("56-char hex hash parses to .unknownHex with 28 bytes")
    func bareHexHash() throws {
        let hex = String(repeating: "a", count: 56)
        let voter = try parseVoterArgument(hex)
        guard case .unknownHex(let data) = voter else {
            Issue.record("expected .unknownHex, got \(voter)")
            return
        }
        #expect(data.count == 28)
        #expect(data == hex.hexStringToData)
    }

    @Test("uppercase hex hash is lowercased before decoding")
    func uppercaseHex() throws {
        let upper = String(repeating: "A", count: 56)
        let voter = try parseVoterArgument(upper)
        guard case .unknownHex(let data) = voter else {
            Issue.record("expected .unknownHex")
            return
        }
        #expect(data == String(repeating: "a", count: 56).hexStringToData)
    }

    @Test("hex hash of the wrong length is rejected")
    func wrongLengthHex() {
        let short = String(repeating: "a", count: 55)
        #expect(throws: (any Error).self) {
            _ = try parseVoterArgument(short)
        }
    }

    @Test("unrecognized garbage is rejected")
    func rejectsGarbage() {
        #expect(throws: (any Error).self) {
            _ = try parseVoterArgument("not-a-real-voter-format")
        }
    }

    @Test("an unsupported bech32 prefix (e.g. addr1…) is rejected")
    func rejectsAddr1() {
        #expect(throws: (any Error).self) {
            _ = try parseVoterArgument("addr1qqqqqqq")
        }
    }

    @Test("trims surrounding whitespace before dispatching")
    func trimsWhitespace() throws {
        let hex = "  " + String(repeating: "a", count: 56) + "  "
        let voter = try parseVoterArgument(hex)
        guard case .unknownHex = voter else {
            Issue.record("expected .unknownHex after trimming")
            return
        }
    }
}
