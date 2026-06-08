import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("VerifyMainCommand")
struct VerifyMainCommandTests {

    @Test("commandName is 'verify'")
    func commandName() {
        #expect(VerifyMainCommand.configuration.commandName == "verify")
    }

    @Test("subcommands include default + CIP variants")
    func subcommandsRegistered() {
        let names = VerifyMainCommand.configuration.subcommands.map { $0.configuration.commandName }
        #expect(names.contains("default"))
        #expect(names.contains("cip8"))
        #expect(names.contains("cip30"))
        #expect(names.contains("cip100"))
    }

    @Test("VerifyCommands.name labels match documentation")
    func verifyCommandsLabels() {
        #expect(VerifyCommands.default.name == "Default Ed25519")
        #expect(VerifyCommands.cip8.name == "CIP-8 (COSE_Sign1)")
        #expect(VerifyCommands.cip30.name == "CIP-30 (Wallet signData)")
        #expect(VerifyCommands.cip100.name == "CIP-100 (Governance metadata)")
        #expect(VerifyCommands.back.name == "Back")
        #expect(VerifyCommands.exit.name == "Exit")
    }

    @Test("VerifyCommands.details non-empty for every case")
    func verifyCommandsDetails() {
        for c in VerifyCommands.allCases {
            #expect(!c.details.isEmpty)
        }
    }

    @Test("VerifyCommands.command resolves each case to its type")
    func verifyCommandsResolves() {
        #expect(VerifyCommands.default.command().configuration.commandName
            == VerifyMainCommand.VerifyDefault.configuration.commandName)
        #expect(VerifyCommands.cip8.command().configuration.commandName
            == VerifyMainCommand.VerifyCIP8.configuration.commandName)
        #expect(VerifyCommands.cip30.command().configuration.commandName
            == VerifyMainCommand.VerifyCIP30.configuration.commandName)
        #expect(VerifyCommands.cip100.command().configuration.commandName
            == VerifyMainCommand.VerifyCIP100.configuration.commandName)
        #expect(VerifyCommands.back.command().configuration.commandName
            == MainMenuCommand.configuration.commandName)
        #expect(VerifyCommands.exit.command().configuration.commandName
            == ExitCommand.configuration.commandName)
    }
}

@Suite("VerifyMainCommand.VerifyDefault")
struct VerifyDefaultTests {
    @Test("commandName is 'default'")
    func commandName() {
        #expect(VerifyMainCommand.VerifyDefault.configuration.commandName == "default")
    }

    @Test("defaults: nothing set")
    func defaults() throws {
        let cmd = try VerifyMainCommand.VerifyDefault.parse([])
        #expect(cmd.data == nil)
        #expect(cmd.dataHex == nil)
        #expect(cmd.dataFile == nil)
        #expect(cmd.publicKey == nil)
        #expect(cmd.signature == nil)
    }

    @Test("parses --data, --public-key, --signature")
    func parsesAll() throws {
        let cmd = try VerifyMainCommand.VerifyDefault.parse([
            "--data", "hi",
            "--public-key", "vkey.txt",
            "--signature", "deadbeef"
        ])
        #expect(cmd.data == "hi")
        #expect(cmd.publicKey == "vkey.txt")
        #expect(cmd.signature == "deadbeef")
    }

    @Test("parses short -p for --public-key")
    func parsesShortPublicKey() throws {
        let cmd = try VerifyMainCommand.VerifyDefault.parse(["-p", "k"])
        #expect(cmd.publicKey == "k")
    }
}

@Suite("VerifyMainCommand.VerifyCIP8")
struct VerifyCIP8Tests {
    @Test("commandName is 'cip8'")
    func commandName() {
        #expect(VerifyMainCommand.VerifyCIP8.configuration.commandName == "cip8")
    }

    @Test("defaults are nil")
    func defaults() throws {
        let cmd = try VerifyMainCommand.VerifyCIP8.parse([])
        #expect(cmd.coseSign1 == nil)
        #expect(cmd.coseKey == nil)
    }

    @Test("parses --cose-sign1 and --cose-key")
    func parsesAll() throws {
        let cmd = try VerifyMainCommand.VerifyCIP8.parse([
            "--cose-sign1", "84582a",
            "--cose-key", "a401"
        ])
        #expect(cmd.coseSign1 == "84582a")
        #expect(cmd.coseKey == "a401")
    }
}

@Suite("VerifyMainCommand.VerifyCIP30")
struct VerifyCIP30Tests {
    @Test("commandName is 'cip30'")
    func commandName() {
        #expect(VerifyMainCommand.VerifyCIP30.configuration.commandName == "cip30")
    }

    @Test("defaults are nil")
    func defaults() throws {
        let cmd = try VerifyMainCommand.VerifyCIP30.parse([])
        #expect(cmd.coseSign1 == nil)
        #expect(cmd.coseKey == nil)
    }
}

@Suite("VerifyMainCommand.VerifyCIP100")
struct VerifyCIP100Tests {
    @Test("commandName is 'cip100'")
    func commandName() {
        #expect(VerifyMainCommand.VerifyCIP100.configuration.commandName == "cip100")
    }

    @Test("defaults are nil")
    func defaults() throws {
        let cmd = try VerifyMainCommand.VerifyCIP100.parse([])
        #expect(cmd.data == nil)
        #expect(cmd.dataFile == nil)
    }

    @Test("parses --data-file")
    func parsesDataFile() throws {
        let cmd = try VerifyMainCommand.VerifyCIP100.parse(["--data-file", "/tmp/x.jsonld"])
        #expect(cmd.dataFile?.string == "/tmp/x.jsonld")
    }
}
