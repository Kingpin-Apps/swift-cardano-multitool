import Foundation
import SystemPackage
import Testing
import Configuration
import SwiftCardanoCore
import SwiftCardanoChain
@testable import SwiftCardanoMultitool

@Suite("MultitoolConfigs")
struct MultitoolConfigsTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("dynamic member lookup returns stored paths")
    func dynamicMemberLookup() {
        let cfgs = MultitoolConfigs(configs: [
            "mainnet": FilePath("/etc/main.json"),
            "preview": FilePath("/etc/preview.json")
        ])
        #expect(cfgs.mainnet == FilePath("/etc/main.json"))
        #expect(cfgs.preview == FilePath("/etc/preview.json"))
        #expect(cfgs.absent == nil)
    }

    @Test("JSON encode/decode round-trip preserves paths")
    func codableRoundTrip() throws {
        let original = MultitoolConfigs(configs: [
            "mainnet": FilePath("/etc/scm/main.json"),
            "preview": FilePath("/etc/scm/preview.json")
        ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MultitoolConfigs.self, from: data)
        #expect(decoded.configs == original.configs)
    }

    @Test("save followed by direct decode round-trips through the filesystem")
    func saveLoadRoundTrip() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = FilePath(dir.appendingPathComponent("configs.json").path)
        let original = MultitoolConfigs(configs: ["mainnet": FilePath("/tmp/x.json")])
        try original.save(to: path)
        let data = try Data(contentsOf: URL(fileURLWithPath: path.string))
        let decoded = try JSONDecoder().decode(MultitoolConfigs.self, from: data)
        #expect(decoded.configs == original.configs)
    }

    @Test("save throws when the file exists and overwrite is false")
    func saveRefusesOverwriteByDefault() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = FilePath(dir.appendingPathComponent("configs.json").path)
        let cfgs = MultitoolConfigs(configs: ["mainnet": FilePath("/tmp/a.json")])
        try cfgs.save(to: path)
        #expect(throws: SwiftCardanoMultitoolError.self) {
            try cfgs.save(to: path)
        }
    }

    @Test("save overwrites when overwrite is true")
    func saveAllowsOverwriteWhenAsked() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = FilePath(dir.appendingPathComponent("configs.json").path)
        let first = MultitoolConfigs(configs: ["mainnet": FilePath("/tmp/a.json")])
        let second = MultitoolConfigs(configs: ["mainnet": FilePath("/tmp/b.json")])
        try first.save(to: path)
        try second.save(to: path, overwrite: true)
        let data = try Data(contentsOf: URL(fileURLWithPath: path.string))
        let decoded = try JSONDecoder().decode(MultitoolConfigs.self, from: data)
        #expect(decoded.configs == second.configs)
    }
}

@Suite("MultitoolConfig codable round-trip")
struct MultitoolConfigCodableTests {

    private let sampleJSON: String = """
    {
      "blockfrost_project_id": "preview-abc",
      "mode": "lite",
      "token_meta_server": {
        "mainnet": "https://tokens.cardano.org/metadata/"
      },
      "ada_handle_policy": {
        "mainnet": "f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a"
      },
      "max_retry_attempts": 7,
      "base_retry_delay": 250
    }
    """

    @Test("decodes a minimal JSON sample and preserves scalar fields")
    func decodesMinimalJSON() throws {
        let data = Data(sampleJSON.utf8)
        let cfg = try JSONDecoder().decode(MultitoolConfig.self, from: data)
        #expect(cfg.blockfrostProjectId == "preview-abc")
        #expect(cfg.mode == .lite)
        #expect(cfg.maxRetryAttempts == 7)
        #expect(cfg.baseRetryDelay == 250)
        #expect(cfg.tokenMetaServer.mainnet.absoluteString == "https://tokens.cardano.org/metadata/")
    }

    @Test("defaults missing mode to .auto")
    func defaultsMode() throws {
        let json = """
        {
          "token_meta_server": { "mainnet": "https://tokens.cardano.org/metadata/" },
          "ada_handle_policy": { "mainnet": "f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a" }
        }
        """
        let cfg = try JSONDecoder().decode(MultitoolConfig.self, from: Data(json.utf8))
        #expect(cfg.mode == .auto)
    }

    @Test("round-trips through encodeAsJson + decode")
    func jsonRoundTrip() throws {
        let original = try JSONDecoder().decode(MultitoolConfig.self, from: Data(sampleJSON.utf8))
        let reencoded = try original.encodeAsJson()
        let decoded = try JSONDecoder().decode(MultitoolConfig.self, from: reencoded)
        #expect(decoded.mode == original.mode)
        #expect(decoded.blockfrostProjectId == original.blockfrostProjectId)
        #expect(decoded.maxRetryAttempts == original.maxRetryAttempts)
        #expect(decoded.baseRetryDelay == original.baseRetryDelay)
    }

    @Test("encodeAsToml produces non-empty data that mentions a known key")
    func tomlEncodingNonEmpty() throws {
        let cfg = try JSONDecoder().decode(MultitoolConfig.self, from: Data(sampleJSON.utf8))
        let data = try cfg.encodeAsToml()
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(!text.isEmpty)
        #expect(text.contains("blockfrost_project_id"))
    }

    @Test("encodeAsYaml produces non-empty data that mentions a known key")
    func yamlEncodingNonEmpty() throws {
        let cfg = try JSONDecoder().decode(MultitoolConfig.self, from: Data(sampleJSON.utf8))
        let data = try cfg.encodeAsYaml()
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(!text.isEmpty)
        #expect(text.contains("blockfrost_project_id"))
    }
}

@Suite("MultitoolConfig.byronToShelleyEpoch")
struct MultitoolConfigByronToShelleyEpochTests {

    private let baseJSON: String = """
    {
      "token_meta_server": { "mainnet": "https://tokens.cardano.org/metadata/" },
      "ada_handle_policy": { "mainnet": "f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a" }
    }
    """

    @Test("falls back to the stored override when cardano is nil")
    func nilCardanoUsesOverride() throws {
        // No explicit byron_to_shelley_epoch in JSON → stored override is nil → returns 0.
        let cfg = try JSONDecoder().decode(MultitoolConfig.self, from: Data(baseJSON.utf8))
        #expect(cfg.cardano == nil)
        let epoch = try cfg.byronToShelleyEpoch
        #expect(epoch == 0)
    }

    @Test("honours an explicit byron_to_shelley_epoch override when cardano is nil")
    func explicitOverride() throws {
        let json = """
        {
          "token_meta_server": { "mainnet": "https://tokens.cardano.org/metadata/" },
          "ada_handle_policy": { "mainnet": "f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a" },
          "byron_to_shelley_epoch": 999
        }
        """
        let cfg = try JSONDecoder().decode(MultitoolConfig.self, from: Data(json.utf8))
        let epoch = try cfg.byronToShelleyEpoch
        #expect(epoch == 999)
    }
}

// MARK: - NetworkDependable.forNetwork mapping

@Suite("NetworkDependable.forNetwork")
struct NetworkDependableForNetworkTests {

    @Test("NetworkURLs returns the matching url for each network")
    func networkURLsMapping() throws {
        let main = URL(string: "https://main.example.com")!
        let pre = URL(string: "https://preprod.example.com")!
        let urls = NetworkURLs(mainnet: main, preprod: pre, preview: nil, guildnet: nil)
        #expect(urls.forNetwork(.mainnet) == main)
        #expect(urls.forNetwork(.preprod) == pre)
        #expect(urls.forNetwork(.preview) == nil)
        #expect(urls.forNetwork(.guildnet) == nil)
    }

    @Test("TokenMetaServerURLs uses the documented IOG defaults")
    func tokenMetaServerDefaults() {
        let urls = TokenMetaServerURLs()
        #expect(urls.mainnet.absoluteString == "https://tokens.cardano.org/metadata/")
        #expect(urls.preprod?.absoluteString == "https://metadata.cardano-testnet.iohkdev.io/metadata/")
        #expect(urls.preview?.absoluteString == "https://metadata.cardano-testnet.iohkdev.io/metadata/")
        #expect(urls.guildnet == nil)
    }

    @Test("AdaHandlePolicyIds defaults to the production policyId for every named network")
    func adaHandlePolicyDefaults() {
        let ids = AdaHandlePolicyIds()
        let prodPolicy = "f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a"
        #expect(ids.mainnet == prodPolicy)
        #expect(ids.preprod == prodPolicy)
        #expect(ids.preview == prodPolicy)
        #expect(ids.guildnet == nil)
    }

    @Test("AdaHandlePolicyIds.forNetwork maps each network to the matching policyId")
    func adaHandleMapping() {
        let ids = AdaHandlePolicyIds()
        let prodPolicy = "f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a"
        #expect(ids.forNetwork(.mainnet) == prodPolicy)
        #expect(ids.forNetwork(.preprod) == prodPolicy)
        #expect(ids.forNetwork(.preview) == prodPolicy)
        #expect(ids.forNetwork(.guildnet) == nil)
    }
}

// MARK: - MultitoolConfig.init(config:) via ConfigReader

@Suite("MultitoolConfig.init(config:) ConfigReader path")
struct MultitoolConfigInitFromConfigTests {

    @Test("empty provider produces a config with mode defaulting to .auto")
    func emptyProviderDefaultsMode() {
        let provider = InMemoryProvider(name: "test", values: [:])
        let reader = ConfigReader(provider: provider)
        let cfg = MultitoolConfig(config: reader)
        #expect(cfg.mode == .auto)
        #expect(cfg.blockfrostProjectId == nil)
        #expect(cfg.koiosApiKey == nil)
    }

    @Test("explicit mode is read from the provider")
    func modeReadFromProvider() {
        let provider = InMemoryProvider(
            name: "test",
            values: ["mode": "online"]
        )
        let reader = ConfigReader(provider: provider)
        let cfg = MultitoolConfig(config: reader)
        #expect(cfg.mode == Mode.online)
    }

    @Test("blockfrost_project_id and koios_api_key are picked up")
    func projectIdAndApiKey() {
        let provider = InMemoryProvider(
            name: "test",
            values: [
                "blockfrost_project_id": "bf-test-123",
                "koios_api_key": "koios-test-key"
            ]
        )
        let reader = ConfigReader(provider: provider)
        let cfg = MultitoolConfig(config: reader)
        #expect(cfg.blockfrostProjectId == "bf-test-123")
        #expect(cfg.koiosApiKey == "koios-test-key")
    }

    @Test("token_meta_server.mainnet overrides the default mainnet URL")
    func tokenMetaServerOverride() {
        let provider = InMemoryProvider(
            name: "test",
            values: ["token_meta_server.mainnet": "https://custom.tokens.example.com/metadata/"]
        )
        let reader = ConfigReader(provider: provider)
        let cfg = MultitoolConfig(config: reader)
        #expect(cfg.tokenMetaServer.mainnet.absoluteString == "https://custom.tokens.example.com/metadata/")
    }
}
