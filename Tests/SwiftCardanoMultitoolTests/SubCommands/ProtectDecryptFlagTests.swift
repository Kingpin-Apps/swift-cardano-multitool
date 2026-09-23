import Testing
import Foundation
import ArgumentParser
import SystemPackage
@testable import SwiftCardanoMultitool

@Suite("protect decrypt --yes flag")
struct ProtectDecryptFlagTests {

    @Test("defaults to prompting for confirmation")
    func defaultsToNo() throws {
        let command = try ProtectMainCommand.Decrypt.parse(["--file-name", "key.skey"])
        #expect(command.yes == false)
    }

    @Test("--yes is accepted")
    func longFormAccepted() throws {
        let command = try ProtectMainCommand.Decrypt.parse(["--file-name", "key.skey", "--yes"])
        #expect(command.yes == true)
    }

    @Test("-y is accepted")
    func shortFormAccepted() throws {
        let command = try ProtectMainCommand.Decrypt.parse(["-f", "key.skey", "-y"])
        #expect(command.yes == true)
        #expect(command.fileName == FilePath("key.skey"))
    }

    @Test("the flag is independent of the file name")
    func flagWithoutFileName() throws {
        let command = try ProtectMainCommand.Decrypt.parse(["--yes"])
        #expect(command.yes == true)
        #expect(command.fileName == nil)
    }

    @Test("the help text mentions the environment variable")
    func helpMentionsEnvironmentVariable() {
        let help = ProtectMainCommand.Decrypt.helpMessage()
        #expect(help.contains("--yes"))
        #expect(help.contains(Environment.decryptPassword.rawValue))
    }
}
