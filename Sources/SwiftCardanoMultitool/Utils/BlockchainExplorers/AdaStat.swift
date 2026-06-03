import Foundation
import SwiftCardanoCore

/// A blockchain explorer implementation for [AdaStat](https://adastat.net).
///
/// AdaStat provides mainnet-only exploration of the Cardano blockchain. It supports
/// viewing accounts, addresses, blocks, pools, and transactions.
///
/// - Note: AdaStat only supports mainnet. Attempting to use preprod or preview
///   networks will throw an error.
/// - Note: Block lookups require a ``BlockNumberOrBodyHash/bodyHash(_:)`` identifier.
///
/// ## Usage
///
/// ```swift
/// let explorer = AdaStat(network: .mainnet)
/// let url = try explorer.viewTransaction(transactionId: txId)
/// ```
public struct AdaStat: BlockchainExplorable {
    /// The Cardano network this explorer targets.
    public let network: Network

    /// The base URLs for each supported network.
    ///
    /// AdaStat only supports mainnet.
    public let networkUrls: NetworkURLs = NetworkURLs(
        mainnet: URL(string: "https://adastat.net")!,
    )

    /// Returns a URL to view the account associated with the given address on AdaStat.
    ///
    /// The account is looked up by the hex-encoded hash of the address's staking part.
    ///
    /// - Parameter address: A Cardano address that must contain a staking part.
    /// - Returns: A URL pointing to the account page on AdaStat.
    /// - Throws: ``SwiftCardanoMultitoolError/invalidAddress(_:)`` if the address
    ///   does not contain a staking part.
    public func viewAccount(address: Address) throws -> URL {
        guard let stakeAddressPart = address.stakingPart else {
            throw SwiftCardanoMultitoolError.invalidAddress("Address does not contain a staking part: \(address)")
        }

        return try baseURL
            .appendingPathComponent("accounts")
            .appendingPathComponent(stakeAddressPart.hash().toHex)
    }

    /// Returns a URL to view the given address on AdaStat.
    ///
    /// The address is converted to its bech32 representation for the URL path.
    ///
    /// - Parameter address: A Cardano address to look up.
    /// - Returns: A URL pointing to the address page on AdaStat.
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
            .appendingPathComponent("addresses")
            .appendingPathComponent(bech32Address)
    }

    /// Returns a URL to view the given block on AdaStat.
    ///
    /// AdaStat requires blocks to be identified by their body hash.
    ///
    /// - Parameter block: A block identifier. Must be ``BlockNumberOrBodyHash/bodyHash(_:)``.
    /// - Returns: A URL pointing to the block page on AdaStat.
    /// - Throws: ``SwiftCardanoMultitoolError/valueError(_:)`` if a block number
    ///   is provided instead of a body hash.
    public func viewBlock(block: BlockNumberOrBodyHash) throws -> URL {
        guard case let .bodyHash(bodyHash) = block else {
            throw SwiftCardanoMultitoolError
                .valueError(
                    "CardanoScan only supports block hash for block URLs"
                )
        }
        return try baseURL
            .appendingPathComponent("blocks")
            .appendingPathComponent(bodyHash.payload.toHex)
    }

    /// Returns a URL to view the given stake pool on AdaStat.
    ///
    /// The pool is looked up by its hex-encoded pool ID.
    ///
    /// - Parameter pool: The pool operator to look up.
    /// - Returns: A URL pointing to the pool page on AdaStat.
    /// - Throws: ``SwiftCardanoMultitoolError/invalidPool(_:)`` if the pool ID
    ///   cannot be converted to hex.
    public func viewPool(pool: PoolOperator) throws -> URL {
        let poolId: String
        do {
            poolId = try pool.id(.hex)
        } catch {
            throw SwiftCardanoMultitoolError
                .invalidPool("Unable to convert pool ID to hex: \(pool)")
        }

        return try baseURL
            .appendingPathComponent("pools")
            .appendingPathComponent(poolId)
    }

    /// Returns a URL to view the given transaction on AdaStat.
    ///
    /// - Parameter transactionId: The transaction identifier to look up.
    /// - Returns: A URL pointing to the transaction page on AdaStat.
    public func viewTransaction(transactionId: TransactionId) throws -> URL {
        return try baseURL
            .appendingPathComponent("transactions")
            .appendingPathComponent(transactionId.payload.toHex)
    }

    /// Returns a URL to view the given DRep on AdaStat.
    ///
    /// - Parameter drep: The DRep identifier to look up.
    /// - Returns: A URL pointing to the DRep page on AdaStat.
    public func viewDRep(drep: DRep) throws -> URL {
        return try baseURL
            .appendingPathComponent("dreps")
            .appendingPathComponent(drep.id((.bech32, .cip105)))
    }
    
    /// Returns a URL to view the given governance action on AdaStat.
    ///
    /// - Parameter govActionID: The governance action identifier to look up.
    /// - Returns: A URL pointing to the governance action page on AdaStat.
    public func viewGovernanceAction(govActionID: GovActionID) throws -> URL {
        return try baseURL
            .appendingPathComponent("governances")
            .appendingPathComponent(govActionID.id(.hex))
    }
}
