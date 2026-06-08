import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("QueryMainCommand.PoolCalidusKey")
struct PoolCalidusKeyTests {

    @Test("commandName is 'calidus-key'")
    func commandName() {
        #expect(QueryMainCommand.PoolCalidusKey.configuration.commandName == "calidus-key")
    }

    @Test("parses with no arguments (wizard would run)")
    func parsesEmpty() throws {
        let cmd = try QueryMainCommand.PoolCalidusKey.parse([])
        #expect(cmd.filter == nil)
    }

    @Test("parses positional filter")
    func parsesFilter() throws {
        let cmd = try QueryMainCommand.PoolCalidusKey.parse(["all"])
        #expect(cmd.filter == "all")
    }

    @Test("parses bech32 pool ID as filter")
    func parsesBech32Pool() throws {
        let cmd = try QueryMainCommand.PoolCalidusKey.parse(["pool1abc"])
        #expect(cmd.filter == "pool1abc")
    }
}
