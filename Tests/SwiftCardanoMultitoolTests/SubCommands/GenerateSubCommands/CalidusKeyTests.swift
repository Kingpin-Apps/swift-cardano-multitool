import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("GenerateMainCommand.CalidusKey")
struct CalidusKeyTests {

    @Test("commandName is 'calidus-key'")
    func commandName() {
        #expect(GenerateMainCommand.CalidusKey.configuration.commandName == "calidus-key")
    }

    @Test("abstract mentions CIP-151 Calidus")
    func abstract() {
        let abstract = GenerateMainCommand.CalidusKey.configuration.abstract
        #expect(abstract.contains("CIP-151"))
        #expect(abstract.contains("Calidus"))
    }

    @Test("defaults: account is 0, passphrase empty, no mnemonic")
    func defaults() throws {
        let cmd = try GenerateMainCommand.CalidusKey.parse([])
        #expect(cmd.name == nil)
        #expect(cmd.account == 0)
        #expect(cmd.passphrase == "")
        #expect(cmd.mnemonics == nil)
    }

    @Test("parses --account override")
    func parsesAccount() throws {
        let cmd = try GenerateMainCommand.CalidusKey.parse([
            "--name", "p", "--account", "7"
        ])
        #expect(cmd.account == 7)
    }

    @Test("parses --passphrase value")
    func parsesPassphrase() throws {
        let cmd = try GenerateMainCommand.CalidusKey.parse([
            "--name", "p", "--passphrase", "secret"
        ])
        #expect(cmd.passphrase == "secret")
    }
}
