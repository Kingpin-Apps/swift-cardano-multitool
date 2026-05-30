import Foundation
import SwiftCardanoCore
import Testing
@testable import SwiftCardanoMultitool

@Suite("CommitteeColdCredential+ExpressibleByArgument")
struct CommitteeColdCredentialExpressibleByArgumentTests {

    @Test("accepts a 56-character hex string as a key hash credential")
    func acceptsHex() {
        let hex = String(repeating: "ab", count: 28)
        #expect(CommitteeColdCredential(argument: hex) != nil)
    }

    @Test("accepts a hex string with 0x prefix")
    func acceptsHexWithPrefix() {
        let hex = "0X" + String(repeating: "fe", count: 28)
        #expect(CommitteeColdCredential(argument: hex) != nil)
    }

    @Test("returns nil for an empty string")
    func rejectsEmpty() {
        #expect(CommitteeColdCredential(argument: "") == nil)
    }

    @Test("returns nil for an unprefixed non-hex non-existent file name")
    func rejectsGarbage() {
        #expect(CommitteeColdCredential(argument: "no_such_cc_cold_file") == nil)
    }
}
