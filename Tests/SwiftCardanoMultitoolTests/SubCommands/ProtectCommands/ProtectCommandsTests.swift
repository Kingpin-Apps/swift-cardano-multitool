import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("ProtectMainCommand")
struct ProtectCommandsTests {

    @Test("Encrypt parses --file-name")
    func encryptParsesFileName() throws {
        let cmd = try ProtectMainCommand.Encrypt.parse(["--file-name", "/tmp/key.skey"])
        #expect(cmd.fileName?.string == "/tmp/key.skey")
    }

    @Test("Decrypt parses --file-name")
    func decryptParsesFileName() throws {
        let cmd = try ProtectMainCommand.Decrypt.parse(["--file-name", "/tmp/key.skey"])
        #expect(cmd.fileName?.string == "/tmp/key.skey")
    }
}
