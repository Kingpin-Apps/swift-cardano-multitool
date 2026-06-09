import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("GenerateMainCommand.Ed25519Key")
struct Ed25519KeyTests {

    @Test("parses --name")
    func parsesName() throws {
        let cmd = try GenerateMainCommand.Ed25519Key.parse(["--name", "mykey"])
        #expect(cmd.name == "mykey")
    }
}
