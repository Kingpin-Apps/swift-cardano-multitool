import Configuration
import Foundation
import SwiftCardanoChain
import SwiftCardanoCore
import SwiftCardanoUtils
import Testing

@testable import SwiftCardanoMultitool

@Suite("YaciConfig + devkit mode")
struct YaciConfigTests {

    static let devkitJSON = """
        {
          "mode": "devkit",
          "yaci": {
            "api_url": "http://devkit.local:8080",
            "admin_url": "http://devkit.local:10000",
            "network_magic": 7
          },
          "token_meta_server": { "mainnet": "https://tokens.cardano.org/metadata/" },
          "ada_handle_policy": { "mainnet": "f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a" }
        }
        """

    @Test("decodes the devkit mode and the [yaci] block")
    func decodesDevkitConfig() throws {
        let cfg = try JSONDecoder().decode(
            MultitoolConfig.self,
            from: Data(Self.devkitJSON.utf8)
        )
        #expect(cfg.mode == .devkit)
        #expect(cfg.yaci?.apiUrl == "http://devkit.local:8080")
        #expect(cfg.yaci?.adminUrl == "http://devkit.local:10000")
        #expect(cfg.yaci?.networkMagic == 7)
        #expect(cfg.yaci?.network == .custom(7))
    }

    @Test("round-trips the [yaci] block through encodeAsJson + decode")
    func roundTripsYaciBlock() throws {
        let original = try JSONDecoder().decode(
            MultitoolConfig.self,
            from: Data(Self.devkitJSON.utf8)
        )
        let decoded = try JSONDecoder().decode(
            MultitoolConfig.self,
            from: original.encodeAsJson()
        )
        #expect(decoded.mode == .devkit)
        #expect(decoded.yaci == original.yaci)
    }

    @Test("a missing [yaci] block falls back to DevKit's own defaults")
    func defaultsWhenBlockAbsent() throws {
        let json = """
            {
              "mode": "devkit",
              "token_meta_server": { "mainnet": "https://tokens.cardano.org/metadata/" },
              "ada_handle_policy": { "mainnet": "f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a" }
            }
            """
        let cfg = try JSONDecoder().decode(MultitoolConfig.self, from: Data(json.utf8))
        #expect(cfg.mode == .devkit)
        #expect(cfg.yaci == nil)

        let fallback = YaciConfig.default()
        #expect(fallback.apiUrl == "http://localhost:8080")
        #expect(fallback.adminUrl == "http://localhost:10000")
        #expect(fallback.network == .custom(YaciConfig.defaultNetworkMagic))
    }

    @Test("an empty magic still resolves to DevKit's default of 42")
    func networkDefaultsToFortyTwo() {
        #expect(YaciConfig().network == .custom(42))
        #expect(YaciConfig(networkMagic: 1097911063).network == .custom(1097911063))
    }

    @Test("devkit mode builds a YaciDevkitChainContext")
    func devkitModeBuildsYaciContext() async throws {
        let cfg = try JSONDecoder().decode(
            MultitoolConfig.self,
            from: Data(Self.devkitJSON.utf8)
        )
        let context = try await getContext(config: cfg)
        #expect(context is YaciDevkitChainContext)
        #expect(context.name == "YaciDevkit")
        // Every devnet magic other than mainnet's maps to the testnet network id.
        #expect(context.networkId == .testnet)
    }

    @Test("the devkit context honours the configured endpoints")
    func devkitContextUsesConfiguredEndpoints() async throws {
        let cfg = try JSONDecoder().decode(
            MultitoolConfig.self,
            from: Data(Self.devkitJSON.utf8)
        )
        let context = try #require(try await getContext(config: cfg) as? YaciDevkitChainContext)
        #expect(context.api.baseURL.absoluteString.hasPrefix("http://devkit.local:8080"))
    }

    @Test("a mainnet [cardano] block does not override the devnet's own magic")
    func mainnetCardanoBlockDoesNotLeakIntoTheContext() async throws {
        // getContext warns about this combination; what matters here is that the
        // context still points at the devnet rather than at mainnet.
        var cfg = try JSONDecoder().decode(
            MultitoolConfig.self,
            from: Data(Self.devkitJSON.utf8)
        )
        cfg.cardano = CardanoConfig(network: .mainnet, era: .conway, ttlBuffer: 3600)

        let context = try await getContext(config: cfg)
        #expect(context is YaciDevkitChainContext)
        #expect(context.networkId == .testnet)
    }

    @Test("the devkit ConfigNetwork seeds devkit mode and magic 42")
    func configNetworkDevkit() throws {
        #expect(ConfigNetwork.devkit.network == .custom(42))
        #expect(ConfigNetwork.devkit.mode == .devkit)
        #expect(ConfigNetwork.preprod.mode == .auto)

        let cfg = try MultitoolConfig.default(
            network: ConfigNetwork.devkit.network,
            mode: ConfigNetwork.devkit.mode
        )
        #expect(cfg.mode == .devkit)
        #expect(cfg.cardano?.network == .custom(42))
        #expect(cfg.yaci?.networkMagic == 42)
    }

    @Test("the [yaci] block is read through the ConfigReader path")
    func readsYaciBlockFromProvider() {
        let reader = ConfigReader(
            provider: InMemoryProvider(
                name: "test",
                values: [
                    "mode": "devkit",
                    "yaci.api_url": "http://devkit.local:9000",
                    "yaci.admin_url": "http://devkit.local:11000",
                    "yaci.network_magic": 99,
                ]
            )
        )
        let cfg = MultitoolConfig(config: reader)
        #expect(cfg.mode == .devkit)
        #expect(cfg.yaci?.apiUrl == "http://devkit.local:9000")
        #expect(cfg.yaci?.adminUrl == "http://devkit.local:11000")
        #expect(cfg.yaci?.network == .custom(99))
    }

    @Test("a custom cardano.network written as an integer is not read back as mainnet")
    func integerNetworkMagicSurvivesTheConfigReader() {
        // `Network.custom` encodes as its bare magic, so it comes back from
        // TOML/JSON as an integer. Reading it only as a string silently produced
        // mainnet and aimed every address at the wrong network; swift-cardano-utils
        // 0.5.7 fixed that. Kept as an end-to-end guard on the devkit config path,
        // which is the one that actually uses a custom magic.
        let reader = ConfigReader(
            provider: InMemoryProvider(
                name: "test",
                values: ["cardano.network": 42, "cardano.era": "conway"]
            )
        )
        let cfg = MultitoolConfig(config: reader)
        #expect(cfg.cardano?.network == .custom(42))
    }

    @Test("a named cardano.network is still read as that network")
    func namedNetworkStillWins() {
        let reader = ConfigReader(
            provider: InMemoryProvider(
                name: "test",
                values: ["cardano.network": "preprod", "cardano.era": "conway"]
            )
        )
        let cfg = MultitoolConfig(config: reader)
        #expect(cfg.cardano?.network == .preprod)
    }

    @Test("auto mode never selects the devkit backend")
    func autoModeIgnoresDevkit() {
        // A [yaci] block left over from a devnet session must not redirect a
        // mainnet command, so `devkit` is only ever reachable explicitly.
        #expect(Mode.auto != .devkit)
        #expect(Mode(rawValue: "devkit") == .devkit)
        #expect(Mode.allCases.contains(.devkit))
    }
}
