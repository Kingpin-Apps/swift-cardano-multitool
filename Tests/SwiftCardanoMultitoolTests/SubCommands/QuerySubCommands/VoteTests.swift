import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("QueryMainCommand.Vote")
struct QueryVoteTests {

    @Test("parses --voter, --action-type, --all")
    func parsesAll() throws {
        let cmd = try QueryMainCommand.Vote.parse([
            "--voter", "drep1xyz",
            "--action-type", "info",
            "--all"
        ])
        #expect(cmd.voterRaw == "drep1xyz")
        #expect(cmd.actionType == .infoAction)
        #expect(cmd.showAll == true)
    }

    @Test("rejects an unknown --action-type")
    func rejectsBadActionType() {
        #expect(throws: (any Error).self) {
            _ = try QueryMainCommand.Vote.parse(["--action-type", "made-up"])
        }
    }
}
