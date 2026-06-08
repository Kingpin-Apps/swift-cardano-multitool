import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("SignMainCommand")
struct SignMainCommandTests {

    @Test("commandName is 'sign'")
    func commandName() {
        #expect(SignMainCommand.configuration.commandName == "sign")
    }

    @Test("abstract is set")
    func abstract() {
        #expect(!SignMainCommand.configuration.abstract.isEmpty)
    }

    @Test("subcommands include all CIP variants and default")
    func subcommandsRegistered() {
        let names = SignMainCommand.configuration.subcommands.map { $0.configuration.commandName }
        #expect(names.contains("default"))
        #expect(names.contains("cip8"))
        #expect(names.contains("cip30"))
        #expect(names.contains("cip36"))
        #expect(names.contains("cip88"))
        #expect(names.contains("cip100"))
    }

    @Test("SignCommands.name reads as the documented label")
    func signCommandsLabels() {
        #expect(SignCommands.default.name == "Default Ed25519")
        #expect(SignCommands.cip8.name == "CIP-8 (COSE_Sign1)")
        #expect(SignCommands.cip30.name == "CIP-30 (Wallet signData)")
        #expect(SignCommands.cip36.name == "CIP-36 (Catalyst voting)")
        #expect(SignCommands.cip88.name == "CIP-88 (Calidus pool registration)")
        #expect(SignCommands.cip100.name == "CIP-100 (Governance metadata)")
        #expect(SignCommands.back.name == "Back")
        #expect(SignCommands.exit.name == "Exit")
    }

    @Test("SignCommands.details non-empty for every case")
    func signCommandsDetails() {
        for c in SignCommands.allCases {
            #expect(!c.details.isEmpty)
        }
    }

    @Test("SignCommands.command resolves each case to its type")
    func signCommandsResolves() {
        #expect(SignCommands.default.command().configuration.commandName
            == SignMainCommand.SignDefault.configuration.commandName)
        #expect(SignCommands.cip8.command().configuration.commandName
            == SignMainCommand.SignCIP8.configuration.commandName)
        #expect(SignCommands.cip30.command().configuration.commandName
            == SignMainCommand.SignCIP30.configuration.commandName)
        #expect(SignCommands.cip36.command().configuration.commandName
            == SignMainCommand.SignCIP36.configuration.commandName)
        #expect(SignCommands.cip88.command().configuration.commandName
            == SignMainCommand.SignCIP88.configuration.commandName)
        #expect(SignCommands.cip100.command().configuration.commandName
            == SignMainCommand.SignCIP100.configuration.commandName)
        #expect(SignCommands.back.command().configuration.commandName
            == MainMenuCommand.configuration.commandName)
        #expect(SignCommands.exit.command().configuration.commandName
            == ExitCommand.configuration.commandName)
    }
}

@Suite("SignMainCommand.SignDefault")
struct SignDefaultTests {
    @Test("commandName is 'default'")
    func commandName() {
        #expect(SignMainCommand.SignDefault.configuration.commandName == "default")
    }

    @Test("defaults: nothing set, flags off")
    func defaults() throws {
        let cmd = try SignMainCommand.SignDefault.parse([])
        #expect(cmd.data == nil)
        #expect(cmd.dataHex == nil)
        #expect(cmd.dataFile == nil)
        #expect(cmd.secretKey == nil)
        #expect(cmd.calidus == false)
        #expect(cmd.output.json == false)
        #expect(cmd.output.jsonExtended == false)
        #expect(cmd.output.includeSecret == false)
        #expect(cmd.output.outFile == nil)
    }

    @Test("parses --data and --secret-key")
    func parsesDataAndKey() throws {
        let cmd = try SignMainCommand.SignDefault.parse([
            "--data", "hello", "--secret-key", "key.skey"
        ])
        #expect(cmd.data == "hello")
        #expect(cmd.secretKey == "key.skey")
    }

    @Test("parses --calidus flag")
    func parsesCalidusFlag() throws {
        let cmd = try SignMainCommand.SignDefault.parse([
            "--data", "x", "--secret-key", "k", "--calidus"
        ])
        #expect(cmd.calidus == true)
    }

    @Test("parses --out-file with -o short alias")
    func parsesOutFile() throws {
        let cmd = try SignMainCommand.SignDefault.parse([
            "--data", "x", "--secret-key", "k", "-o", "/tmp/sig.txt"
        ])
        #expect(cmd.output.outFile?.string == "/tmp/sig.txt")
    }
}

@Suite("SignMainCommand.SignCIP8")
struct SignCIP8Tests {
    @Test("commandName is 'cip8'")
    func commandName() {
        #expect(SignMainCommand.SignCIP8.configuration.commandName == "cip8")
    }

    @Test("defaults: testnet false, attachCoseKey false")
    func defaults() throws {
        let cmd = try SignMainCommand.SignCIP8.parse([])
        #expect(cmd.testnet == false)
        #expect(cmd.attachCoseKey == false)
    }

    @Test("parses --testnet and --attach-cose-key")
    func parsesFlags() throws {
        let cmd = try SignMainCommand.SignCIP8.parse([
            "--data", "x", "--secret-key", "k", "--testnet", "--attach-cose-key"
        ])
        #expect(cmd.testnet == true)
        #expect(cmd.attachCoseKey == true)
    }
}

@Suite("SignMainCommand.SignCIP30")
struct SignCIP30Tests {
    @Test("commandName is 'cip30'")
    func commandName() {
        #expect(SignMainCommand.SignCIP30.configuration.commandName == "cip30")
    }

    @Test("defaults: testnet false")
    func defaults() throws {
        let cmd = try SignMainCommand.SignCIP30.parse([])
        #expect(cmd.testnet == false)
    }
}

@Suite("SignMainCommand.SignCIP36")
struct SignCIP36Tests {
    @Test("commandName is 'cip36'")
    func commandName() {
        #expect(SignMainCommand.SignCIP36.configuration.commandName == "cip36")
    }

    @Test("defaults: deregister false, vote weights empty, vote purpose 0")
    func defaults() throws {
        let cmd = try SignMainCommand.SignCIP36.parse([])
        #expect(cmd.deregister == false)
        #expect(cmd.voteWeights.isEmpty)
        #expect(cmd.votePublicKeys.isEmpty)
        #expect(cmd.votePurpose == 0)
        #expect(cmd.nonce == nil)
    }

    @Test("parses --deregister and --vote-purpose")
    func parsesFlags() throws {
        let cmd = try SignMainCommand.SignCIP36.parse([
            "--deregister", "--vote-purpose", "5"
        ])
        #expect(cmd.deregister == true)
        #expect(cmd.votePurpose == 5)
    }

    @Test("parses repeated --vote-public-key options")
    func parsesRepeatedVoteKeys() throws {
        let cmd = try SignMainCommand.SignCIP36.parse([
            "--vote-public-key", "k1",
            "--vote-public-key", "k2"
        ])
        #expect(cmd.votePublicKeys == ["k1", "k2"])
    }
}

@Suite("SignMainCommand.SignCIP88")
struct SignCIP88Tests {
    @Test("commandName is 'cip88'")
    func commandName() {
        #expect(SignMainCommand.SignCIP88.configuration.commandName == "cip88")
    }

    @Test("defaults: metaJson false, no nonce override")
    func defaults() throws {
        let cmd = try SignMainCommand.SignCIP88.parse([])
        #expect(cmd.metaJson == false)
        #expect(cmd.nonce == nil)
    }

    @Test("parses --meta-json flag")
    func parsesMetaJson() throws {
        let cmd = try SignMainCommand.SignCIP88.parse(["--meta-json"])
        #expect(cmd.metaJson == true)
    }

    @Test("parses --nonce override")
    func parsesNonce() throws {
        let cmd = try SignMainCommand.SignCIP88.parse(["--nonce", "12345"])
        #expect(cmd.nonce == 12345)
    }
}

@Suite("SignMainCommand.SignCIP100")
struct SignCIP100Tests {
    @Test("commandName is 'cip100'")
    func commandName() {
        #expect(SignMainCommand.SignCIP100.configuration.commandName == "cip100")
    }

    @Test("defaults: nothing set")
    func defaults() throws {
        let cmd = try SignMainCommand.SignCIP100.parse([])
        #expect(cmd.data == nil)
        #expect(cmd.dataFile == nil)
        #expect(cmd.secretKey == nil)
        #expect(cmd.authorName == nil)
    }

    @Test("parses --author-name")
    func parsesAuthorName() throws {
        let cmd = try SignMainCommand.SignCIP100.parse(["--author-name", "Alice"])
        #expect(cmd.authorName == "Alice")
    }
}
