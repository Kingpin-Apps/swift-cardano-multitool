import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("QueryMainCommand.Tip")
struct QueryTipTests {

    @Test("run() uses the mocked chain context's lastBlockSlot when not CardanoCli")
    func runUsesMockedLastBlockSlot() async throws {
        let cfg = TestConfigs.make()
        let mock = MockChainContext(name: "TestCtx", type: .online, networkId: .mainnet)
        mock.stubLastBlockSlot = { 12_345_678 }

        try await Configs.$override.withValue(cfg) {
            try await Contexts.$override.withValue(mock) {
                let cmd = try QueryMainCommand.Tip.parse([])
                try await cmd.run()
            }
        }
    }
}
