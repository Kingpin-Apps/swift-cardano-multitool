import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("SendMainCommand.All")
struct SendAllTests {

    @Test("--send-mode accepts each documented value")
    func parsesEachMode() throws {
        let cmdAssets = try SendMainCommand.All.parse(["--send-mode", "assets-only"])
        #expect(cmdAssets.sendMode == .assetsOnly)
        let cmdLove = try SendMainCommand.All.parse(["--send-mode", "lovelaces-only"])
        #expect(cmdLove.sendMode == .lovelacesOnly)
    }

    @Test("validate rejects 'all' mode combined with --use-cardano-cli")
    func rejectsAllWithCardanoCLI() {
        #expect(throws: (any Error).self) {
            _ = try SendMainCommand.All.parse([
                "--send-mode", "all",
                "--use-cardano-cli"
            ])
        }
    }

    @Test("validate rejects 'lovelaces-only' combined with --use-cardano-cli")
    func rejectsLovelacesOnlyWithCardanoCLI() {
        #expect(throws: (any Error).self) {
            _ = try SendMainCommand.All.parse([
                "--send-mode", "lovelaces-only",
                "--use-cardano-cli"
            ])
        }
    }

    @Test("validate allows 'assets-only' with --use-cardano-cli")
    func allowsAssetsOnlyWithCardanoCLI() throws {
        let cmd = try SendMainCommand.All.parse([
            "--send-mode", "assets-only",
            "--use-cardano-cli"
        ])
        #expect(cmd.sendMode == .assetsOnly)
        #expect(cmd.transactionOptions.useCardanoCLI == true)
    }
}
