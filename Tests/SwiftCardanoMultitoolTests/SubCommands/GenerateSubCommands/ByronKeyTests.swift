import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("GenerateMainCommand.ByronKey")
struct ByronKeyTests {

    @Test("commandName is 'byron-key'")
    func commandName() {
        #expect(GenerateMainCommand.ByronKey.configuration.commandName == "byron-key")
    }

    @Test("abstract mentions Byron-era mnemonic")
    func abstract() {
        let abstract = GenerateMainCommand.ByronKey.configuration.abstract
        #expect(abstract.contains("Byron"))
        #expect(abstract.contains("mnemonic"))
    }

    @Test("default parse leaves name and mnemonics nil")
    func defaults() throws {
        let cmd = try GenerateMainCommand.ByronKey.parse([])
        #expect(cmd.name == nil)
        #expect(cmd.mnemonics == nil)
    }

    @Test("parses --name and --mnemonics options")
    func parsesNameAndMnemonics() throws {
        let cmd = try GenerateMainCommand.ByronKey.parse([
            "--name", "mybyron",
            "--mnemonics", "abandon abandon abandon"
        ])
        #expect(cmd.name == "mybyron")
        #expect(cmd.mnemonics == "abandon abandon abandon")
    }

    @Test("accepts short -n alias for --name")
    func parsesShortName() throws {
        let cmd = try GenerateMainCommand.ByronKey.parse(["-n", "test"])
        #expect(cmd.name == "test")
    }
}
