import Configuration
import Foundation
import UTxORPCClient

/// UTxO RPC configuration.
///
/// A UTxO RPC server answers UTxO lookups, protocol parameters, the tip,
/// submission and script evaluation. When this block has a `url`, `scm` puts
/// the server in front of the context its `mode` picks, which still answers
/// the stake, pool and governance queries UTxO RPC has no calls for.
///
/// ```toml
/// # cardano-node 11.x started with "EnableRpc": true
/// [utxorpc]
/// url = "unix:///opt/cardano/mainnet/socket/rpc.sock"
///
/// # Demeter
/// [utxorpc]
/// url = "https://cardano-preview.utxorpc-m1.demeter.run"
/// api_key = "dmtr_utxorpc..."
///
/// # cardano-node-api
/// [utxorpc]
/// url = "http://127.0.0.1:9090"
/// api_version = "v1alpha"
/// ```
///
/// The API key can come from the `UTXORPC_API_KEY` environment variable
/// instead of the file.
public struct UTxORPCConfig: Codable, Sendable, Equatable {
    /// The server: `https://host[:port]`, `http://host[:port]` or
    /// `unix:///path/to/rpc.sock`.
    public var url: String?

    /// API key sent with every call, in the ``apiKeyHeader`` header.
    public var apiKey: String?

    /// Header the API key travels in. Defaults to Demeter's `dmtr-api-key`.
    public var apiKeyHeader: String?

    /// `v1beta` (the default) or `v1alpha` for cardano-node-api.
    public var apiVersion: String?

    enum CodingKeys: String, CodingKey {
        case url
        case apiKey = "api_key"
        case apiKeyHeader = "api_key_header"
        case apiVersion = "api_version"
    }

    /// Demeter's API key header.
    public static let defaultAPIKeyHeader = "dmtr-api-key"

    public init(
        url: String? = nil,
        apiKey: String? = nil,
        apiKeyHeader: String? = nil,
        apiVersion: String? = nil
    ) {
        self.url = url
        self.apiKey = apiKey
        self.apiKeyHeader = apiKeyHeader
        self.apiVersion = apiVersion
    }

    /// Reads the `[utxorpc]` block, or returns `nil` when it has no `url`.
    ///
    /// - Parameter config: The config reader to read configuration values from.
    public init?(config: ConfigReader) {
        func key(_ codingKey: CodingKeys) -> ConfigKey {
            ConfigKey("utxorpc.\(codingKey.rawValue)")
        }

        guard let url = config.string(forKey: key(.url)), !url.isEmpty else { return nil }
        self.url = url
        self.apiKey = config.string(forKey: key(.apiKey)).flatMap { $0.isEmpty ? nil : $0 }
        self.apiKeyHeader = config.string(forKey: key(.apiKeyHeader)).flatMap { $0.isEmpty ? nil : $0 }
        self.apiVersion = config.string(forKey: key(.apiVersion)).flatMap { $0.isEmpty ? nil : $0 }
    }

    /// The endpoint this block describes.
    public func endpoint() throws -> UTxORPCEndpoint {
        guard let url, let parsed = URL(string: url) else {
            throw SwiftCardanoMultitoolError.invalidConfiguration(
                "[utxorpc] url is missing or not a URL: \(url ?? "nil")"
            )
        }
        let version: UTxORPCAPIVersion
        if let apiVersion {
            guard let known = UTxORPCAPIVersion(rawValue: apiVersion) else {
                throw SwiftCardanoMultitoolError.invalidConfiguration(
                    "[utxorpc] api_version must be v1beta or v1alpha, not \(apiVersion)"
                )
            }
            version = known
        } else {
            version = .v1beta
        }
        var headers: [String: String] = [:]
        if let apiKey {
            headers[apiKeyHeader ?? Self.defaultAPIKeyHeader] = apiKey
        }
        return try UTxORPCEndpoint(url: parsed, headers: headers, apiVersion: version)
    }
}
