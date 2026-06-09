import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("QueryMainCommand.Epoch")
struct QueryEpochTests {

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
