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
