import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("VerifyMainCommand.VerifyDefault")
struct VerifyDefaultTests {

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

@Suite("VerifyMainCommand.VerifyCIP100")
struct VerifyCIP100Tests {

    @Test("parses --data-file")
    func parsesDataFile() throws {
        let cmd = try VerifyMainCommand.VerifyCIP100.parse(["--data-file", "/tmp/x.jsonld"])
        #expect(cmd.dataFile?.string == "/tmp/x.jsonld")
    }
}
