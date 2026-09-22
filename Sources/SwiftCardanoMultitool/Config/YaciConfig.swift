import Configuration
import Foundation
import SwiftCardanoCore

/// Yaci DevKit configuration.
///
/// Yaci DevKit runs a throw-away local devnet. Chain data is read from the Yaci
/// Store REST API it embeds (port 8080 by default), and genesis comes from its
/// admin/cluster API (port 10000 by default), because the store serves none.
///
/// ```toml
/// mode = "devkit"
///
/// [yaci]
/// api_url = "http://localhost:8080"
/// admin_url = "http://localhost:10000"
/// network_magic = 42
/// ```
///
/// Every field is optional; the defaults match a DevKit started with
/// `yaci-devkit up` on the local machine.
public struct YaciConfig: Codable, Sendable, Equatable {
    /// Yaci Store's root, e.g. `http://localhost:8080`. A trailing `/api/v1` is
    /// accepted and dropped by the chain context.
    public var apiUrl: String?

    /// The DevKit admin (cluster) API, which serves the genesis documents.
    /// Defaults to port 10000 on the store's host.
    public var adminUrl: String?

    /// The devnet's protocol magic. DevKit's default is 42.
    public var networkMagic: Int?

    enum CodingKeys: String, CodingKey {
        case apiUrl = "api_url"
        case adminUrl = "admin_url"
        case networkMagic = "network_magic"
    }

    /// The network the devnet runs as, derived from ``networkMagic``.
    ///
    /// Any magic other than mainnet's maps to the testnet network id, so a
    /// devnet's addresses are always testnet addresses.
    public var network: Network {
        .custom(networkMagic ?? YaciConfig.defaultNetworkMagic)
    }

    /// DevKit's default protocol magic.
    public static let defaultNetworkMagic = 42

    public init(
        apiUrl: String? = nil,
        adminUrl: String? = nil,
        networkMagic: Int? = nil
    ) {
        self.apiUrl = apiUrl
        self.adminUrl = adminUrl
        self.networkMagic = networkMagic
    }

    /// Creates a new YaciConfig using values from the provided reader.
    ///
    /// - Parameter config: The config reader to read configuration values from.
    public init(config: ConfigReader) {
        func key(_ codingKey: CodingKeys) -> ConfigKey {
            ConfigKey("yaci.\(codingKey.rawValue)")
        }

        self.apiUrl = config.string(forKey: key(.apiUrl)).flatMap { $0.isEmpty ? nil : $0 }
        self.adminUrl = config.string(forKey: key(.adminUrl)).flatMap { $0.isEmpty ? nil : $0 }
        self.networkMagic = config.int(forKey: key(.networkMagic))
    }

    /// The configuration for a DevKit running with its default layout on this machine.
    public static func `default`() -> YaciConfig {
        YaciConfig(
            apiUrl: "http://localhost:8080",
            adminUrl: "http://localhost:10000",
            networkMagic: defaultNetworkMagic
        )
    }
}
