import Logging
import Testing
@testable import SwiftCardanoMultitool

@Suite("getLogger")
struct LoggingTests {

    private func makeConfig(logLevel: Logger.Level?) -> MultitoolConfig {
        MultitoolConfig(
            tokenMetaServer: TokenMetaServerURLs(),
            adaHandlePolicy: AdaHandlePolicyIds(),
            logLevel: logLevel
        )
    }

    @Test("uses the configured log level")
    func usesConfiguredLevel() {
        let logger = getLogger(config: makeConfig(logLevel: .debug))
        #expect(logger.logLevel == .debug)
    }

    @Test("defaults to .error when the configured log level is nil")
    func defaultsToErrorWhenNil() {
        let logger = getLogger(config: makeConfig(logLevel: nil))
        #expect(logger.logLevel == .error)
    }

    @Test("uses the com.swift-cardano-multitool label")
    func usesExpectedLabel() {
        let logger = getLogger(config: makeConfig(logLevel: .info))
        #expect(logger.label == "com.swift-cardano-multitool")
    }
}
