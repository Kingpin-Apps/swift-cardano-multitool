import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("QueryMainCommand.DRep")
struct QueryDRepTests {

    @Test("commandName is 'drep'")
    func commandName() {
        #expect(QueryMainCommand.DRep.configuration.commandName == "drep")
    }

    @Test("parses with no arguments (wizard would run)")
    func parsesEmpty() throws {
        let cmd = try QueryMainCommand.DRep.parse([])
        #expect(cmd.drep == nil)
    }

    @Test("rejects garbage that doesn't resolve to a DRep")
    func rejectsGarbage() {
        #expect(throws: (any Error).self) {
            _ = try QueryMainCommand.DRep.parse(["totally_invalid_drep_xyz"])
        }
    }
}
