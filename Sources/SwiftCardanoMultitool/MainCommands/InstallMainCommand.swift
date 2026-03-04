import Foundation
import ArgumentParser
import Noora

enum InstallCommands: String, CaseIterable, CustomStringConvertible {
    case cardanoNode
    case cardanoCLI
    case cardanoHWCLI
    case cardanoSigner
    case kupo
    case mithril
    case ogmios
    case back
    case exit

    var description: String {
        switch self {
            case .cardanoNode:
                return "Install cardano-node, the backbone of the Cardano blockchain."
            case .cardanoCLI:
                return "Install cardano-cli, the command-line interface for Cardano."
            case .cardanoHWCLI:
                return "Install cardano-hw-cli, for managing hardware wallets (Ledger/Trezor)."
            case .cardanoSigner:
                return "Install cardano-signer, for securely signing transactions and messages."
            case .kupo:
                return "Install Kupo, a lightweight Cardano chain indexer."
            case .mithril:
                return "Install mithril-client, for fast Cardano node bootstrapping via certified snapshots."
            case .ogmios:
                return "Install Ogmios, a lightweight bridge interface for the Cardano node."
            case .back:
                return "Go back to the main menu."
            case .exit:
                return "Exit the program."
        }
    }

    func command() -> any AsyncParsableCommand.Type {
        switch self {
            case .cardanoNode: return InstallMainCommand.CardanoNode.self
            case .cardanoCLI: return InstallMainCommand.CardanoCLI.self
            case .cardanoHWCLI: return InstallMainCommand.CardanoHWCLI.self
            case .cardanoSigner: return InstallMainCommand.CardanoSigner.self
            case .kupo: return InstallMainCommand.Kupo.self
            case .mithril: return InstallMainCommand.Mithril.self
            case .ogmios: return InstallMainCommand.Ogmios.self
            case .back: return MainMenuCommand.self
            case .exit: return ExitCommand.self
        }
    }
}

struct InstallMainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install Cardano ecosystem tools.",
        subcommands: InstallCommands.allCases.map { $0.command() }
    )

    func run() async throws {
        let selectedOption: InstallCommands = noora.singleChoicePrompt(
            title: "Select Install Command",
            question: "Select the tool you would like to install.",
            description: "Install various components of the Cardano ecosystem."
        )

        spacedPrint(
            "Running \(.command(selectedOption.rawValue)) command..."
        )

        await selectedOption.command().main([])
    }
}
