import Foundation
import SwiftCardanoCore

/// A blockchain explorer implementation for [CardanoScan](https://cardanoscan.io).
///
/// CardanoScan supports mainnet, preprod, and preview networks. It provides
/// viewing of accounts (stake keys), addresses, blocks, pools, and transactions.
///
/// - Note: Block lookups require a ``BlockNumberOrBodyHash/number(_:)`` identifier.
/// - Note: Account lookups require a stake address (bech32 prefix `stake`).
///
/// ## Usage
///
/// ```swift
/// let explorer = CardanoScan(network: .mainnet)
/// let url = try explorer.viewTransaction(transactionId: txId)
/// ```
public struct CardanoScan: BlockchainExplorable {
    /// The Cardano network this explorer targets.
    public let network: Network

    /// The base URLs for each supported network.
    ///
    /// CardanoScan supports mainnet, preprod, and preview.
    public let networkUrls: NetworkURLs = NetworkURLs(
        mainnet: URL(string: "https://cardanoscan.io")!,
        preprod: URL(string: "https://preprod.cardanoscan.io")!,
        preview: URL(string: "https://preview.cardanoscan.io")!
    )

    /// Returns a URL to view the stake key account on CardanoScan.
    ///
    /// The address must be a stake address (bech32 representation starting with `"stake"`).
    ///
    /// - Parameter address: A Cardano stake address.
    /// - Returns: A URL pointing to the stake key page on CardanoScan.
    /// - Throws: ``SwiftCardanoMultitoolError/invalidAddress(_:)`` if the address
    ///   cannot be converted to bech32 or is not a stake address.
    public func viewAccount(address: Address) throws -> URL {
        let bech32Address: String
        do {
            bech32Address = try address.toBech32()
        } catch {
            throw SwiftCardanoMultitoolError.invalidAddress("Unable to convert address to bech32: \(address)")
        }

        guard bech32Address.starts(with: "stake") else {
            throw SwiftCardanoMultitoolError.invalidAddress("Address must be a stake address for CardanoScan Stake Key URL")
        }

        return try baseURL
            .appendingPathComponent("stakeKey")
            .appendingPathComponent(bech32Address)
    }

    /// Returns a URL to view the given address on CardanoScan.
    ///
    /// The address is converted to its bech32 representation for the URL path.
    ///
    /// - Parameter address: A Cardano address to look up.
    /// - Returns: A URL pointing to the address page on CardanoScan.
    /// - Throws: ``SwiftCardanoMultitoolError/invalidAddress(_:)`` if the address
    ///   cannot be converted to bech32.
    public func viewAddress(address: Address) throws -> URL {
        let bech32Address: String
        do {
            bech32Address = try address.toBech32()
        } catch {
            throw SwiftCardanoMultitoolError.invalidAddress("Unable to convert address to bech32: \(address)")
        }

        return try baseURL
            .appendingPathComponent("address")
            .appendingPathComponent(bech32Address)
    }

    /// Returns a URL to view the given block on CardanoScan.
    ///
    /// CardanoScan requires blocks to be identified by their block number.
    ///
    /// - Parameter block: A block identifier. Must be ``BlockNumberOrBodyHash/number(_:)``.
    /// - Returns: A URL pointing to the block page on CardanoScan.
    /// - Throws: ``SwiftCardanoMultitoolError/valueError(_:)`` if a body hash
    ///   is provided instead of a block number.
    public func viewBlock(block: BlockNumberOrBodyHash) throws -> URL {
        guard case let .number(blockNumber) = block else {
            throw SwiftCardanoMultitoolError
                .valueError(
                    "CardanoScan only supports block number for block URLs"
                )
        }
        return try baseURL
            .appendingPathComponent("blocks")
            .appendingPathComponent(String(blockNumber))
    }

    /// Returns a URL to view the given stake pool on CardanoScan.
    ///
    /// The pool is looked up by its bech32-encoded pool ID.
    ///
    /// - Parameter pool: The pool operator to look up.
    /// - Returns: A URL pointing to the pool page on CardanoScan.
    /// - Throws: ``SwiftCardanoMultitoolError/invalidPool(_:)`` if the pool ID
    ///   cannot be converted to bech32.
    public func viewPool(pool: PoolOperator) throws -> URL {
        let poolId: String
        do {
            poolId = try pool.id(.bech32)
        } catch {
            throw SwiftCardanoMultitoolError
                .invalidPool("Unable to convert pool ID to bech32: \(pool)")
        }

        return try baseURL
            .appendingPathComponent("pool")
            .appendingPathComponent(poolId)
    }

    /// Returns a URL to view the given transaction on CardanoScan.
    ///
    /// - Parameter transactionId: The transaction identifier to look up.
    /// - Returns: A URL pointing to the transaction page on CardanoScan.
    public func viewTransaction(transactionId: TransactionId) throws -> URL {
        return try baseURL
            .appendingPathComponent("transaction")
            .appendingPathComponent(transactionId.payload.toHex)
    }
}
