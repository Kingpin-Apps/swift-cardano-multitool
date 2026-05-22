import Foundation
import ArgumentParser
import Noora

enum InstallCommands: String, Subcommandable, AlignedChoiceDescribable {
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

    var name: String {
        switch self {
            case .cardanoNode: return "Cardano Node"
            case .cardanoDbSync: return "Cardano Db Sync"
            case .cardanoCLI: return "Cardano CLI"
            case .cardanoHWCLI: return "Cardano HW CLI"
            case .cardanoSigner: return "Cardano Signer"
            case .cardanoSubmitAPI: return "Cardano Submit API"
            case .cardanoWallet: return "Cardano Wallet"
            case .kupo: return "Kupo"
            case .mithril: return "Mithril"
            case .ogmios: return "Ogmios"
            case .back: return "Back"
            case .exit: return "Exit"
        }
    }

    var details: String {
        switch self {
            case .cardanoNode: return "The backbone of the Cardano blockchain."
            case .cardanoDbSync: return "A tool for synchronizing Cardano blockchain data to a PostgreSQL database."
            case .cardanoCLI: return "The command-line interface for Cardano."
            case .cardanoHWCLI: return "For managing hardware wallets (Ledger/Trezor)."
            case .cardanoSigner: return "For securely signing transactions and messages."
            case .cardanoSubmitAPI: return "A lightweight transaction submission service."
            case .cardanoWallet: return "The Cardano Wallet software for managing your funds."
            case .kupo: return "A lightweight Cardano chain indexer."
            case .mithril: return "For fast Cardano node bootstrapping via certified snapshots."
            case .ogmios: return "A lightweight bridge interface for the Cardano node."
            case .back: return "Go back to the main menu."
            case .exit: return "Leave the program."
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
