import ArgumentParser
import Testing
@testable import SwiftCardanoMultitool

@Suite("RunMainCommand smoke tests")
struct RunCommandsTests {

    @Test("Node: abstract is set")
    func nodeAbstract() {
        #expect(RunMainCommand.Node.configuration.abstract == "Run cardano-node.")
    }

    @Test("Node: parses --use-default-entrypoint")
    func nodeParsesUseDefaultEntrypoint() throws {
        let cmd = try RunMainCommand.Node.parse(["--use-default-entrypoint=true"])
        #expect(cmd.useDefaultEntrypoint == true)
    }

    @Test("Kupo: abstract is set")
    func kupoAbstract() {
        #expect(RunMainCommand.Kupo.configuration.abstract == "Run kupo.")
    }

    @Test("Ogmios: abstract is set")
    func ogmiosAbstract() {
        #expect(RunMainCommand.Ogmios.configuration.abstract == "Run ogmios.")
    }

    @Test("DbSync: commandName is 'db-sync'")
    func runDbSyncCommandName() {
        #expect(RunMainCommand.DbSync.configuration.commandName == "db-sync")
    }

    @Test("SubmitApi: commandName is 'submit-api'")
    func runSubmitAPICommandName() {
        #expect(RunMainCommand.SubmitApi.configuration.commandName == "submit-api")
    }

    @Test("Wallet: commandName is 'cardano-wallet'")
    func runWalletCommandName() {
        #expect(RunMainCommand.Wallet.configuration.commandName == "cardano-wallet")
    }
}
