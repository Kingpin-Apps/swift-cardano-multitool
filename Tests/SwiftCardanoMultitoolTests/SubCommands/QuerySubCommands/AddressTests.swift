import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("QueryMainCommand.Address")
struct QueryAddressTests {

    @Test("rejects garbage that doesn't resolve to an address")
    func rejectsGarbageAddress() {
        #expect(throws: (any Error).self) {
            _ = try QueryMainCommand.Address.parse(["not_a_real_address_xyz"])
        }
    }
}
