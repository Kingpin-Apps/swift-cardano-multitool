import Foundation
import ArgumentParser
import Noora
import Configuration
import SystemPackage
import SwiftCardanoUtils
import Logging

// MARK: - MultitoolConfigs Models
@dynamicMemberLookup
struct MultitoolConfigs: Codable, Sendable {
    public var configs: [String: FilePath] = [:]
    
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
    
    /// Creates a new MultitoolConfigs using values from the provided reader.
    ///
    /// - Parameter config: The config reader to read configuration values from.
    public init(config: ConfigReader) {
        self.configs = config.string(
            forKey: "configs",
            as: Dictionary<String, FilePath>.self
        ) ?? [:]
    }
    
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
        let noora = Noora(theme: Style.theme, content: Style.content)
        
        guard let configPath = Environment.getFilePath(.configs) else {
            noora.error(.alert("Unable to find configurations path.", takeaways: [
                "Make sure the \(Environment.configs.rawValue) environment variable is set.",
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
        
        print(noora.format(
            "Using config from: \(.primary(configPath.string))")
        )
        
        return try await load(from: configPath)
    }
    
    /// Load the configuration from a JSON file.
    /// - Parameter path: The file path.
    /// - Returns: The loaded configuration.
    /// - Throws: An error if the file cannot be read or parsed.
    /// - Note: Environment variables will override values in the JSON file.
    static func load(from path: FilePath) async throws -> MultitoolConfigs {
        
        let config = ConfigReader(providers: [
            EnvironmentVariablesProvider(),
            try await JSONProvider(filePath: .init(path.string))
        ])
        return MultitoolConfigs(config: config)
    }
}


// MARK: - Configuration Models

/// Main configuration structure for SwiftCardanoMultitool
public struct MultitoolConfig: Codable, Sendable {
    /// Blockfrost project ID for API access
    public var blockfrostProjectId: String?
    
    /// API key for Koios access
    public var koiosApiKey: String?
    
    /// Cardano node and CLI configuration
    public var cardano: CardanoConfig
    
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
    public var tokenMetaServer: NetworkUrls
    
    /// The blockchain explorer to use
    public var blockchainExplorer: BlockchainExplorer
    
    /// ADA handle policy IDs for different networks
    public var adaHandlePolicy: NetworkPolicyIds
    
    /// Log level (info, debug, warn, error)
    public var logLevel: Logger.Level?
    
    /// Whether to show version information
    public var showVersionInfo: Bool?
    
    /// Whether to query token registry
    public var queryTokenRegistry: Bool?
    
    /// Whether to crop transaction output
    public var cropTxOutput: Bool?
    
    private enum CodingKeys: String, CodingKey {
        case blockfrostProjectId = "blockfrost_project_id"
        case cardano
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
    }
    
    public init(
        blockfrostProjectId: String? = nil,
        cardano: CardanoConfig,
        ogmios: OgmiosConfig? = nil,
        kupo: KupoConfig? = nil,
        mode: Mode = .auto,
        offlineFile: FilePath? = nil,
        tokenMetaServer: NetworkUrls,
        blockchainExplorer: BlockchainExplorer = .cexplorer,
        adaHandlePolicy: NetworkPolicyIds,
        logLevel: Logger.Level? = .info,
        showVersionInfo: Bool? = true,
        queryTokenRegistry: Bool? = true,
        cropTxOutput: Bool? = true
    ) {
        self.blockfrostProjectId = blockfrostProjectId
        self.cardano = cardano
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
    }
    
    /// Creates a new MultitoolConfig using values from the provided reader.
    ///
    /// - Parameter config: The config reader to read configuration values from.
    public init(config: ConfigReader) {
        
        func key(_ codingKey: CodingKeys) -> String {
            return "\(codingKey)"
        }
        
        self.blockfrostProjectId = config.string(
            forKey: CodingKeys.blockfrostProjectId.rawValue
        )
        
        self.cardano = CardanoConfig(config: config)
        self.ogmios = try? OgmiosConfig(config: config)
        self.kupo = try? KupoConfig(config: config)
        
        self.mode = config.string(
            forKey: CodingKeys.mode.rawValue,
            as: Mode.self,
            default: .auto,
        )
        
        self.offlineFile = config.string(
            forKey: CodingKeys.offlineFile.rawValue,
            as: FilePath.self
        )
        
        self.tokenMetaServer = NetworkUrls(
            mainnet: config.string(
                forKey: "\(key(.tokenMetaServer)).mainnet",
                as: URL.self,
                default: URL(string: "https://tokens.cardano.org/metadata/")!
            ),
            preprod: config.string(
                forKey: "\(key(.tokenMetaServer)).preprod",
                as: URL.self,
                default: URL(string: "https://metadata.cardano-testnet.iohkdev.io/metadata/")!
            ),
            preview: config.string(
                forKey: "\(key(.tokenMetaServer)).preview",
                as: URL.self,
                default: URL(string: "https://metadata.cardano-testnet.iohkdev.io/metadata/")!
            )
        )
        
        self.blockchainExplorer = config.string(
            forKey: "\(key(.blockchainExplorer))",
            as: BlockchainExplorer.self,
            default: .cexplorer
        )
        
        self.adaHandlePolicy = NetworkPolicyIds(
            mainnet: config.string(
                forKey: "\(key(.adaHandlePolicy)).mainnet",
                default: "f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a"
            ),
            preprod: config.string(
                forKey: "\(key(.adaHandlePolicy)).preprod",
                default: "f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a"
            ),
            preview: config.string(
                forKey: "\(key(.adaHandlePolicy)).preview",
                default: "f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a"
            )
        )
        
        self.logLevel = config.string(
            forKey: "\(key(.logLevel))",
            as: Logger.Level.self,
            default: .info
        )
        
        self.showVersionInfo = config.bool(
            forKey: "\(key(.showVersionInfo))",
            default: true
        )
        
        self.queryTokenRegistry = config.bool(
            forKey: "\(key(.queryTokenRegistry))",
            default: true
        )
        
        self.cropTxOutput = config.bool(
            forKey: "\(key(.cropTxOutput))",
            default: true
        )
    }
    
    static func `default`() throws -> MultitoolConfig {
        let cwd = FilePath(FileManager.default.currentDirectoryPath)
        return MultitoolConfig(
            blockfrostProjectId: nil,
            cardano: try CardanoConfig.default(),
            ogmios: try? OgmiosConfig.default(),
            kupo: try? KupoConfig.default(),
            mode: .auto,
            offlineFile: cwd.appending("offline_transfer.json"),
            tokenMetaServer: NetworkUrls(
                mainnet: URL(string: "https://tokens.cardano.org/metadata/")!,
                preprod: URL(string: "https://metadata.cardano-testnet.iohkdev.io/metadata/")!,
                preview: URL(string: "https://metadata.cardano-testnet.iohkdev.io/metadata/")!
            ),
            blockchainExplorer: .cexplorer,
            adaHandlePolicy: NetworkPolicyIds(
                mainnet: "f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a",
                preprod: "f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a",
                preview: "f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a"
            ),
            logLevel: .warning,
            showVersionInfo: true,
            queryTokenRegistry: true,
            cropTxOutput: true
        )
    }
    
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
    static func load() async throws -> MultitoolConfig {
        let noora = try await Terminal.shared.noora()
        
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
        
        print(
            noora.format("Using config from: \(.path(try .init(validating: configPath.string)))"),
            terminator: "\n\n"
        )
        
        return try await load(from: configPath)
    }
    
    /// Load the configuration from a JSON file.
    /// - Parameter path: The file path.
    /// - Returns: The loaded configuration.
    /// - Throws: An error if the file cannot be read or parsed.
    /// - Note: Environment variables will override values in the JSON file.
    static func load(from path: FilePath) async throws -> MultitoolConfig {
        
        let config = ConfigReader(providers: [
            EnvironmentVariablesProvider(),
            try await JSONProvider(filePath: .init(path.string))
        ])
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

public struct NetworkUrls: Codable, Hashable, Sendable {
    public var mainnet: URL
    public var preprod: URL?
    public var preview: URL?
    public var guildnet: URL?
    
    public init(
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
    
    private enum CodingKeys: String, CodingKey {
        case mainnet
        case preprod
        case preview
        case guildnet
    }
}

public struct NetworkPolicyIds: Codable, Hashable, Sendable {
    public var mainnet: String
    public var preprod: String
    public var preview: String
    public var guildnet: String?
    
    public init(
        mainnet: String,
        preprod: String,
        preview: String,
        guildnet: String? = nil
    ) {
        self.mainnet = mainnet
        self.preprod = preprod
        self.preview = preview
        self.guildnet = guildnet
    }
    
    private enum CodingKeys: String, CodingKey {
        case mainnet
        case preprod
        case preview
        case guildnet
    }
}

