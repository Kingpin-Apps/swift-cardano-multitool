import Foundation
import SwiftCardanoCore
import Testing
@testable import SwiftCardanoMultitool

@Suite("DRepCredential+ExpressibleByArgument")
struct DRepCredentialExpressibleByArgumentTests {

    @Test("accepts a 56-character hex string as a key hash credential")
    func acceptsHex() {
        let hex = String(repeating: "ab", count: 28)
        #expect(DRepCredential(argument: hex) != nil)
    }

    @Test("accepts a hex string with 0x prefix")
    func acceptsHexWithPrefix() {
        let hex = "0x" + String(repeating: "12", count: 28)
        #expect(DRepCredential(argument: hex) != nil)
    }

    @Test("returns nil for an empty string")
    func rejectsEmpty() {
        #expect(DRepCredential(argument: "") == nil)
    }

    @Test("returns nil for an unprefixed non-hex non-existent file name")
    func rejectsGarbage() {
        #expect(DRepCredential(argument: "missing_drep_file_path") == nil)
    }
}
