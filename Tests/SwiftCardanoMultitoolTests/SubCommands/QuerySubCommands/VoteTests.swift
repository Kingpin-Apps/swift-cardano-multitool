import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("QueryMainCommand.Vote")
struct QueryVoteTests {

    @Test("commandName is 'vote'")
    func commandName() {
        #expect(QueryMainCommand.Vote.configuration.commandName == "vote")
    }

    @Test("aliases include 'votes'")
    func aliases() {
        #expect(QueryMainCommand.Vote.configuration.aliases.contains("votes"))
    }

    @Test("defaults: nothing set, showAll false")
    func defaults() throws {
        let cmd = try QueryMainCommand.Vote.parse([])
        #expect(cmd.voterRaw == nil)
        #expect(cmd.govActionID == nil)
        #expect(cmd.actionType == nil)
        #expect(cmd.showAll == false)
    }

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
