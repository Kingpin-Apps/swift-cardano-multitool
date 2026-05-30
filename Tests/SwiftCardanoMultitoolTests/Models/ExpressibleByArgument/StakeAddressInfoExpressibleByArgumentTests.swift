import Foundation
import SwiftCardanoChain
import Testing
@testable import SwiftCardanoMultitool

@Suite("StakeAddressInfo+ExpressibleByArgument")
struct StakeAddressInfoExpressibleByArgumentTests {

    @Test("returns nil for an empty string")
    func rejectsEmpty() {
        #expect(StakeAddressInfo(argument: "") == nil)
    }

    @Test("returns nil for a malformed stake-prefix bech32 string")
    func rejectsBadStakePrefix() {
        #expect(StakeAddressInfo(argument: "stake1notarealaddress") == nil)
    }

    @Test("returns nil for an addr-prefix string (not a stake address)")
    func rejectsAddrPrefix() {
        // Falls through to the file fallback (no \"stake\" prefix); fallback misses.
        #expect(StakeAddressInfo(argument: "addr1qx_not_a_file") == nil)
    }

    @Test("returns nil when the file fallback finds nothing")
    func rejectsMissingFile() {
        #expect(StakeAddressInfo(argument: "missing_stake_address_xyz") == nil)
    }
}
