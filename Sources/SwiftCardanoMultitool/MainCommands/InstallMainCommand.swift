import Foundation
import ArgumentParser
import Noora

enum InstallCommands: String, Subcommandable {
    case cardanoNode
    case cardanoDbSync
    case cardanoCLI
    case cardanoHWCLI
    case cardanoSigner
    case cardanoSubmitAPI
    case cardanoWallet
    case kupo
    case mithril
    case ogmios
    case back
    case exit

    var description: String {
        switch self {
            case .cardanoNode:
                return "Cardano Node - The backbone of the Cardano blockchain."
            case .cardanoDbSync:
                return "Cardano Db Sync - A tool for synchronizing Cardano blockchain data to a PostgreSQL database."
            case .cardanoCLI:
                return "Cardano CLI - The command-line interface for Cardano."
            case .cardanoHWCLI:
                return "Cardano HW CLI - For managing hardware wallets (Ledger/Trezor)."
            case .cardanoSigner:
                return "Cardano Signer - For securely signing transactions and messages."
            case .cardanoSubmitAPI:
                return "Cardano Submit API - A lightweight transaction submission service."
            case .cardanoWallet:
                return "Cardano Wallet - The Cardano Wallet software for managing your funds."
            case .kupo:
                return "Kupo - A lightweight Cardano chain indexer."
            case .mithril:
                return "Mithril - For fast Cardano node bootstrapping via certified snapshots."
            case .ogmios:
                return "Ogmios - A lightweight bridge interface for the Cardano node."
            case .back:
                return "Back - Go back to the main menu."
            case .exit:
                return "Exit - Leave the program."
        }
    }
    
    static var subcommands: [any AsyncParsableCommand.Type] {
        return Self.allCases.compactMap {
            switch $0 {
                case .back, .exit:
                    return .none
                default:
                    return $0.command()
            }
        }
    }

    func command() -> any AsyncParsableCommand.Type {
        switch self {
            case .cardanoNode: return InstallMainCommand.CardanoNode.self
            case .cardanoDbSync: return InstallMainCommand.CardanoDbSync.self
            case .cardanoCLI: return InstallMainCommand.CardanoCLI.self
            case .cardanoHWCLI: return InstallMainCommand.CardanoHWCLI.self
            case .cardanoSigner: return InstallMainCommand.CardanoSigner.self
            case .cardanoSubmitAPI: return InstallMainCommand.CardanoSubmitAPI.self
            case .cardanoWallet: return InstallMainCommand.CardanoWallet.self
            case .kupo: return InstallMainCommand.Kupo.self
            case .mithril: return InstallMainCommand.Mithril.self
            case .ogmios: return InstallMainCommand.Ogmios.self
            case .back: return MainMenuCommand.self
            case .exit: return ExitCommand.self
        }
    }
}

struct InstallMainCommand: AsyncParsableCommand, MainCommandable {
    typealias E = InstallCommands
    
    var name: String { "Install" }
    
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install Cardano ecosystem tools.",
        discussion: """
        Install various components of the Cardano ecosystem, including the 
        Cardano Node, Cardano CLI, Cardano Wallet, Kupo, Mithril, Ogmios, and 
        more. Select the tool you would like to install from the options 
        provided.
        """,
        subcommands: InstallCommands.subcommands
    )
}
