import Foundation
import SwiftCardanoCore

/// A type that represents a block identifier, either by its number or body hash.
///
/// Use this enum when you need to reference a specific block on the Cardano blockchain.
/// Different blockchain explorers may require different identifier types:
/// - Some explorers (e.g., CardanoScan, PoolTool) use block numbers.
/// - Others (e.g., AdaStat, Cexplorer, Eutxo) use block body hashes.
public enum BlockNumberOrBodyHash: Codable, CustomStringConvertible, Sendable {
    /// A block identified by its sequential block number.
    case number(BlockNumber)
    /// A block identified by its body hash.
    case bodyHash(BlockBodyHash)

    public var description: String {
        switch self {
            case .bodyHash(let hash): return "Block Hash: \(hash)"
            case .number(let number): return "Block Number: \(number)"
        }
    }
}


/// A protocol that defines the interface for Cardano blockchain explorers.
///
/// Conforming types provide URL generation for viewing various Cardano blockchain
/// entities (accounts, addresses, blocks, pools, and transactions) on a specific
/// explorer service.
///
/// Default implementations are provided for all `view*` methods that throw
/// ``SwiftCardanoMultitoolError/notImplemented(_:)`` — conforming types only need
/// to override the methods they support.
///
/// ## Conforming to BlockchainExplorable
///
/// To create a new blockchain explorer, implement the required properties and
/// override the `view*` methods your explorer supports:
///
/// ```swift
/// struct MyExplorer: BlockchainExplorable {
///     let network: Network
///     let networkUrls: NetworkURLs = NetworkURLs(
///         mainnet: URL(string: "https://myexplorer.io")!
///     )
///
///     func viewTransaction(transactionId: TransactionId) throws -> URL {
///         try baseURL.appendingPathComponent("tx")
///             .appendingPathComponent(transactionId.payload.toHex)
///     }
/// }
/// ```
public protocol BlockchainExplorable: Sendable {
    /// The Cardano network this explorer instance targets.
    var network: Network { get }
    /// The set of base URLs for each supported network.
    var networkUrls: NetworkURLs { get }

    /// Returns a URL to view the account (stake key) associated with the given address.
    /// - Parameter address: A Cardano address containing a staking part.
    /// - Returns: A URL pointing to the account page on the explorer.
    /// - Throws: ``SwiftCardanoMultitoolError`` if the address is invalid or the operation is unsupported.
    func viewAccount(address: Address) throws -> URL

    /// Returns a URL to view the given address on the explorer.
    /// - Parameter address: A Cardano address to look up.
    /// - Returns: A URL pointing to the address page on the explorer.
    /// - Throws: ``SwiftCardanoMultitoolError`` if the address is invalid or the operation is unsupported.
    func viewAddress(address: Address) throws -> URL

    /// Returns a URL to view the given block on the explorer.
    /// - Parameter block: A block identifier (by number or body hash).
    /// - Returns: A URL pointing to the block page on the explorer.
    /// - Throws: ``SwiftCardanoMultitoolError`` if the block type is unsupported by this explorer.
    func viewBlock(block: BlockNumberOrBodyHash) throws -> URL

    /// Returns a URL to view the given stake pool on the explorer.
    /// - Parameter pool: The pool operator to look up.
    /// - Returns: A URL pointing to the pool page on the explorer.
    /// - Throws: ``SwiftCardanoMultitoolError`` if the pool ID cannot be converted or the operation is unsupported.
    func viewPool(pool: PoolOperator) throws -> URL

    /// Returns a URL to view the given transaction on the explorer.
    /// - Parameter transactionId: The transaction identifier to look up.
    /// - Returns: A URL pointing to the transaction page on the explorer.
    /// - Throws: ``SwiftCardanoMultitoolError`` if the operation is unsupported.
    func viewTransaction(transactionId: TransactionId) throws -> URL

    /// Returns a URL to view the given DRep on the explorer.
    /// - Parameter drep: The delegate representative to look up.
    /// - Returns: A URL pointing to the DRep page on the explorer.
    /// - Throws: ``SwiftCardanoMultitoolError`` if the DRep ID cannot be encoded or the operation is unsupported.
    func viewDRep(drep: DRep) throws -> URL

    /// Returns a URL to view the given governance action on the explorer.
    /// - Parameter govActionID: The governance action identifier to look up.
    /// - Returns: A URL pointing to the governance action page on the explorer.
    /// - Throws: ``SwiftCardanoMultitoolError`` if the governance action ID cannot be encoded or the operation is unsupported.
    func viewGovernanceAction(govActionID: GovActionID) throws -> URL

    /// Returns a URL to view the given constitutional committee member on the explorer.
    /// - Parameter committeeColdCredential: The cold credential identifying the committee member.
    /// - Returns: A URL pointing to the committee-member page on the explorer.
    /// - Throws: ``SwiftCardanoMultitoolError`` if the credential cannot be encoded or the operation is unsupported.
    func viewCommitteeMember(committeeColdCredential: CommitteeColdCredential) throws -> URL
}

extension BlockchainExplorable {

    /// The base URL for the explorer on the current ``network``.
    ///
    /// Resolves the appropriate URL from ``networkUrls`` based on the current network.
    /// - Throws: ``SwiftCardanoMultitoolError/notImplemented(_:)`` if the current network
    ///   is not configured, or ``SwiftCardanoMultitoolError/unsupportedNetwork(_:)`` for
    ///   unrecognized networks.
    public var baseURL: URL {
        get throws {
            switch network {
                case .mainnet:
                    return networkUrls.mainnet
                case .preprod:
                    if let url = networkUrls.preprod {
                        return url
                    } else {
                        throw SwiftCardanoMultitoolError.notImplemented("Preprod URL not configured for this explorer: \(Self.self)")
                    }
                case .preview:
                    if let url = networkUrls.preview {
                        return url
                    } else {
                        throw SwiftCardanoMultitoolError.notImplemented("Preview URL not configured for this explorer: \(Self.self)")
                    }
                default:
                    throw SwiftCardanoMultitoolError.unsupportedNetwork(network.description)
            }
        }
    }

    /// Default implementation that throws ``SwiftCardanoMultitoolError/notImplemented(_:)``.
    public func viewAccount(address: Address) throws -> URL {
        throw SwiftCardanoMultitoolError
            .notImplemented("viewAccount not implemented for this explorer: \(self)")
    }

    /// Default implementation that throws ``SwiftCardanoMultitoolError/notImplemented(_:)``.
    public func viewAddress(address: Address) throws -> URL {
        throw SwiftCardanoMultitoolError
            .notImplemented("viewAddress not implemented for this explorer: \(self)")
    }

    /// Default implementation that throws ``SwiftCardanoMultitoolError/notImplemented(_:)``.
    public func viewBlock(block: BlockNumberOrBodyHash) throws -> URL {
        throw SwiftCardanoMultitoolError
            .notImplemented("viewBlock not implemented for this explorer: \(self)")
    }

    /// Default implementation that throws ``SwiftCardanoMultitoolError/notImplemented(_:)``.
    public func viewPool(pool: PoolOperator) throws -> URL {
        throw SwiftCardanoMultitoolError
            .notImplemented("viewPool not implemented for this explorer: \(self)")
    }

    /// Default implementation that throws ``SwiftCardanoMultitoolError/notImplemented(_:)``.
    public func viewTransaction(transactionId: TransactionId) throws -> URL {
        throw SwiftCardanoMultitoolError
            .notImplemented("viewTransaction not implemented for this explorer: \(self)")
    }

    /// Default implementation that throws ``SwiftCardanoMultitoolError/notImplemented(_:)``.
    public func viewDRep(drep: DRep) throws -> URL {
        throw SwiftCardanoMultitoolError
            .notImplemented("viewDRep not implemented for this explorer: \(self)")
    }

    /// Default implementation that throws ``SwiftCardanoMultitoolError/notImplemented(_:)``.
    public func viewGovernanceAction(govActionID: GovActionID) throws -> URL {
        throw SwiftCardanoMultitoolError
            .notImplemented("viewGovernanceAction not implemented for this explorer: \(self)")
    }

    /// Default implementation that throws ``SwiftCardanoMultitoolError/notImplemented(_:)``.
    public func viewCommitteeMember(committeeColdCredential: CommitteeColdCredential) throws -> URL {
        throw SwiftCardanoMultitoolError
            .notImplemented("viewCommitteeMember not implemented for this explorer: \(self)")
    }
}

/// An enumeration of supported Cardano blockchain explorer services.
///
/// Use this enum to select a blockchain explorer and create a configured
/// instance for a specific network:
///
/// ```swift
/// let explorer = BlockchainExplorer.cardanoScan.explorer(network: .mainnet)
/// let url = try explorer.viewTransaction(transactionId: txId)
/// ```
///
/// ## Supported Explorers
///
/// | Case | Service |
/// | --- | --- |
/// | ``adaStat`` | [adastat.net](https://adastat.net) |
/// | ``cardanoScan`` | [cardanoscan.io](https://cardanoscan.io) |
/// | ``cexplorer`` | [cexplorer.io](https://cexplorer.io) |
/// | ``eutxo`` | [eutxo.org](https://eutxo.org) |
/// | ``pooltool`` | [pooltool.io](https://pooltool.io) |
public enum BlockchainExplorer: String, Codable, CaseIterable, CustomStringConvertible, Sendable {
    /// The AdaStat blockchain explorer at [adastat.net](https://adastat.net).
    case adaStat = "adastat"
    /// The CardanoScan blockchain explorer at [cardanoscan.io](https://cardanoscan.io).
    case cardanoScan = "cardanoscan"
    /// The Cexplorer blockchain explorer at [cexplorer.io](https://cexplorer.io).
    case cexplorer = "cexplorer"
    /// The Eutxo blockchain explorer at [eutxo.org](https://eutxo.org).
    case eutxo = "eutxo"
    /// The PoolTool blockchain explorer at [pooltool.io](https://pooltool.io).
    case pooltool = "pooltool"

    public var description: String {
        switch self {
            case .adaStat: return "Explore Cardano Blockchain using adastat.net."
            case .cardanoScan: return "Explore Cardano Blockchain using cardanoscan.io."
            case .cexplorer: return "ExploreCardano Blockchain using cexplorer.io."
            case .eutxo: return "Explore Cardano Blockchain using eutxo.org."
            case .pooltool: return "Explore Cardano Blockchain using pooltool.io."
        }
    }

    /// Creates a configured ``BlockchainExplorable`` instance for the given network.
    /// - Parameter network: The Cardano network to target.
    /// - Returns: A blockchain explorer instance configured for the specified network.
    public func explorer(network: Network) -> any BlockchainExplorable {
        switch self {
            case .adaStat: return AdaStat(network: network)
            case .cardanoScan: return CardanoScan(network: network)
            case .cexplorer: return Cexplorer(network: network)
            case .eutxo: return Eutxo(network: network)
            case .pooltool: return PoolTool(network: network)
        }
    }
}


