import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("RunMainCommand parsing behavior")
struct RunCommandsTests {

    @Test("Node: parses --use-default-entrypoint")
    func nodeParsesUseDefaultEntrypoint() throws {
        let cmd = try RunMainCommand.Node.parse(["--use-default-entrypoint=true"])
        #expect(cmd.useDefaultEntrypoint == true)
    }
}
