import Foundation
import SwiftCardanoChain
import Testing
@testable import SwiftCardanoMultitool

@Suite("AddressInfo+ExpressibleByArgument")
struct AddressInfoExpressibleByArgumentTests {

    @Test("returns nil for an empty string")
    func rejectsEmpty() {
        #expect(AddressInfo(argument: "") == nil)
    }

    @Test("returns nil for a malformed addr-prefix bech32 string")
    func rejectsBadAddrPrefix() {
        // The hasPrefix(\"addr\") branch will be taken; the failable AddressInfo init
        // returns nil for garbage payloads.
        #expect(AddressInfo(argument: "addr1notarealaddress") == nil)
    }

    @Test("returns nil for a malformed stake-prefix bech32 string")
    func rejectsBadStakePrefix() {
        #expect(AddressInfo(argument: "stake1notarealaddress") == nil)
    }

    @Test("returns nil when the file fallback finds nothing")
    func rejectsMissingFile() {
        #expect(AddressInfo(argument: "no_such_address_file_xyz") == nil)
    }
}
