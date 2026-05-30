import Foundation
import SwiftCardanoCore
import Testing
@testable import SwiftCardanoMultitool

@Suite("CommitteeHotCredential+ExpressibleByArgument")
struct CommitteeHotCredentialExpressibleByArgumentTests {

    @Test("accepts a 56-character hex string as a key hash credential")
    func acceptsHex() {
        let hex = String(repeating: "ab", count: 28)
        #expect(CommitteeHotCredential(argument: hex) != nil)
    }

    @Test("accepts a hex string with 0x prefix")
    func acceptsHexWithPrefix() {
        let hex = "0x" + String(repeating: "34", count: 28)
        #expect(CommitteeHotCredential(argument: hex) != nil)
    }

    @Test("returns nil for an empty string")
    func rejectsEmpty() {
        #expect(CommitteeHotCredential(argument: "") == nil)
    }

    @Test("returns nil for an unprefixed non-hex non-existent file name")
    func rejectsGarbage() {
        #expect(CommitteeHotCredential(argument: "no_such_cc_hot_file") == nil)
    }
}
