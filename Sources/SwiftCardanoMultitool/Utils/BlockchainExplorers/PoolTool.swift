import Foundation
import SwiftCardanoCore

/// A blockchain explorer implementation for [PoolTool](https://pooltool.io).
///
/// PoolTool is a mainnet-only explorer focused on stake pool analytics. It supports
/// viewing accounts, blocks, and pools. It does not support address or transaction
/// lookups — those methods will throw ``SwiftCardanoMultitoolError/notImplemented(_:)``
/// via the default protocol implementation.
///
/// - Note: PoolTool only supports mainnet. Attempting to use preprod or preview
///   networks will throw an error.
/// - Note: Block lookups require a ``BlockNumberOrBodyHash/number(_:)`` identifier.
///
/// ## Usage
///
/// ```swift
/// let explorer = PoolTool(network: .mainnet)
/// let url = try explorer.viewPool(pool: poolOperator)
/// ```
public struct PoolTool: BlockchainExplorable {
    /// The Cardano network this explorer targets.
    public let network: Network

    /// The base URLs for each supported network.
    ///
    /// PoolTool only supports mainnet.
    public let networkUrls: NetworkURLs = NetworkURLs(
        mainnet: URL(string: "https://pooltool.io")!,
    )

    /// Returns a URL to view the account associated with the given address on PoolTool.
    ///
    /// The account is looked up by the hex-encoded hash of the address's staking part.
    ///
    /// - Parameter address: A Cardano address that must contain a staking part.
    /// - Returns: A URL pointing to the address page on PoolTool.
    /// - Throws: ``SwiftCardanoMultitoolError/invalidAddress(_:)`` if the address
    ///   does not contain a staking part.
    public func viewAccount(address: Address) throws -> URL {
        guard let stakeAddressPart = address.stakingPart else {
            throw SwiftCardanoMultitoolError.invalidAddress("Address does not contain a staking part: \(address)")
        }

        return try baseURL
            .appendingPathComponent("address")
            .appendingPathComponent(stakeAddressPart.hash().toHex)
    }

    /// Returns a URL to view the given block on PoolTool.
    ///
    /// PoolTool requires blocks to be identified by their block number, displayed
    /// on the realtime page.
    ///
    /// - Parameter block: A block identifier. Must be ``BlockNumberOrBodyHash/number(_:)``.
    /// - Returns: A URL pointing to the realtime block page on PoolTool.
    /// - Throws: ``SwiftCardanoMultitoolError/valueError(_:)`` if a body hash
    ///   is provided instead of a block number.
    public func viewBlock(block: BlockNumberOrBodyHash) throws -> URL {
        guard case let .number(blockNumber) = block else {
            throw SwiftCardanoMultitoolError
                .valueError(
                    "PoolTool only supports block number for block URLs"
                )
        }
        return try baseURL
            .appendingPathComponent("realtime")
            .appendingPathComponent(String(blockNumber))
    }

    /// Returns a URL to view the given stake pool on PoolTool.
    ///
    /// The pool is looked up by its hex-encoded pool key hash.
    ///
    /// - Parameter pool: The pool operator to look up.
    /// - Returns: A URL pointing to the pool page on PoolTool.
    public func viewPool(pool: PoolOperator) throws -> URL {
        return try baseURL
            .appendingPathComponent("pool")
            .appendingPathComponent(pool.poolKeyHash.payload.toHex)
    }
}
