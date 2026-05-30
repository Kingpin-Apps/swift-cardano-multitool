import Foundation
import SwiftCardanoCore
import Testing
@testable import SwiftCardanoMultitool

@Suite("DRep+ExpressibleByArgument")
struct DRepExpressibleByArgumentTests {

    // DRep.init(from: Data) expects a structured (tagged) DRep encoding, not a raw
    // 28-byte key hash. The argument parser preserves that: a bare hex blob falls
    // through to the file fallback, which fails to find anything and returns nil.
    // Use DRepCredential for the raw key-hash case.

    @Test("returns nil for a bare 56-character hex string")
    func bareHexIsNil() {
        let hex = String(repeating: "ab", count: 28)
        #expect(DRep(argument: hex) == nil)
    }

    @Test("returns nil for an empty string")
    func rejectsEmpty() {
        #expect(DRep(argument: "") == nil)
    }

    @Test("returns nil for an unprefixed non-hex non-existent file name")
    func rejectsGarbage() {
        #expect(DRep(argument: "no_such_file_xyz_qrs") == nil)
    }

    @Test("returns nil for a hex string with an odd number of digits")
    func rejectsOddHex() {
        let hex = String(repeating: "a", count: 55)
        #expect(DRep(argument: hex) == nil)
    }
}
