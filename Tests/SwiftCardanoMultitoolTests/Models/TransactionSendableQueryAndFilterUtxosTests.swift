import ArgumentParser
import Foundation
import SystemPackage
import Testing
import SwiftCardanoChain
import SwiftCardanoCore
@testable import SwiftCardanoMultitool

/// Direct unit tests around `TransactionSendable.queryAndFilterUtxos`. Hooks the
/// `ChainContext.utxos(address:)` call via the test-only `MockChainContext.stubUtxos`
/// to feed a canned list, then verifies the filter pipeline (specific-UTXO, skip-asset,
/// only-asset, limit) in isolation.

private struct TestSender: TransactionSendable {
    @OptionGroup var transactionOptions: SharedTransactionOptions
    func run() async throws {}
}

@Suite("TransactionSendable.queryAndFilterUtxos")
struct QueryAndFilterUtxosTests {

    private func makeAddressInfo() throws -> AddressInfo {
        let addr = try ChainFixtures.makeAddress()
        return try AddressInfo(address: addr)
    }

    private func makeSender() throws -> TestSender {
        try TestSender.parse([])
    }

    @Test("returns all utxos when no filters are configured")
    func returnsAllWithoutFilters() async throws {
        let addr = try ChainFixtures.makeAddress()
        let addrInfo = try AddressInfo(address: addr)

        let utxos = [
            ChainFixtures.makeUTxO(address: addr, coin: 5_000_000, txIdSeed: 0x01),
            ChainFixtures.makeUTxO(address: addr, coin: 8_000_000, txIdSeed: 0x02),
        ]
        let mock = MockChainContext(name: "Mock", type: .online, networkId: .mainnet)
        mock.stubUtxos = { _ in utxos }

        let sender = try makeSender()
        let cfg = TestConfigs.make()
        let filtered = try await sender.queryAndFilterUtxos(
            feePaymentAddress: addrInfo, context: mock, config: cfg
        )
        #expect(filtered.count == 2)
    }

    @Test("throws when no utxos are available")
    func throwsWhenEmpty() async throws {
        let addr = try ChainFixtures.makeAddress()
        let addrInfo = try AddressInfo(address: addr)

        let mock = MockChainContext(name: "Mock", type: .online, networkId: .mainnet)
        mock.stubUtxos = { _ in [] }

        let sender = try makeSender()
        let cfg = TestConfigs.make()
        await #expect(throws: (any Error).self) {
            _ = try await sender.queryAndFilterUtxos(
                feePaymentAddress: addrInfo, context: mock, config: cfg
            )
        }
    }

    @Test("utxoLimit caps the result count, sorted by value descending")
    func limitsResultCount() async throws {
        let addr = try ChainFixtures.makeAddress()
        let addrInfo = try AddressInfo(address: addr)

        let utxos = [
            ChainFixtures.makeUTxO(address: addr, coin: 1_000_000, txIdSeed: 0x01),
            ChainFixtures.makeUTxO(address: addr, coin: 9_000_000, txIdSeed: 0x02),
            ChainFixtures.makeUTxO(address: addr, coin: 5_000_000, txIdSeed: 0x03),
        ]
        let mock = MockChainContext(name: "Mock", type: .online, networkId: .mainnet)
        mock.stubUtxos = { _ in utxos }

        var sender = try makeSender()
        sender.transactionOptions.utxoLimit = 2
        let cfg = TestConfigs.make()
        let filtered = try await sender.queryAndFilterUtxos(
            feePaymentAddress: addrInfo, context: mock, config: cfg
        )
        #expect(filtered.count == 2)
        // After sort-desc, the top 2 should be the 9 lovelace and the 5 lovelace ones.
        let coins = filtered.map { $0.output.amount.coin }.sorted(by: >)
        #expect(coins == [9_000_000, 5_000_000])
    }

    @Test("skipUtxoWithAsset removes utxos that carry the matched (policyId, assetName)")
    func skipAssetFilter() async throws {
        let addr = try ChainFixtures.makeAddress()
        let addrInfo = try AddressInfo(address: addr)

        let policy = String(repeating: "a", count: 56)
        let assetHex = "4d59544f4b" // "MYTOK"

        let plain = ChainFixtures.makeUTxO(address: addr, coin: 5_000_000, txIdSeed: 0x01)
        let tokenBearing = try ChainFixtures.makeUTxOWithAsset(
            address: addr,
            coin: 5_000_000,
            policyIdHex: policy,
            assetNameHex: assetHex,
            quantity: 100,
            txIdSeed: 0x02
        )
        let mock = MockChainContext(name: "Mock", type: .online, networkId: .mainnet)
        mock.stubUtxos = { _ in [plain, tokenBearing] }

        var sender = try makeSender()
        sender.transactionOptions.skipUtxoWithAsset = ["\(policy)+\(assetHex)"]
        let cfg = TestConfigs.make()
        let filtered = try await sender.queryAndFilterUtxos(
            feePaymentAddress: addrInfo, context: mock, config: cfg
        )
        // The token-bearing UTxO is filtered out; only the plain one remains.
        #expect(filtered.count == 1)
        #expect(filtered.first?.input.index == 0)
    }

    @Test("onlyUtxoWithAsset keeps only utxos that carry the required asset")
    func onlyAssetFilter() async throws {
        let addr = try ChainFixtures.makeAddress()
        let addrInfo = try AddressInfo(address: addr)

        let policy = String(repeating: "b", count: 56)
        let assetHex = "4142" // "AB"

        let plain = ChainFixtures.makeUTxO(address: addr, coin: 5_000_000, txIdSeed: 0x01)
        let tokenBearing = try ChainFixtures.makeUTxOWithAsset(
            address: addr,
            coin: 5_000_000,
            policyIdHex: policy,
            assetNameHex: assetHex,
            quantity: 1,
            txIdSeed: 0x02
        )
        let mock = MockChainContext(name: "Mock", type: .online, networkId: .mainnet)
        mock.stubUtxos = { _ in [plain, tokenBearing] }

        var sender = try makeSender()
        sender.transactionOptions.onlyUtxoWithAsset = ["\(policy)+\(assetHex)"]
        let cfg = TestConfigs.make()
        let filtered = try await sender.queryAndFilterUtxos(
            feePaymentAddress: addrInfo, context: mock, config: cfg
        )
        // Only the token-bearing UTxO remains.
        #expect(filtered.count == 1)
    }

    @Test("utxoFilter limits result to specified txHash#index entries")
    func specificUtxoFilter() async throws {
        let addr = try ChainFixtures.makeAddress()
        let addrInfo = try AddressInfo(address: addr)

        let target = ChainFixtures.makeUTxO(address: addr, coin: 7_000_000, txIdSeed: 0xFE, index: 1)
        let other = ChainFixtures.makeUTxO(address: addr, coin: 7_000_000, txIdSeed: 0xAA, index: 0)
        let mock = MockChainContext(name: "Mock", type: .online, networkId: .mainnet)
        mock.stubUtxos = { _ in [target, other] }

        var sender = try makeSender()
        // Match the description format that `utxo.input.description` produces.
        sender.transactionOptions.utxoFilter = [target.input.description]
        let cfg = TestConfigs.make()
        let filtered = try await sender.queryAndFilterUtxos(
            feePaymentAddress: addrInfo, context: mock, config: cfg
        )
        #expect(filtered.count == 1)
    }
}
