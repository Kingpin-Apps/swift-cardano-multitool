import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("GenerateMainCommand.VoteKey")
struct VoteKeyTests {

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
