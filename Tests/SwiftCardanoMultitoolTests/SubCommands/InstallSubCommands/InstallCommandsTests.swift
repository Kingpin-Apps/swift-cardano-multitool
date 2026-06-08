import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("InstallMainCommand smoke tests")
struct InstallCommandsTests {

    @Test("CardanoNode: commandName 'cardano-node'")
    func cardanoNode() {
        #expect(InstallMainCommand.CardanoNode.configuration.commandName == "cardano-node")
    }

    @Test("CardanoNode: parses --install-dir and --method")
    func cardanoNodeOptions() throws {
        let cmd = try InstallMainCommand.CardanoNode.parse([
            "--install-dir", "/opt/bin",
            "--method", "binary"
        ])
        #expect(cmd.installDir == "/opt/bin")
        #expect(cmd.method == "binary")
    }

    @Test("CardanoCLI: commandName 'cardano-cli'")
    func cardanoCLI() {
        #expect(InstallMainCommand.CardanoCLI.configuration.commandName == "cardano-cli")
    }

    @Test("CardanoHWCLI: commandName 'cardano-hw-cli'")
    func cardanoHWCLI() {
        #expect(InstallMainCommand.CardanoHWCLI.configuration.commandName == "cardano-hw-cli")
    }

    @Test("CardanoSigner: commandName 'cardano-signer'")
    func cardanoSigner() {
        #expect(InstallMainCommand.CardanoSigner.configuration.commandName == "cardano-signer")
    }

    @Test("CardanoSubmitAPI: commandName 'cardano-submit-api'")
    func cardanoSubmitAPI() {
        #expect(InstallMainCommand.CardanoSubmitAPI.configuration.commandName == "cardano-submit-api")
    }

    @Test("CardanoDbSync: commandName 'cardano-db-sync'")
    func cardanoDbSync() {
        #expect(InstallMainCommand.CardanoDbSync.configuration.commandName == "cardano-db-sync")
    }

    @Test("CardanoWallet: commandName 'cardano-wallet'")
    func cardanoWallet() {
        #expect(InstallMainCommand.CardanoWallet.configuration.commandName == "cardano-wallet")
    }

    @Test("Kupo: commandName 'kupo'")
    func installKupo() {
        #expect(InstallMainCommand.Kupo.configuration.commandName == "kupo")
    }

    @Test("Ogmios: commandName 'ogmios'")
    func installOgmios() {
        #expect(InstallMainCommand.Ogmios.configuration.commandName == "ogmios")
    }

    @Test("Mithril: commandName 'mithril'")
    func mithril() {
        #expect(InstallMainCommand.Mithril.configuration.commandName == "mithril")
    }
}

// MARK: - parse() smoke tests for each Install subcommand (improves option-decoder coverage)

@Suite("InstallMainCommand parse() smoke tests")
struct InstallCommandsParseTests {

    @Test("CardanoCLI parses with no args (every option defaults to nil)")
    func cardanoCLIDefaults() throws {
        let cmd = try InstallMainCommand.CardanoCLI.parse([])
        #expect(cmd.installDir == nil)
        #expect(cmd.method == nil)
        #expect(cmd.image == nil)
    }

    @Test("CardanoCLI parses --image option")
    func cardanoCLIImage() throws {
        let cmd = try InstallMainCommand.CardanoCLI.parse([
            "--image", "ghcr.io/test/cli:latest"
        ])
        #expect(cmd.image == "ghcr.io/test/cli:latest")
    }

    @Test("CardanoHWCLI parses with no args")
    func cardanoHWCLIDefaults() throws {
        let cmd = try InstallMainCommand.CardanoHWCLI.parse([])
        #expect(cmd.installDir == nil)
        #expect(cmd.method == nil)
    }

    @Test("CardanoSigner parses with no args")
    func cardanoSignerDefaults() throws {
        let cmd = try InstallMainCommand.CardanoSigner.parse([])
        #expect(cmd.installDir == nil)
        #expect(cmd.method == nil)
    }

    @Test("CardanoSubmitAPI parses with no args")
    func cardanoSubmitAPIDefaults() throws {
        let cmd = try InstallMainCommand.CardanoSubmitAPI.parse([])
        #expect(cmd.installDir == nil)
        #expect(cmd.method == nil)
    }

    @Test("CardanoDbSync parses with no args")
    func cardanoDbSyncDefaults() throws {
        let cmd = try InstallMainCommand.CardanoDbSync.parse([])
        #expect(cmd.installDir == nil)
        #expect(cmd.method == nil)
    }

    @Test("CardanoWallet parses with no args")
    func cardanoWalletDefaults() throws {
        let cmd = try InstallMainCommand.CardanoWallet.parse([])
        #expect(cmd.installDir == nil)
        #expect(cmd.method == nil)
    }

    @Test("Kupo parses with no args")
    func kupoDefaults() throws {
        let cmd = try InstallMainCommand.Kupo.parse([])
        #expect(cmd.installDir == nil)
        #expect(cmd.method == nil)
    }

    @Test("Ogmios parses with no args")
    func ogmiosDefaults() throws {
        let cmd = try InstallMainCommand.Ogmios.parse([])
        #expect(cmd.installDir == nil)
        #expect(cmd.method == nil)
    }

    @Test("Mithril parses with no args")
    func mithrilDefaults() throws {
        let cmd = try InstallMainCommand.Mithril.parse([])
        #expect(cmd.installDir == nil)
        #expect(cmd.method == nil)
    }
}
