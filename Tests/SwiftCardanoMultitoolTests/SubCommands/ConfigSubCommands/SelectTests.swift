import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("ConfigMainCommand.Select")
struct ConfigSelectTests {

    // Select takes no arguments and immediately prompts the user; its run() path is
    // covered by Tier 3 once PromptProvider is in place. For now just verify the
    // argument-parser configuration is well-formed.

    @Test("configuration abstract is set")
    func configurationAbstractSet() {
        #expect(ConfigMainCommand.Select.configuration.abstract == "Select configuration values.")
    }

    @Test("parses with no arguments")
    func parsesEmpty() throws {
        _ = try ConfigMainCommand.Select.parse([])
    }

    @Test("rejects unexpected positional arguments")
    func rejectsUnexpected() {
        #expect(throws: (any Error).self) {
            _ = try ConfigMainCommand.Select.parse(["unexpected"])
        }
    }
}
