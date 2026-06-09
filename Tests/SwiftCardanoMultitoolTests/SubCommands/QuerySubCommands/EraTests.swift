import ArgumentParser
import SwiftCardanoCore
import Testing
@testable import SwiftCardanoMultitool

@Suite("QueryMainCommand.Era")
struct QueryEraTests {

    @Test("run() succeeds when the mock returns an era")
    func runWithEra() async throws {
        let cfg = TestConfigs.make()
        let mock = MockChainContext()
        mock.stubEra = { SwiftCardanoCore.Era.conway }

        try await Configs.$override.withValue(cfg) {
            try await Contexts.$override.withValue(mock) {
                let cmd = try QueryMainCommand.Era.parse([])
                try await cmd.run()
            }
        }
    }

    @Test("run() throws ExitCode.failure when the era stub returns nil")
    func runThrowsWhenEraNil() async throws {
        let cfg = TestConfigs.make()
        let mock = MockChainContext()
        mock.stubEra = { nil }

        await #expect(throws: ExitCode.self) {
            try await Configs.$override.withValue(cfg) {
                try await Contexts.$override.withValue(mock) {
                    let cmd = try QueryMainCommand.Era.parse([])
                    try await cmd.run()
                }
            }
        }
    }
}
