import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("QueryMainCommand.Epoch")
struct QueryEpochTests {

    @Test("configuration abstract is set")
    func configurationAbstract() {
        #expect(QueryMainCommand.Epoch.configuration.abstract == "Get current epoch.")
    }

    @Test("parses with no arguments")
    func parsesEmpty() throws {
        _ = try QueryMainCommand.Epoch.parse([])
    }

    @Test("run() retrieves the epoch via the mocked chain context")
    func runUsesMockedEpoch() async throws {
        let cfg = TestConfigs.make()
        let mock = MockChainContext()
        mock.stubEpoch = { 500 }

        try await Configs.$override.withValue(cfg) {
            try await Contexts.$override.withValue(mock) {
                let cmd = try QueryMainCommand.Epoch.parse([])
                try await cmd.run()
            }
        }
    }
}
