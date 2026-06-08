import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("QueryMainCommand.GovernanceAction")
struct QueryGovernanceActionTests {

    @Test("commandName is 'governance-action'")
    func commandName() {
        #expect(QueryMainCommand.GovernanceAction.configuration.commandName == "governance-action")
    }

    @Test("aliases include 'gov-action' and 'ga'")
    func aliases() {
        let aliases = QueryMainCommand.GovernanceAction.configuration.aliases
        #expect(aliases.contains("gov-action"))
        #expect(aliases.contains("ga"))
    }

    @Test("parses with no arguments (wizard would run)")
    func parsesEmpty() throws {
        let cmd = try QueryMainCommand.GovernanceAction.parse([])
        #expect(cmd.govActionID == nil)
    }

    @Test("rejects an unparseable govActionID positional")
    func rejectsGarbage() {
        #expect(throws: (any Error).self) {
            _ = try QueryMainCommand.GovernanceAction.parse(["not_a_valid_id"])
        }
    }
}
