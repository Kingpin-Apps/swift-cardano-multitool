import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("QueryMainCommand.Address")
struct QueryAddressTests {

    @Test("configuration abstract is set")
    func configurationAbstract() {
        #expect(QueryMainCommand.Address.configuration.abstract == "Query UTxOs for an address.")
    }

    @Test("parses with no arguments (wizard will be invoked at run time)")
    func parsesEmpty() throws {
        let cmd = try QueryMainCommand.Address.parse([])
        #expect(cmd.address == nil)
    }

    @Test("rejects garbage that doesn't resolve to an address")
    func rejectsGarbageAddress() {
        #expect(throws: (any Error).self) {
            _ = try QueryMainCommand.Address.parse(["not_a_real_address_xyz"])
        }
    }
}
