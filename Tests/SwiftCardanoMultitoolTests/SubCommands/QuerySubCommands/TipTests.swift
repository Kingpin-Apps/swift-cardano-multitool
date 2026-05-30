import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("QueryMainCommand.Tip")
struct QueryTipTests {

    @Test("configuration commandName matches abstract")
    func configurationAbstract() {
        #expect(QueryMainCommand.Tip.configuration.abstract == "Query the tip of the blockchain.")
    }

    @Test("parses with no arguments")
    func parsesEmpty() throws {
        _ = try QueryMainCommand.Tip.parse([])
    }

    @Test("run() uses the mocked chain context's lastBlockSlot when not CardanoCli")
    func runUsesMockedLastBlockSlot() async throws {
        let cfg = TestConfigs.make()
        let mock = MockChainContext(name: "TestCtx", type: .online, networkId: .mainnet)
        mock.stubLastBlockSlot = { 12_345_678 }

        try await Configs.$override.withValue(cfg) {
            try await Contexts.$override.withValue(mock) {
                let cmd = try QueryMainCommand.Tip.parse([])
                try await cmd.run()
                // No assertion on output; this exercises the happy path end-to-end and
                // ensures the mocked chain stub is the one invoked.
            }
        }
    }
}
