import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("SignMainCommand.SignDefault")
struct SignDefaultTests {

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

    @Test("parses --testnet and --attach-cose-key")
    func parsesFlags() throws {
        let cmd = try SignMainCommand.SignCIP8.parse([
            "--data", "x", "--secret-key", "k", "--testnet", "--attach-cose-key"
        ])
        #expect(cmd.testnet == true)
        #expect(cmd.attachCoseKey == true)
    }
}

@Suite("SignMainCommand.SignCIP36")
struct SignCIP36Tests {

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

    @Test("parses --author-name")
    func parsesAuthorName() throws {
        let cmd = try SignMainCommand.SignCIP100.parse(["--author-name", "Alice"])
        #expect(cmd.authorName == "Alice")
    }
}
