import Foundation
import SwiftCardanoCore

/// A blockchain explorer implementation for [Eutxo](https://eutxo.org).
///
/// Eutxo is a mainnet-only explorer that supports viewing blocks and transactions.
/// It does not support account, address, or pool lookups — those methods will throw
/// ``SwiftCardanoMultitoolError/notImplemented(_:)`` via the default protocol implementation.
///
/// - Note: Eutxo only supports mainnet. Attempting to use preprod or preview
///   networks will throw an error.
/// - Note: Block lookups require a ``BlockNumberOrBodyHash/bodyHash(_:)`` identifier.
///
/// ## Usage
///
/// ```swift
/// let explorer = Eutxo(network: .mainnet)
/// let url = try explorer.viewTransaction(transactionId: txId)
/// ```
public struct Eutxo: BlockchainExplorable {
    /// The Cardano network this explorer targets.
    public let network: Network

    /// The base URLs for each supported network.
    ///
    /// Eutxo only supports mainnet.
    public let networkUrls: NetworkURLs = NetworkURLs(
        mainnet: URL(string: "https://eutxo.org")!,
    )

    /// Returns a URL to view the given block on Eutxo.
    ///
    /// Eutxo requires blocks to be identified by their body hash.
    ///
    /// - Parameter block: A block identifier. Must be ``BlockNumberOrBodyHash/bodyHash(_:)``.
    /// - Returns: A URL pointing to the block page on Eutxo.
    /// - Throws: ``SwiftCardanoMultitoolError/valueError(_:)`` if a block number
    ///   is provided instead of a body hash.
    public func viewBlock(block: BlockNumberOrBodyHash) throws -> URL {
        guard case let .bodyHash(bodyHash) = block else {
            throw SwiftCardanoMultitoolError
                .valueError(
                    "Eutxo only supports block hash for block URLs"
                )
        }
        return try baseURL
            .appendingPathComponent("block")
            .appendingPathComponent(bodyHash.payload.toHex)
    }

    /// Returns a URL to view the given transaction on Eutxo.
    ///
    /// - Parameter transactionId: The transaction identifier to look up.
    /// - Returns: A URL pointing to the transaction page on Eutxo.
    public func viewTransaction(transactionId: TransactionId) throws -> URL {
        return try baseURL
            .appendingPathComponent("transaction")
            .appendingPathComponent(transactionId.payload.toHex)
    }
}
