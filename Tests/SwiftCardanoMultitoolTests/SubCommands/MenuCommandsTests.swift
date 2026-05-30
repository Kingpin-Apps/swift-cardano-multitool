import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("MainMenuCommand")
struct MainMenuCommandTests {

    @Test("abstract is set")
    func abstractIsSet() {
        #expect(MainMenuCommand.configuration.abstract == "Show the main menu.")
    }

    @Test("parses with no arguments")
    func parsesEmpty() throws {
        _ = try MainMenuCommand.parse([])
    }
}

@Suite("ExitCommand")
struct ExitCommandTests {

    @Test("abstract is set")
    func abstractIsSet() {
        #expect(ExitCommand.configuration.abstract == "Exit.")
    }

    @Test("parses with no arguments")
    func parsesEmpty() throws {
        _ = try ExitCommand.parse([])
    }

    @Test("run() throws ExitCode.success")
    func runThrowsSuccess() async throws {
        var cmd = try ExitCommand.parse([])
        await #expect(throws: ExitCode.self) {
            try await cmd.run()
        }
    }
}
