import Foundation
import Testing
import SwiftCardanoCore
@testable import SwiftCardanoMultitool

/// Behavior tests for `ScriptUtils.utxoSummary` — the function prints tables via Noora
/// rather than returning a structured result, so these tests exercise the code paths
/// (empty list, lovelace-only, standard asset, each ADA Handle variant) by asserting
/// the call completes without throwing for each input shape.
@Suite("ScriptUtils.utxoSummary")
struct UtxoSummaryTests {

    /// Default mainnet ADA Handle policy ID from `AdaHandlePolicyIds()`.
    private static let adaHandlePolicy = "f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a"

    /// Hex-encode a UTF-8 handle name.
    private static func handleHex(_ name: String) -> String {
        Data(name.utf8).map { String(format: "%02x", $0) }.joined()
    }

    @Test("empty utxos array completes without throwing")
    func emptyUtxos() async throws {
        let cfg = TestConfigs.make(network: .mainnet)
        try await utxoSummary(utxos: [], config: cfg)
    }

    @Test("single lovelace-only UTxO completes without throwing")
    func singleLovelaceOnly() async throws {
        let cfg = TestConfigs.make(network: .mainnet)
        let addr = try ChainFixtures.makeAddress()
        let utxo = ChainFixtures.makeUTxO(address: addr, coin: 5_000_000)
        try await utxoSummary(utxos: [utxo], config: cfg)
    }

    @Test("multiple lovelace-only UTxOs (plural label path)")
    func multipleLovelaceUtxos() async throws {
        let cfg = TestConfigs.make(network: .mainnet)
        let addr = try ChainFixtures.makeAddress()
        let utxos = [
            ChainFixtures.makeUTxO(address: addr, coin: 1_000_000, txIdSeed: 0x01, index: 0),
            ChainFixtures.makeUTxO(address: addr, coin: 2_500_000, txIdSeed: 0x02, index: 1),
        ]
        try await utxoSummary(utxos: utxos, config: cfg)
    }

    @Test("UTxO with a standard (non-handle) multi-asset completes without throwing")
    func standardMultiAsset() async throws {
        let cfg = TestConfigs.make(network: .mainnet)
        let addr = try ChainFixtures.makeAddress()
        let utxo = try ChainFixtures.makeUTxOWithAsset(
            address: addr,
            coin: 2_000_000,
            policyIdHex: String(repeating: "a", count: 56),
            assetNameHex: Self.handleHex("MYTOK"),
            quantity: 100
        )
        try await utxoSummary(utxos: [utxo], config: cfg)
    }

    @Test("UTxO with a CIP-68 (000de140 prefix) ADA Handle is detected and rendered")
    func adaHandleCIP68() async throws {
        let cfg = TestConfigs.make(network: .mainnet)
        let addr = try ChainFixtures.makeAddress()
        let assetName = "000de140" + Self.handleHex("hareem")
        let utxo = try ChainFixtures.makeUTxOWithAsset(
            address: addr,
            coin: 1_500_000,
            policyIdHex: Self.adaHandlePolicy,
            assetNameHex: assetName,
            quantity: 1
        )
        try await utxoSummary(utxos: [utxo], config: cfg)
    }

    @Test("UTxO with a Virtual (00000000 prefix) ADA Handle is detected and rendered")
    func adaHandleVirtual() async throws {
        let cfg = TestConfigs.make(network: .mainnet)
        let addr = try ChainFixtures.makeAddress()
        let assetName = "00000000" + Self.handleHex("virt")
        let utxo = try ChainFixtures.makeUTxOWithAsset(
            address: addr,
            coin: 1_500_000,
            policyIdHex: Self.adaHandlePolicy,
            assetNameHex: assetName,
            quantity: 1
        )
        try await utxoSummary(utxos: [utxo], config: cfg)
    }

    @Test("UTxO with a Reference (000643b0 prefix) ADA Handle is detected and rendered")
    func adaHandleReference() async throws {
        let cfg = TestConfigs.make(network: .mainnet)
        let addr = try ChainFixtures.makeAddress()
        let assetName = "000643b0" + Self.handleHex("ref")
        let utxo = try ChainFixtures.makeUTxOWithAsset(
            address: addr,
            coin: 1_500_000,
            policyIdHex: Self.adaHandlePolicy,
            assetNameHex: assetName,
            quantity: 1
        )
        try await utxoSummary(utxos: [utxo], config: cfg)
    }

    @Test("UTxO with a CIP-25 (no special prefix) ADA Handle falls through to the legacy branch")
    func adaHandleCIP25() async throws {
        let cfg = TestConfigs.make(network: .mainnet)
        let addr = try ChainFixtures.makeAddress()
        let assetName = Self.handleHex("legacy")
        let utxo = try ChainFixtures.makeUTxOWithAsset(
            address: addr,
            coin: 1_500_000,
            policyIdHex: Self.adaHandlePolicy,
            assetNameHex: assetName,
            quantity: 1
        )
        try await utxoSummary(utxos: [utxo], config: cfg)
    }
}
