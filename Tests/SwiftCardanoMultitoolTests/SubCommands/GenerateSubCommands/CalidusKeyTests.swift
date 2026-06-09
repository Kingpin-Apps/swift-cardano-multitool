import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("GenerateMainCommand.CalidusKey")
struct CalidusKeyTests {

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
