import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("ProtectMainCommand.Encrypt")
struct ProtectEncryptTests {

    @Test("configuration abstract is set")
    func configurationAbstract() {
        #expect(ProtectMainCommand.Encrypt.configuration.abstract == "Encrypt your SKEY-Files with a password.")
    }

    @Test("defaults fileName to nil")
    func defaults() throws {
        let cmd = try ProtectMainCommand.Encrypt.parse([])
        #expect(cmd.fileName == nil)
    }

    @Test("parses --file-name")
    func parsesFileName() throws {
        let cmd = try ProtectMainCommand.Encrypt.parse(["--file-name", "/tmp/key.skey"])
        #expect(cmd.fileName?.string == "/tmp/key.skey")
    }
}

@Suite("ProtectMainCommand.Decrypt")
struct ProtectDecryptTests {

    @Test("configuration abstract is set")
    func configurationAbstract() {
        // Abstract may vary; just confirm it's non-empty.
        #expect(!(ProtectMainCommand.Decrypt.configuration.abstract.isEmpty))
    }

    @Test("defaults fileName to nil")
    func defaults() throws {
        let cmd = try ProtectMainCommand.Decrypt.parse([])
        #expect(cmd.fileName == nil)
    }

    @Test("parses --file-name")
    func parsesFileName() throws {
        let cmd = try ProtectMainCommand.Decrypt.parse(["--file-name", "/tmp/key.skey"])
        #expect(cmd.fileName?.string == "/tmp/key.skey")
    }
}
