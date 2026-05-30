import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("ConfigMainCommand.Show")
struct ConfigShowTests {

    // Show calls `MultitoolConfig.load()` (which depends on CARDANO_MULTITOOL_CONFIG)
    // and prints JSON. Behavior coverage will come once Tier 3 lets us inject a
    // config loader. For now verify the argument-parser configuration.

    @Test("configuration abstract is set")
    func configurationAbstractSet() {
        #expect(ConfigMainCommand.Show.configuration.abstract == "Show current configuration.")
    }

    @Test("parses with no arguments")
    func parsesEmpty() throws {
        _ = try ConfigMainCommand.Show.parse([])
    }

    @Test("rejects unexpected positional arguments")
    func rejectsUnexpected() {
        #expect(throws: (any Error).self) {
            _ = try ConfigMainCommand.Show.parse(["surprise"])
        }
    }
}
