import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("QueryMainCommand.CommitteeMember")
struct QueryCommitteeMemberTests {

    @Test("commandName is 'committee-member'")
    func commandName() {
        #expect(QueryMainCommand.CommitteeMember.configuration.commandName == "committee-member")
    }

    @Test("aliases include 'committee' and 'cc'")
    func aliases() {
        let aliases = QueryMainCommand.CommitteeMember.configuration.aliases
        #expect(aliases.contains("committee"))
        #expect(aliases.contains("cc"))
    }

    @Test("parses with no arguments (wizard would run)")
    func parsesEmpty() throws {
        let cmd = try QueryMainCommand.CommitteeMember.parse([])
        #expect(cmd.credential == nil)
    }
}
