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
        #expect(cmd.method == "binary")
    }

    @Test("CardanoCLI parses --image option")
    func cardanoCLIImage() throws {
        let cmd = try InstallMainCommand.CardanoCLI.parse([
            "--image", "ghcr.io/test/cli:latest"
        ])
        #expect(cmd.image == "ghcr.io/test/cli:latest")
    }
}
