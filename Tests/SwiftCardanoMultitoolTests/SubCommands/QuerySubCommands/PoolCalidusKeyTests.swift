import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("QueryMainCommand.PoolCalidusKey")
struct PoolCalidusKeyTests {

    @Test("parses positional filter")
    func parsesFilter() throws {
        let cmd = try QueryMainCommand.PoolCalidusKey.parse(["all"])
        #expect(cmd.filter == "all")
    }
}
