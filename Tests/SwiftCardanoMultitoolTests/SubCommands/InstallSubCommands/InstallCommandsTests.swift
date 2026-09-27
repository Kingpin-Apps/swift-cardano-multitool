import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("InstallMainCommand option parsing")
struct InstallCommandsOptionTests {

    @Test("CardanoNode: parses --install-dir and --method")
    func cardanoNodeOptions() throws {
        let cmd = try InstallMainCommand.CardanoNode.parse([
            "--install-dir", "/opt/bin",
            "--method", "binary"
        ])
        #expect(cmd.installDir == "/opt/bin")
        #expect(cmd.method == .binary)
    }

    @Test("rejects an unknown --method at parse time")
    func rejectsUnknownMethod() {
        #expect(throws: (any Error).self) {
            _ = try InstallMainCommand.CardanoNode.parse(["--method", "brew"])
        }
    }

    @Test("CardanoCLI parses --image option")
    func cardanoCLIImage() throws {
        let cmd = try InstallMainCommand.CardanoCLI.parse([
            "--image", "ghcr.io/test/cli:latest"
        ])
        #expect(cmd.image == "ghcr.io/test/cli:latest")
    }
}
