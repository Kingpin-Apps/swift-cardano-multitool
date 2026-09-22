import Foundation
import SwiftCardanoCore
import Testing
@testable import SwiftCardanoMultitool

@Suite("DRep+ExpressibleByArgument")
struct DRepExpressibleByArgumentTests {

    // A bare 56-character hex string is a 28-byte credential hash. It used to be
    // rejected, because the parser handed it to `DRep.init(from: Data)`, which
    // expects a structured (tagged) encoding. It is now read as a key hash, the
    // same assumption cardano-cli makes for `--drep-key-hash`.
    // See DRepArgumentParsingTests for the full matrix of accepted spellings.

    @Test("reads a bare 56-character hex string as a key hash")
    func bareHexIsKeyHash() {
        let hex = String(repeating: "ab", count: 28)
        let drep = DRep(argument: hex)
        guard case let .verificationKeyHash(hash) = drep?.credential else {
            Issue.record("expected a verification key hash, got \(String(describing: drep))")
            return
        }
        #expect(hash.payload.toHex == hex)
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
