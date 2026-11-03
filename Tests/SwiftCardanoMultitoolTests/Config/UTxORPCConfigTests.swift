import Configuration
import Foundation
import Testing
import UTxORPCClient

@testable import SwiftCardanoMultitool

@Suite("UTxORPCConfig")
struct UTxORPCConfigTests {

    static let json = """
        {
          "utxorpc": {
            "url": "https://cardano-preview.utxorpc-m1.demeter.run",
            "api_key": "test-key",
            "api_version": "v1alpha"
          },
          "token_meta_server": { "mainnet": "https://tokens.cardano.org/metadata/" },
          "ada_handle_policy": { "mainnet": "f0ff48bbb7bbe9d59a40f1ce90e9e9d0ff5002ec48f232b49ca0fb9a" }
        }
        """

    @Test("decodes the [utxorpc] block and round-trips it")
    func decodesAndRoundTrips() throws {
        let cfg = try JSONDecoder().decode(MultitoolConfig.self, from: Data(Self.json.utf8))
        #expect(cfg.utxorpc == UTxORPCConfig(
            url: "https://cardano-preview.utxorpc-m1.demeter.run",
            apiKey: "test-key",
            apiVersion: "v1alpha"
        ))
        let decoded = try JSONDecoder().decode(MultitoolConfig.self, from: cfg.encodeAsJson())
        #expect(decoded.utxorpc == cfg.utxorpc)
    }

    @Test("the ConfigReader path reads the block, and leaves it out without a url")
    func readsThroughConfigReader() {
        let reader = ConfigReader(
            provider: InMemoryProvider(
                name: "test",
                values: [
                    "utxorpc.url": "unix:///tmp/rpc.sock",
                    "utxorpc.api_key": "",
                ]
            )
        )
        #expect(MultitoolConfig(config: reader).utxorpc == UTxORPCConfig(url: "unix:///tmp/rpc.sock"))

        let empty = ConfigReader(provider: InMemoryProvider(name: "test", values: ["utxorpc.url": ""]))
        #expect(MultitoolConfig(config: empty).utxorpc == nil)
    }

    @Test("default configs carry no [utxorpc] block, so nothing changes until one is added")
    func defaultsLeaveItOut() throws {
        #expect(try MultitoolConfig.default().utxorpc == nil)
    }

    @Test("the API key travels in Demeter's header unless another is named")
    func apiKeyHeader() throws {
        let demeter = try UTxORPCConfig(url: "https://example.org", apiKey: "k").endpoint()
        #expect(demeter.headers == ["dmtr-api-key": "k"])
        #expect(demeter.useTLS)

        let custom = try UTxORPCConfig(url: "https://example.org", apiKey: "k", apiKeyHeader: "x-api-key").endpoint()
        #expect(custom.headers == ["x-api-key": "k"])

        #expect(try UTxORPCConfig(url: "unix:///tmp/rpc.sock").endpoint().headers.isEmpty)
    }

    @Test("api_version picks the API, v1beta by default")
    func apiVersion() throws {
        #expect(try UTxORPCConfig(url: "http://127.0.0.1:9090").endpoint().apiVersion == .v1beta)
        #expect(try UTxORPCConfig(url: "http://127.0.0.1:9090", apiVersion: "v1alpha").endpoint().apiVersion == .v1alpha)
        #expect(throws: SwiftCardanoMultitoolError.self) {
            _ = try UTxORPCConfig(url: "http://127.0.0.1:9090", apiVersion: "v2").endpoint()
        }
    }
}
