import Foundation
import CardanoCLITools
import Configuration

/// Transaction explorer protocol
public protocol TransactionExplorable: Sendable {
    func exploreTransaction(txHash: String, network: Network) async throws -> URL
}

/// Enum of supported blockchain explorers
public enum BlockchainExplorer: String, Codable, CaseIterable, CustomStringConvertible, Sendable {
    case adaStat = "adastat"
    case cardanoScan = "cardanoscan"
    case cexplorer = "cexplorer"
    case eutxo = "eutxo"
    
    public var description: String {
        switch self {
            case .adaStat: return "Explore transactions on adastat.net."
            case .cardanoScan: return "Explore transactions on cardanoscan.io."
            case .cexplorer: return "Explore transactions on cexplorer.io."
            case .eutxo: return "Explore transactions on eutxo.org."
        }
    }
    
    public func explorer() -> any TransactionExplorable {
        switch self {
            case .adaStat: return AdaStat()
            case .cardanoScan: return CardanoScan()
            case .cexplorer: return Cexplorer()
            case .eutxo: return Eutxo()
        }
    }
}

/// Transaction explorer for adastat.net
public struct AdaStat: TransactionExplorable {
    private let networkUrls: NetworkUrls = NetworkUrls(
        mainnet: URL(string: "https://adastat.net")!,
    )
    
    public func exploreTransaction(txHash: String, network: Network) async throws -> URL {
        switch network {
            case .mainnet:
                return networkUrls.mainnet
                    .appendingPathComponent("transactions")
                    .appendingPathComponent(txHash)
            default:
                throw CardanoSPOToolsError
                    .unsupportedNetwork(network.description)
        }
    }
}

/// Transaction explorer for cardanoscan.io
public struct CardanoScan: TransactionExplorable {
    private let networkUrls: NetworkUrls = NetworkUrls(
        mainnet: URL(string: "https://cardanoscan.io")!,
        preprod: URL(string: "https://preprod.cardanoscan.io")!,
        preview: URL(string: "https://preview.cardanoscan.io")!
    )
    
    public func exploreTransaction(txHash: String, network: Network) async throws -> URL {
        switch network {
            case .mainnet:
                return networkUrls.mainnet
                    .appendingPathComponent("transaction")
                    .appendingPathComponent(txHash)
            case .preprod:
                return networkUrls.preprod!
                    .appendingPathComponent("ttransaction")
                    .appendingPathComponent(txHash)
            case .preview:
                return networkUrls.preview!
                    .appendingPathComponent("transaction")
                    .appendingPathComponent(txHash)
            default:
                throw CardanoSPOToolsError
                    .unsupportedNetwork(network.description)
        }
    }
}

/// Transaction explorer for cexplorer.io
public struct Cexplorer: TransactionExplorable {
    private let networkUrls: NetworkUrls = NetworkUrls(
        mainnet: URL(string: "https://cexplorer.io")!,
        preprod: URL(string: "https://preprod.cexplorer.io")!,
        preview: URL(string: "https://preview.cexplorer.io")!
    )
    
    public func exploreTransaction(txHash: String, network: Network) async throws -> URL {
        switch network {
            case .mainnet:
                return networkUrls.mainnet
                    .appendingPathComponent("tx")
                    .appendingPathComponent(txHash)
            case .preprod:
                return networkUrls.preprod!
                    .appendingPathComponent("tx")
                    .appendingPathComponent(txHash)
            case .preview:
                return networkUrls.preview!
                    .appendingPathComponent("tx")
                    .appendingPathComponent(txHash)
            default:
                throw CardanoSPOToolsError
                    .unsupportedNetwork(network.description)
        }
    }
}

/// Transaction explorer for eutxo.org
public struct Eutxo: TransactionExplorable {
    private let networkUrls: NetworkUrls = NetworkUrls(
        mainnet: URL(string: "https://eutxo.org")!,
        preprod: URL(string: "https://preprod.cexplorer.io")!,
        preview: URL(string: "https://preview.cexplorer.io")!
    )
    
    public func exploreTransaction(txHash: String, network: Network) async throws -> URL {
        switch network {
            case .mainnet:
                return networkUrls.mainnet
                    .appendingPathComponent("transaction")
                    .appendingPathComponent(txHash)
            case .preprod:
                return networkUrls.preprod!
                    .appendingPathComponent("tx")
                    .appendingPathComponent(txHash)
            case .preview:
                return networkUrls.preview!
                    .appendingPathComponent("tx")
                    .appendingPathComponent(txHash)
            default:
                throw CardanoSPOToolsError
                    .unsupportedNetwork(network.description)
        }
    }
}
