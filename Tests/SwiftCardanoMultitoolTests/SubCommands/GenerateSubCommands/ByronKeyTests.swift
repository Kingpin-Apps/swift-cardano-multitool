import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("GenerateMainCommand.ByronKey")
struct ByronKeyTests {

    @Test("parses --name and --mnemonics options")
    func parsesNameAndMnemonics() throws {
        let cmd = try GenerateMainCommand.ByronKey.parse([
            "--name", "mybyron",
            "--mnemonics", "abandon abandon abandon"
        ])
        #expect(cmd.name == "mybyron")
        #expect(cmd.mnemonics == "abandon abandon abandon")
    }
}
