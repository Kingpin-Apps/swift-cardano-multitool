import Foundation
import ArgumentParser
import Noora
import Configuration
import ConfigurationTOML
import TOML
import Yams
import SystemPackage
import SwiftCardanoUtils
import SwiftCardanoCore
import SwiftCardanoChain
import Logging

// MARK: - MultitoolConfigs Models
@dynamicMemberLookup
struct MultitoolConfigs: Sendable {
    public var configs: [String: FilePath]
    
    subscript(dynamicMember key: String) -> FilePath? {
        get { configs[key] }
        set { configs[key] = newValue }
    }
    
    var keys: Dictionary<String, FilePath>.Keys {
        configs.keys
    }
    
    var values: Dictionary<String, FilePath>.Values {
        configs.values
    }
    
    public init(configs: [String: FilePath]) {
        self.configs = configs
    }
}

// MARK: - MultitoolConfigs Codable
extension MultitoolConfigs: Codable {
    private enum CodingKeys: String, CodingKey {
        case configs
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let configsDict = try container.decode([String: String].self, forKey: .configs)
        self.configs = configsDict.mapValues { FilePath($0) }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let configsDict = configs.mapValues { $0.string }
        try container.encode(configsDict, forKey: .configs)
    }
    
    /// Save the JSON representation to a file.
    /// Save the JSON representation to a file.
    /// - Parameter path: The file path.
    /// - Throws: An error if the file cannot be written.
    /// - Note: This method will not overwrite an existing file.
    func save(to path: FilePath, overwrite: Bool = false) throws {
        if FileManager.default.fileExists(atPath: path.string) && !overwrite {
            throw SwiftCardanoMultitoolError.fileAlreadyExists(path)
        }
        
        let data = try JSONEncoder().encode(self)
        try data.write(to: URL(fileURLWithPath: path.string), options: .atomic)
    }
    
    /// Load the configuration from the default path specified by the `CONFIG` environment variable.
    /// - Returns: The loaded configuration.
    /// - Throws: An error if the file cannot be read or parsed.
    /// - Note: Environment variables will override values in the JSON file.
    static func load() async throws -> MultitoolConfigs {
        guard let configPath = Environment.getFilePath(.configs) else {
            noora.error(.alert(
                "Unable to find configurations path.",
                takeaways: [
                    "Make sure the \(Environment.configs.rawValue) environment variable is set.",
                    "Ensure that your environment has access to the environment variables (e.g., not running in a sandboxed environment).",
                ]
            ))
            throw ExitCode.failure
        }
        
        return try await load(from: configPath)
    }
    
    /// Load the configuration from a JSON file.
    /// - Parameter path: The file path.
    /// - Returns: The loaded configuration.
    /// - Throws: An error if the file cannot be read or parsed.
    static func load(from path: FilePath) async throws -> MultitoolConfigs {
        
        guard FileManager.default.fileExists(atPath: path.string) else {
            noora.error(.alert(
                "Configuration file not found.",
                takeaways: [
                    "Make sure the configuration file exists at the specified path: \(path)",
                    "Ensure that your environment has access to the file (e.g., not running in a sandboxed environment).",
                ]
            ))
            throw ExitCode.failure
        }
        
        spacedPrint(
            "\nUsing configs from: \(.primary(path.string))"
        )
        
        let data = try Data(contentsOf: URL(fileURLWithPath: path.string))
        return try JSONDecoder().decode(MultitoolConfigs.self, from: data)
    }
}


/// Task-local override for the multitool config.
///
/// When set (typically by tests), `MultitoolConfig.load()` short-circuits and returns
/// the override instead of reading from `CARDANO_MULTITOOL_CONFIG`. Production never
/// sets this; the env-var path is always used in real runs.
public enum Configs {
    @TaskLocal public static var override: MultitoolConfig?
}

// MARK: - Configuration Models

/// Main configuration for `scm`.
///
/// Load from a JSON, TOML, or YAML file pointed to by the
/// `CARDANO_MULTITOOL_CONFIG` environment variable, or by calling
/// `MultitoolConfig.load()`. Individual fields can be overridden by
/// environment variables (e.g. `BLOCKFROST_PROJECT_ID`).
///
/// See <doc:Configuration> for a full field reference and file format examples.
public struct MultitoolConfig: Codable, Sendable {
    /// Blockfrost project ID for API access
    public var blockfrostProjectId: String?
    
    /// API key for Koios access
    public var koiosApiKey: String?
    
    /// Cardano node and CLI configuration
    public var cardano: CardanoConfig?
    
    /// Mithril ClientI configuration
    public var mithril: MithrilConfig?
    
    /// Ogmios configuration
    public var ogmios: OgmiosConfig?
    
    /// Kupo configuration
    public var kupo: KupoConfig?
    
    /// Operation mode (Auto, Online, Offline, Lite)
    public var mode: Mode
    
    /// Path to offline transfer file
    @FilePathCodable
    public var offlineFile: FilePath?
    
    /// Token metadata server URLs for different networks
    public var tokenMetaServer: TokenMetaServerURLs
    
    /// The blockchain explorer to use
    public var blockchainExplorer: BlockchainExplorer
    
    /// ADA handle policy IDs for different networks
    public var adaHandlePolicy: AdaHandlePolicyIds
    
    /// Log level (info, debug, warn, error)
    public var logLevel: Logger.Level?
    
    /// Whether to show version information
    public var showVersionInfo: Bool?
    
    /// Whether to query token registry
    public var queryTokenRegistry: Bool?
    
    /// Whether to crop transaction output
    public var cropTxOutput: Bool?
    
    /// Maximum retry attempts for API calls
    public var maxRetryAttempts: Int?
    
    /// Base delay for exponential backoff (milliseconds)
    public var baseRetryDelay: UInt64?
    
    /// The number of Byron Epochs before the Chain forks to Shelley-Era
    private var _byronToShelleyEpoch: UInt64?
    public var byronToShelleyEpoch: UInt64 {
        get throws {
            if let cardano = self.cardano {
                switch cardano.network {
                    case .mainnet:
                        return 208
                    case .preprod:
                        return 4
                    case .preview:
                        return 0
                    case .guildnet:
                        return 2
                    default:
                        return _byronToShelleyEpoch ?? 0
                }
            }
            return _byronToShelleyEpoch ?? 0
        }
//        set {
//            _byronToShelleyEpoch = newValue
//        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case blockfrostProjectId = "blockfrost_project_id"
        case koiosApiKey = "koios_api_key"
        case cardano
        case mithril
        case ogmios
        case kupo
        case mode
        case offlineFile = "offline_file"
        case tokenMetaServer = "token_meta_server"
        case blockchainExplorer = "blockchain_explorer"
        case adaHandlePolicy = "ada_handle_policy"
        case logLevel = "log_level"
        case showVersionInfo = "show_version_info"
        case queryTokenRegistry = "query_token_registry"
        case cropTxOutput = "crop_tx_output"
        case maxRetryAttempts = "max_retry_attempts"
        case baseRetryDelay = "base_retry_delay"
        case byronToShelleyEpoch = "byron_to_shelley_epoch"
        
        var configKey: ConfigKey {
            return ConfigKey(self.rawValue)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.blockfrostProjectId = try container.decodeIfPresent(String.self, forKey: .blockfrostProjectId)
        self.koiosApiKey = try container.decodeIfPresent(String.self, forKey: .koiosApiKey)
        self.cardano = try container.decodeIfPresent(CardanoConfig.self, forKey: .cardano)
        self.mithril = try container.decodeIfPresent(MithrilConfig.self, forKey: .mithril)
        self.ogmios = try container.decodeIfPresent(OgmiosConfig.self, forKey: .ogmios)
        self.kupo = try container.decodeIfPresent(KupoConfig.self, forKey: .kupo)
        self.mode = try container.decodeIfPresent(Mode.self, forKey: .mode) ?? .auto
        let offlineFileStr = try container.decodeIfPresent(String.self, forKey: .offlineFile)
        self.offlineFile = offlineFileStr.map { FilePath($0) }
        self.tokenMetaServer = try container.decode(TokenMetaServerURLs.self, forKey: .tokenMetaServer)
        self.blockchainExplorer = try container.decodeIfPresent(BlockchainExplorer.self, forKey: .blockchainExplorer) ?? .cexplorer
        self.adaHandlePolicy = try container.decode(AdaHandlePolicyIds.self, forKey: .adaHandlePolicy)
        self.logLevel = try container.decodeIfPresent(Logger.Level.self, forKey: .logLevel)
        self.showVersionInfo = try container.decodeIfPresent(Bool.self, forKey: .showVersionInfo)
        self.queryTokenRegistry = try container.decodeIfPresent(Bool.self, forKey: .queryTokenRegistry)
        self.cropTxOutput = try container.decodeIfPresent(Bool.self, forKey: .cropTxOutput)
        self.maxRetryAttempts = try container.decodeIfPresent(Int.self, forKey: .maxRetryAttempts)
        self.baseRetryDelay = try container.decodeIfPresent(UInt64.self, forKey: .baseRetryDelay)
        // Decode the optional stored epoch into the private backing store
        self._byronToShelleyEpoch = try container.decodeIfPresent(UInt64.self, forKey: .byronToShelleyEpoch)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(blockfrostProjectId, forKey: .blockfrostProjectId)
        try container.encodeIfPresent(koiosApiKey, forKey: .koiosApiKey)
        try container.encodeIfPresent(cardano, forKey: .cardano)
        try container.encodeIfPresent(mithril, forKey: .mithril)
        try container.encodeIfPresent(ogmios, forKey: .ogmios)
        try container.encodeIfPresent(kupo, forKey: .kupo)
        try container.encode(mode, forKey: .mode)
        try container.encodeIfPresent(offlineFile?.string, forKey: .offlineFile)
        try container.encode(tokenMetaServer, forKey: .tokenMetaServer)
        try container.encode(blockchainExplorer, forKey: .blockchainExplorer)
        try container.encode(adaHandlePolicy, forKey: .adaHandlePolicy)
        try container.encodeIfPresent(logLevel, forKey: .logLevel)
        try container.encodeIfPresent(showVersionInfo, forKey: .showVersionInfo)
        try container.encodeIfPresent(queryTokenRegistry, forKey: .queryTokenRegistry)
        try container.encodeIfPresent(cropTxOutput, forKey: .cropTxOutput)
        try container.encodeIfPresent(maxRetryAttempts, forKey: .maxRetryAttempts)
        try container.encodeIfPresent(baseRetryDelay, forKey: .baseRetryDelay)
        // Only encode the explicit override for byron->shelley epoch if it was provided
        try container.encodeIfPresent(_byronToShelleyEpoch, forKey: .byronToShelleyEpoch)
    }
    
    public init(
        blockfrostProjectId: String? = nil,
        cardano: CardanoConfig? = nil,
        mithril: MithrilConfig? = nil,
        ogmios: OgmiosConfig? = nil,
        kupo: KupoConfig? = nil,
        mode: Mode = .auto,
        offlineFile: FilePath? = nil,
        tokenMetaServer: TokenMetaServerURLs,
        blockchainExplorer: BlockchainExplorer = .cexplorer,
        adaHandlePolicy: AdaHandlePolicyIds,
        logLevel: Logger.Level? = .info,
        showVersionInfo: Bool? = true,
        queryTokenRegistry: Bool? = true,
        cropTxOutput: Bool? = true,
        maxRetryAttempts: Int? = 5,
        baseRetryDelay: UInt64? = 200,
        byronToShelleyEpoch: UInt64? = 208
    ) {
        self.blockfrostProjectId = blockfrostProjectId
        self.cardano = cardano
        self.mithril = mithril
        self.ogmios = ogmios
        self.kupo = kupo
        self.mode = mode
        self.offlineFile = offlineFile
        self.tokenMetaServer = tokenMetaServer
        self.blockchainExplorer = blockchainExplorer
        self.adaHandlePolicy = adaHandlePolicy
        self.logLevel = logLevel
        self.showVersionInfo = showVersionInfo
        self.queryTokenRegistry = queryTokenRegistry
        self.cropTxOutput = cropTxOutput
        self.maxRetryAttempts = maxRetryAttempts
        self.baseRetryDelay = baseRetryDelay
        self._byronToShelleyEpoch = byronToShelleyEpoch ?? 208
    }
    
    /// Creates a new MultitoolConfig using values from the provided reader.
    ///
    /// - Parameter config: The config reader to read configuration values from.
    public init(config: ConfigReader) {
        
        self.blockfrostProjectId = config.string(
            forKey: CodingKeys.blockfrostProjectId.configKey
        )
        
        self.koiosApiKey = config.string(
            forKey: CodingKeys.koiosApiKey.configKey
        )
        
        self.cardano = try? CardanoConfig(config: config)
        self.mithril = try? MithrilConfig(config: config)
        self.ogmios = try? OgmiosConfig(config: config)
        self.kupo = try? KupoConfig(config: config)
        
        self.mode = config.string(
            forKey: CodingKeys.mode.configKey,
            as: Mode.self,
            default: .auto,
        )
        
        self.offlineFile = config.string(
            forKey: CodingKeys.offlineFile.configKey,
            as: FilePath.self
        )
        
        self.tokenMetaServer = TokenMetaServerURLs(
            mainnet: config.string(
                forKey: ConfigKey("\(CodingKeys.tokenMetaServer.rawValue).mainnet"),
                as: URL.self,
                default: URL(string: "https://tokens.cardano.org/metadata/")!
            ),
            preprod: config.string(
                forKey: ConfigKey("\(CodingKeys.tokenMetaServer.rawValue).preprod"),
                as: URL.self,
                default: URL(string: "https://metadata.cardano-testnet.iohkdev.io/metadata/")!
            ),
            preview: config.string(
                forKey: ConfigKey("\(CodingKeys.tokenMetaServer.rawValue).preview"),
                as: URL.self,
                default: URL(string: "https://metadata.cardano-testnet.iohkdev.io/metadata/")!
            )
        )
        
        self.blockchainExplorer = config.string(
            forKey: CodingKeys.blockchainExplorer.configKey,
            as: BlockchainExplorer.self,
            default: .cexplorer
        )
        
        self.adaHandlePolicy = AdaHandlePolicyIds(
            mainnet: config.string(
                forKey: ConfigKey("\(CodingKeys.adaHandlePolicy.rawValue).mainnet"),
                default: "f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a"
            ),
            preprod: config.string(
                forKey: ConfigKey("\(CodingKeys.adaHandlePolicy.rawValue).preprod"),
                default: "f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a"
            ),
            preview: config.string(
                forKey: ConfigKey("\(CodingKeys.adaHandlePolicy.rawValue).preview"),
                default: "f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a"
            )
        )
        
        self.logLevel = config.string(
            forKey: CodingKeys.logLevel.configKey,
            as: Logger.Level.self,
            default: .info
        )
        
        self.showVersionInfo = config.bool(
            forKey: CodingKeys.showVersionInfo.configKey,
            default: true
        )
        
        self.queryTokenRegistry = config.bool(
            forKey: CodingKeys.queryTokenRegistry.configKey,
            default: true
        )
        
        self.cropTxOutput = config.bool(
            forKey: CodingKeys.cropTxOutput.configKey,
            default: true
        )
        
        self.maxRetryAttempts = config.int(
            forKey: CodingKeys.maxRetryAttempts.configKey,
            default: 5
        )
        
        self.baseRetryDelay = UInt64(config.int(
            forKey: CodingKeys.baseRetryDelay.configKey,
            default: 200
        ))
        
        self._byronToShelleyEpoch = UInt64(config.int(
            forKey: CodingKeys.byronToShelleyEpoch.configKey,
            default: 208
        ))
    }
    
    static func `default`(network: Network = .mainnet) throws -> MultitoolConfig {
        let cwd = FilePath(FileManager.default.currentDirectoryPath)
        var cardanoConfig = try CardanoConfig.default()
        cardanoConfig.network = network
        return MultitoolConfig(
            blockfrostProjectId: Environment.get(.blockfrostProjectId),
            cardano: cardanoConfig,
            mithril: try? MithrilConfig.default(),
            ogmios: try? OgmiosConfig.default(),
            kupo: try? KupoConfig.default(),
            mode: .auto,
            offlineFile: cwd.appending("offline-transfer.json"),
            tokenMetaServer: TokenMetaServerURLs(),
            blockchainExplorer: .cexplorer,
            adaHandlePolicy: AdaHandlePolicyIds(),
            logLevel: .warning,
            showVersionInfo: true,
            queryTokenRegistry: true,
            cropTxOutput: true,
            maxRetryAttempts: 5,
            baseRetryDelay: 200,
            byronToShelleyEpoch: 208
        )
    }
    
    /// Save the configuration to a file, using JSON or TOML based on the file extension.
    /// - Parameters:
    ///   - path: The file path (.toml → TOML, anything else → JSON).
    ///   - overwrite: If false (default), throws if the file already exists.
    func save(to path: FilePath, overwrite: Bool = false) throws {
        if FileManager.default.fileExists(atPath: path.string) && !overwrite {
            throw SwiftCardanoMultitoolError.fileAlreadyExists(path)
        }
        let ext = path.extension?.lowercased()
        let data = ext == "toml" ? try encodeAsToml()
            : (ext == "yaml" || ext == "yml") ? try encodeAsYaml()
            : try encodeAsJson()
        try data.write(to: URL(fileURLWithPath: path.string), options: .atomic)
    }

    /// Save the configuration to a file using an explicit file type.
    /// - Parameters:
    ///   - path: The file path to write to.
    ///   - fileType: The format to use (json or toml).
    ///   - overwrite: If false (default), throws if the file already exists.
    func save(to path: FilePath, as fileType: ConfigFileType, overwrite: Bool = false) throws {
        if FileManager.default.fileExists(atPath: path.string) && !overwrite {
            throw SwiftCardanoMultitoolError.fileAlreadyExists(path)
        }
        let data: Data
        switch fileType {
            case .toml: data = try encodeAsToml()
            case .yaml: data = try encodeAsYaml()
            case .json: data = try encodeAsJson()
        }
        try data.write(to: URL(fileURLWithPath: path.string), options: .atomic)
    }

    func encodeAsYaml() throws -> Data {
        let yamlString = try YAMLEncoder().encode(self)
        return Data(yamlString.utf8)
    }

    func encodeAsJson() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    /// Encodes to TOML by going through JSON, stripping null values, then converting to TOML.
    /// This avoids the limitation that TOMLEncoder cannot encode nil optionals.
    func encodeAsToml() throws -> Data {
        let jsonData = try JSONEncoder().encode(self)
        guard let jsonObj = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw CocoaError(.coderInvalidValue)
        }
        let cleaned = Self.stripJsonNulls(jsonObj)
        return Data(Self.tomlFromDict(cleaned).utf8)
    }

    private static func stripJsonNulls(_ dict: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in dict {
            if value is NSNull { continue }
            if let nested = value as? [String: Any] {
                let stripped = stripJsonNulls(nested)
                if !stripped.isEmpty { result[key] = stripped }
            } else if let arr = value as? [Any] {
                result[key] = arr.compactMap { item -> Any? in
                    if item is NSNull { return nil }
                    if let d = item as? [String: Any] { return stripJsonNulls(d) }
                    return item
                }
            } else {
                result[key] = value
            }
        }
        return result
    }

    private static func tomlFromDict(_ dict: [String: Any], sectionPath: String = "") -> String {
        var scalars: [String] = []
        var tables: [(String, [String: Any])] = []

        for key in dict.keys.sorted() {
            let value = dict[key]!
            if let nested = value as? [String: Any] {
                tables.append((key, nested))
            } else if let arr = value as? [Any] {
                scalars.append("\(key) = \(tomlInlineArray(arr))")
            } else if let str = value as? String {
                scalars.append("\(key) = \(tomlQuotedString(str))")
            } else if let num = value as? NSNumber {
                scalars.append("\(key) = \(tomlNumber(num))")
            }
        }

        var parts = scalars
        for (key, nested) in tables {
            let fullPath = sectionPath.isEmpty ? key : "\(sectionPath).\(key)"
            parts.append("")
            parts.append("[\(fullPath)]")
            parts.append(tomlFromDict(nested, sectionPath: fullPath))
        }
        return parts.joined(separator: "\n")
    }

    private static func tomlQuotedString(_ str: String) -> String {
        let escaped = str
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }

    private static func tomlNumber(_ num: NSNumber) -> String {
        if CFBooleanGetTypeID() == CFGetTypeID(num) {
            return num.boolValue ? "true" : "false"
        }
        if num.doubleValue.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(num.int64Value)"
        }
        return "\(num.doubleValue)"
    }

    private static func tomlInlineArray(_ arr: [Any]) -> String {
        let items: [String] = arr.compactMap { item in
            if let str = item as? String { return tomlQuotedString(str) }
            if let num = item as? NSNumber { return tomlNumber(num) }
            if let nested = item as? [String: Any] {
                let pairs = nested.sorted(by: { $0.key < $1.key }).compactMap { (k, v) -> String? in
                    if let s = v as? String { return "\(k) = \(tomlQuotedString(s))" }
                    if let n = v as? NSNumber { return "\(k) = \(tomlNumber(n))" }
                    return nil
                }
                return "{\(pairs.joined(separator: ", "))}"
            }
            return nil
        }
        return "[\(items.joined(separator: ", "))]"
    }

    /// Load the configuration from the default path specified by the `CONFIG` environment variable.
    /// - Parameter quiet: If true, suppresses debug output.
    /// - Returns: The loaded configuration.
    /// - Throws: An error if the file cannot be read or parsed.
    /// - Note: Environment variables will override values in the JSON file.
    static func load(quiet: Bool = false) async throws -> MultitoolConfig {
        if let override = Configs.override {
            return override
        }
        guard let configPath = Environment.getFilePath(.config) else {
            noora.error(.alert("Unable to find configuration path.", takeaways: [
                "Make sure the \(Environment.config.rawValue) environment variable is set.",
                "Ensure that your environment has access to the environment variables (e.g., not running in a sandboxed environment).",
            ]))
            throw ExitCode.failure
        }
        
        guard FileManager.default.fileExists(atPath: configPath.string) else {
            noora.error(.alert("Configuration file not found.", takeaways: [
                "Make sure the configuration file exists at the specified path: \(configPath)",
                "Ensure that your environment has access to the file (e.g., not running in a sandboxed environment).",
            ]))
            throw ExitCode.failure
        }
        
        let absolute = FileManager.default.currentDirectoryPath + "/" + configPath.string

        if !quiet {
            spacedPrint(
                "\nUsing config from: \(.path(try .init(validating: "/" + absolute)))"
            )
        }
        
        
        return try await load(from: configPath)
    }
    
    /// Load the configuration from a JSON file.
    /// - Parameter path: The file path.
    /// - Returns: The loaded configuration.
    /// - Throws: An error if the file cannot be read or parsed.
    /// - Note: Environment variables will override values in the JSON file.
    static func load(from path: FilePath) async throws -> MultitoolConfig {
        let ext = path.extension?.lowercased()
        var providers: [any ConfigProvider] = [EnvironmentVariablesProvider()]
        if ext == "toml" {
            providers.append(try await FileProvider<TOMLSnapshot>(
                parsingOptions: .default,
                filePath: path
            ))
        } else if ext == "yaml" || ext == "yml" {
            providers.append(try await FileProvider<YAMLSnapshot>(
                filePath: path
            ))
        } else {
            providers.append(try await FileProvider<JSONSnapshot>(
                filePath: path,
                allowMissing: false
            ))
        }
        
        let config = ConfigReader(providers: providers)
        return MultitoolConfig(config: config)
    }
    
    func toSwiftCardanoUtilsConfig() -> SwiftCardanoUtils.Config {
        return Config(
            cardano: self.cardano,
            ogmios: self.ogmios,
            kupo: self.kupo
        )
    }
}

public struct NetworkURLs: NetworkDependable {
    public typealias T = URL
    
    public var mainnet: URL
    public var preprod: URL?
    public var preview: URL?
    public var guildnet: URL?
    
    init(
        mainnet: URL,
        preprod: URL? = nil,
        preview: URL? = nil,
        guildnet: URL? = nil
    ) {
        self.mainnet = mainnet
        self.preprod = preprod
        self.preview = preview
        self.guildnet = guildnet
    }
}

public struct TokenMetaServerURLs: NetworkDependable {
    public typealias T = URL
    
    public var mainnet: URL
    public var preprod: URL?
    public var preview: URL?
    public var guildnet: URL?
    
    init(
        mainnet: URL = URL(string: "https://tokens.cardano.org/metadata/")!,
        preprod: URL? = URL(string: "https://metadata.cardano-testnet.iohkdev.io/metadata/")!,
        preview: URL? = URL(string: "https://metadata.cardano-testnet.iohkdev.io/metadata/")!,
        guildnet: URL? = nil
    ) {
        self.mainnet = mainnet
        self.preprod = preprod
        self.preview = preview
        self.guildnet = guildnet
    }
}

public struct AdaHandlePolicyIds: NetworkDependable {
    public typealias T = String
    
    public var mainnet: String
    public var preprod: String?
    public var preview: String?
    public var guildnet: String?
    
    init(
        mainnet: String = "f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a",
        preprod: String? = "f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a",
        preview: String? = "f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a",
        guildnet: String? = nil
    ) {
        self.mainnet = mainnet
        self.preprod = preprod
        self.preview = preview
        self.guildnet = guildnet
    }
}

