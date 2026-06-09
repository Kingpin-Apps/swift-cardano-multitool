import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("QueryMainCommand.GovernanceAction")
struct QueryGovernanceActionTests {

    @Test("rejects an unparseable govActionID positional")
    func rejectsGarbage() {
        #expect(throws: (any Error).self) {
            _ = try QueryMainCommand.GovernanceAction.parse(["not_a_valid_id"])
        }
    }
}
