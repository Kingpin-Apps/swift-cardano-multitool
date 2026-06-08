import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("GenerateMainCommand.VoteKey")
struct VoteKeyTests {

    @Test("commandName is 'vote-key'")
    func commandName() {
        #expect(GenerateMainCommand.VoteKey.configuration.commandName == "vote-key")
    }

    @Test("abstract mentions CIP-36 Catalyst")
    func abstract() {
        let abstract = GenerateMainCommand.VoteKey.configuration.abstract
        #expect(abstract.contains("CIP-36"))
        #expect(abstract.contains("Catalyst"))
    }

    @Test("defaults: account/address 0, no mnemonic, empty passphrase")
    func defaults() throws {
        let cmd = try GenerateMainCommand.VoteKey.parse([])
        #expect(cmd.name == nil)
        #expect(cmd.account == 0)
        #expect(cmd.address == 0)
        #expect(cmd.passphrase == "")
        #expect(cmd.mnemonics == nil)
    }

    @Test("parses --account and --address overrides")
    func parsesAccountAndAddress() throws {
        let cmd = try GenerateMainCommand.VoteKey.parse([
            "--name", "myvote",
            "--account", "3",
            "--address", "5"
        ])
        #expect(cmd.account == 3)
        #expect(cmd.address == 5)
    }
}
