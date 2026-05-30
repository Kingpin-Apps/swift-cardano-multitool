import Foundation
import SwiftCardanoChain
import Testing
@testable import SwiftCardanoMultitool

@Suite("PaymentAddressInfo+ExpressibleByArgument")
struct PaymentAddressInfoExpressibleByArgumentTests {

    @Test("returns nil for an empty string")
    func rejectsEmpty() {
        #expect(PaymentAddressInfo(argument: "") == nil)
    }

    @Test("returns nil for a malformed addr-prefix bech32 string")
    func rejectsBadAddrPrefix() {
        #expect(PaymentAddressInfo(argument: "addr1notarealpayment") == nil)
    }

    @Test("returns nil for a stake-prefix string (not a payment address)")
    func rejectsStakePrefix() {
        // Falls through to file fallback (no \"addr\" prefix); fallback misses.
        #expect(PaymentAddressInfo(argument: "stake1ux_not_a_file") == nil)
    }

    @Test("returns nil when the file fallback finds nothing")
    func rejectsMissingFile() {
        #expect(PaymentAddressInfo(argument: "missing_payment_address_xyz") == nil)
    }
}
