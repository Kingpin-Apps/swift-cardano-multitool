import Foundation
import SwiftCardanoCore
import Testing
@testable import SwiftCardanoMultitool

@Suite("PoolOperator+ExpressibleByArgument")
struct PoolOperatorExpressibleByArgumentTests {

    @Test("accepts a valid bech32 pool ID")
    func acceptsBech32() {
        let id = "pool1z5uqdk7dzdxaae5633fqfcu2eqzy3a3rgtuvy087fdld7yws0xt"
        #expect(PoolOperator(argument: id) != nil)
    }

    @Test("accepts a 56-character hex string")
    func acceptsHex() {
        let hex = String(repeating: "ab", count: 28)
        #expect(PoolOperator(argument: hex) != nil)
    }

    @Test("accepts a hex string with 0x prefix")
    func acceptsHexWithPrefix() {
        let hex = "0x" + String(repeating: "ab", count: 28)
        #expect(PoolOperator(argument: hex) != nil)
    }

    @Test("returns nil for an empty string")
    func rejectsEmpty() {
        #expect(PoolOperator(argument: "") == nil)
    }

    @Test("returns nil for an unprefixed non-hex non-existent file name")
    func rejectsGarbage() {
        #expect(PoolOperator(argument: "no_such_file_anywhere_xyz") == nil)
    }

    @Test("trims surrounding whitespace before parsing")
    func trimsWhitespace() {
        let id = "  pool1z5uqdk7dzdxaae5633fqfcu2eqzy3a3rgtuvy087fdld7yws0xt  "
        #expect(PoolOperator(argument: id) != nil)
    }
}
