import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("QueryMainCommand.DRep")
struct QueryDRepTests {

    @Test("rejects garbage that doesn't resolve to a DRep")
    func rejectsGarbage() {
        #expect(throws: (any Error).self) {
            _ = try QueryMainCommand.DRep.parse(["totally_invalid_drep_xyz"])
        }
    }
}
