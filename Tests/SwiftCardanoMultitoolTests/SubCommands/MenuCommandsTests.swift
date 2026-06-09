import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("ExitCommand")
struct ExitCommandTests {

    @Test("run() throws ExitCode")
    func runThrowsSuccess() async throws {
        var cmd = try ExitCommand.parse([])
        await #expect(throws: ExitCode.self) {
            try await cmd.run()
        }
    }
}
