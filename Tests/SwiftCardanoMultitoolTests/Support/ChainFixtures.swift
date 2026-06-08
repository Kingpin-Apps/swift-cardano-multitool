import Foundation
import SwiftCardanoCore

/// Lightweight programmatic builders for the on-chain types that
/// `TransactionSendable.queryAndFilterUtxos` and friends need to consume.
///
/// Everything here is plain in-memory construction — no on-disk fixtures
/// and no chain calls — so tests that consume these stay fast and deterministic.
public enum ChainFixtures {

    // MARK: - Addresses

    /// Construct a fresh `Address` from a deterministic 28-byte payment key hash and
    /// 28-byte stake key hash. The same hash byte gets reused across both.
    public static func makeAddress(seed: UInt8 = 0xAB) throws -> Address {
        let paymentHash = VerificationKeyHash(payload: Data(repeating: seed, count: 28))
        let stakeHash = VerificationKeyHash(payload: Data(repeating: seed, count: 28))
        return try Address(
            paymentPart: .verificationKeyHash(paymentHash),
            stakingPart: .verificationKeyHash(stakeHash),
            network: .mainnet
        )
    }

    // MARK: - TransactionInput

    /// 64-hex transaction hash filled with the given byte for determinism.
    public static func makeTransactionInput(
        txIdSeed: UInt8 = 0x11,
        index: UInt16 = 0
    ) -> TransactionInput {
        let txId = TransactionId(payload: Data(repeating: txIdSeed, count: 32))
        return TransactionInput(transactionId: txId, index: index)
    }

    // MARK: - UTxO

    /// A minimal pure-lovelace UTxO at the given address and amount.
    public static func makeUTxO(
        address: Address,
        coin: Int64 = 5_000_000,
        txIdSeed: UInt8 = 0x11,
        index: UInt16 = 0
    ) -> UTxO {
        let input = makeTransactionInput(txIdSeed: txIdSeed, index: index)
        let output = TransactionOutput(address: address, amount: Value(coin: coin))
        return UTxO(input: input, output: output)
    }

    /// A UTxO that carries a single native asset on top of its lovelace.
    public static func makeUTxOWithAsset(
        address: Address,
        coin: Int64 = 5_000_000,
        policyIdHex: String,
        assetNameHex: String,
        quantity: Int64 = 1,
        txIdSeed: UInt8 = 0x22,
        index: UInt16 = 0
    ) throws -> UTxO {
        let input = makeTransactionInput(txIdSeed: txIdSeed, index: index)
        let scriptHash = ScriptHash(payload: policyIdHex.hexStringToData)
        let assetName = try AssetName(payload: assetNameHex.hexStringToData)
        let asset = Asset([assetName: quantity])
        let multiAsset = MultiAsset([scriptHash: asset])
        let value = Value(coin: coin, multiAsset: multiAsset)
        let output = TransactionOutput(address: address, amount: value)
        return UTxO(input: input, output: output)
    }
}
