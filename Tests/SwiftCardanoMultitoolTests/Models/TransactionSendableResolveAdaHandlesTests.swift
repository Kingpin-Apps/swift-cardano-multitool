import ArgumentParser
import Foundation
import Testing
import SwiftCardanoChain
import SwiftCardanoCore
@testable import SwiftCardanoMultitool

/// Tests around `TransactionSendable.resolveAdaHandles` and `resolveStakeAdaHandle`.
/// Both methods short-circuit when the corresponding `transactionOptions` field is nil
/// (no work to do); when an address is already set (no AdaHandle), they also no-op.
/// Only the `$handle` path requires a real chain lookup — out of scope here.

private struct TestSender: TransactionSendable {
    @OptionGroup var transactionOptions: SharedTransactionOptions
    func run() async throws {}
}

@Suite("TransactionSendable.resolveAdaHandles")
struct TransactionSendableResolveAdaHandlesTests {

    @Test("with both addresses unset, resolveAdaHandles is a no-op")
    func bothAddressesNilNoOp() async throws {
        var sender = try TestSender.parse([])
        try await sender.resolveAdaHandles(network: .mainnet)
        #expect(sender.transactionOptions.toAddress == nil)
        #expect(sender.transactionOptions.feePaymentAddress == nil)
    }

    @Test("with a fully-resolved feePaymentAddress (no AdaHandle), resolveAdaHandles preserves it")
    func resolvedFeePaymentAddressUntouched() async throws {
        let addr = try ChainFixtures.makeAddress()
        let info = try AddressInfo(address: addr)

        var sender = try TestSender.parse([])
        sender.transactionOptions.feePaymentAddress = PaymentAddressInfo(info: info)

        try await sender.resolveAdaHandles(network: .mainnet)
        // Address is still present and unchanged.
        #expect(sender.transactionOptions.feePaymentAddress != nil)
        #expect(sender.transactionOptions.feePaymentAddress?.info.address != nil)
    }

    @Test("with a fully-resolved toAddress (no AdaHandle), resolveAdaHandles preserves it")
    func resolvedToAddressUntouched() async throws {
        let addr = try ChainFixtures.makeAddress()
        let info = try AddressInfo(address: addr)

        var sender = try TestSender.parse([])
        sender.transactionOptions.toAddress = PaymentAddressInfo(info: info)

        try await sender.resolveAdaHandles(network: .mainnet)
        #expect(sender.transactionOptions.toAddress != nil)
        #expect(sender.transactionOptions.toAddress?.info.address != nil)
    }
}

// Note: a unit test for `resolveStakeAdaHandle(_:network:)` was attempted but the
// `SwiftCardanoMultitool.StakeAddressInfo` type name collides with the top-level
// `struct SwiftCardanoMultitool` in the same module, making it impossible to
// disambiguate from `SwiftCardanoCore.StakeAddressInfo` at the test-target level.
// The nil-no-op behaviour is exercised indirectly through callers (e.g. Build).

// MARK: - isSame property

@Suite("TransactionSendable.isSame property")
struct TransactionSendableIsSameTests {

    @Test("returns true when both addresses are nil")
    func bothNil() throws {
        let sender = try TestSender.parse([])
        #expect(sender.isSame == true)
    }

    @Test("returns true when the two addresses share the same underlying Address")
    func sameAddress() throws {
        let addr = try ChainFixtures.makeAddress()
        let info = try AddressInfo(address: addr)
        var sender = try TestSender.parse([])
        sender.transactionOptions.feePaymentAddress = PaymentAddressInfo(info: info)
        sender.transactionOptions.toAddress = PaymentAddressInfo(info: info)
        #expect(sender.isSame == true)
    }

    @Test("returns false when addresses differ")
    func differentAddresses() throws {
        let addrA = try ChainFixtures.makeAddress(seed: 0xAA)
        let addrB = try ChainFixtures.makeAddress(seed: 0xBB)
        let infoA = try AddressInfo(address: addrA)
        let infoB = try AddressInfo(address: addrB)
        var sender = try TestSender.parse([])
        sender.transactionOptions.feePaymentAddress = PaymentAddressInfo(info: infoA)
        sender.transactionOptions.toAddress = PaymentAddressInfo(info: infoB)
        #expect(sender.isSame == false)
    }
}
