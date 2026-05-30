import ArgumentParser
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
