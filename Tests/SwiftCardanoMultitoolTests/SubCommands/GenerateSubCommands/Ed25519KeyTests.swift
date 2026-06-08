import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("GenerateMainCommand.Ed25519Key")
struct Ed25519KeyTests {

    @Test("commandName is 'ed25519'")
    func commandName() {
        #expect(GenerateMainCommand.Ed25519Key.configuration.commandName == "ed25519")
    }

    @Test("abstract mentions Ed25519 and keypair")
    func abstract() {
        let abstract = GenerateMainCommand.Ed25519Key.configuration.abstract
        #expect(abstract.contains("Ed25519"))
        #expect(abstract.contains("keypair"))
    }

    @Test("default parse leaves name nil")
    func defaults() throws {
        let cmd = try GenerateMainCommand.Ed25519Key.parse([])
        #expect(cmd.name == nil)
    }

    @Test("parses --name")
    func parsesName() throws {
        let cmd = try GenerateMainCommand.Ed25519Key.parse(["--name", "mykey"])
        #expect(cmd.name == "mykey")
    }
}
