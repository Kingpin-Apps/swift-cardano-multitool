import Foundation
import Testing
import SwiftCardanoCore
@testable import SwiftCardanoMultitool

@Suite("GovActionID+ExpressibleByArgument")
struct GovActionIDExpressibleByArgumentTests {

    @Test("parses <txHash>#<index> form")
    func parsesTxHashIndex() {
        let txHash = String(repeating: "a", count: 64)
        let parsed = GovActionID(argument: "\(txHash)#0")
        #expect(parsed != nil)
        if let parsed {
            #expect(parsed.govActionIndex == 0)
            #expect(parsed.transactionID.payload == txHash.hexStringToData)
        }
    }

    @Test("parses <txHash>#<index> for non-zero index")
    func parsesNonZeroIndex() {
        let txHash = String(repeating: "b", count: 64)
        let parsed = GovActionID(argument: "\(txHash)#42")
        if let parsed {
            #expect(parsed.govActionIndex == 42)
        } else {
            Issue.record("expected to parse")
        }
    }

    @Test("rejects <txHash>#<index> with a non-64-char hash")
    func rejectsShortHash() {
        let shortHash = String(repeating: "a", count: 63)
        let parsed = GovActionID(argument: "\(shortHash)#0")
        #expect(parsed == nil)
    }

    @Test("rejects <txHash>#<index> with a non-hex hash")
    func rejectsNonHexHash() {
        let badHash = "z" + String(repeating: "a", count: 63)
        let parsed = GovActionID(argument: "\(badHash)#0")
        #expect(parsed == nil)
    }

    @Test("trims whitespace before parsing")
    func trimsWhitespace() {
        let txHash = String(repeating: "a", count: 64)
        let parsed = GovActionID(argument: "  \(txHash)#0  ")
        #expect(parsed != nil)
    }

    @Test("rejects entirely garbage input")
    func rejectsGarbage() {
        #expect(GovActionID(argument: "not-an-id") == nil)
    }

    @Test("rejects empty input")
    func rejectsEmpty() {
        #expect(GovActionID(argument: "") == nil)
    }
}
