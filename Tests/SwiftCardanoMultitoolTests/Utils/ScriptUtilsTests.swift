import ArgumentParser
import Logging
import SwiftCardanoUtils
import Testing
@testable import SwiftCardanoMultitool

@Suite("getCardanoConfig")
struct ScriptUtilsGetCardanoConfigTests {

    @Test("throws ExitCode.failure when cardano section is missing")
    func throwsWhenCardanoMissing() {
        let cfg = MultitoolConfig(
            cardano: nil,
            tokenMetaServer: TokenMetaServerURLs(),
            adaHandlePolicy: AdaHandlePolicyIds()
        )
        #expect(throws: ExitCode.self) {
            _ = try getCardanoConfig(config: cfg)
        }
    }
}

@Suite("healthyKupoURL")
struct ScriptUtilsHealthyKupoURLTests {

    let logger = Logger(label: "test")

    @Test("returns nil without a [kupo] block")
    func nilWithoutConfig() async {
        #expect(await healthyKupoURL(config: nil, logger: logger) == nil)
    }

    @Test("returns nil when [kupo] has no port")
    func nilWithoutPort() async {
        #expect(await healthyKupoURL(config: KupoConfig(host: "localhost"), logger: logger) == nil)
    }

    @Test("returns nil when nothing answers on the port")
    func nilWhenUnreachable() async {
        // Port 9 (discard) is closed on a normal machine, so the connection is refused at once.
        let config = KupoConfig(host: "127.0.0.1", port: 9)
        #expect(await healthyKupoURL(config: config, logger: logger) == nil)
    }
}
