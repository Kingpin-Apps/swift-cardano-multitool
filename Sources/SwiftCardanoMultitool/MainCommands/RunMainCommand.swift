import Foundation
import ArgumentParser

enum RunCommands: String, Subcommandable, AlignedChoiceDescribable {
    case cardanoNode
    case cardanoDbSync = "db-sync"
    case cardanoWallet
    case cardanoSubmitAPI = "submit-api"
    case ogmios
    case kupo
    case back
    case exit

    var name: String {
        switch self {
            case .cardanoNode: return "Cardano Node"
            case .cardanoDbSync: return "Cardano DB Sync"
            case .cardanoWallet: return "Cardano Wallet"
            case .cardanoSubmitAPI: return "Cardano Submit API"
            case .ogmios: return "Ogmios"
            case .kupo: return "Kupo"
            case .back: return "Back"
            case .exit: return "Exit"
        }
    }

    var details: String {
        switch self {
            case .cardanoNode: return "Run cardano-node."
            case .cardanoDbSync: return "Run cardano-db-sync."
            case .cardanoWallet: return "Run cardano-wallet."
            case .cardanoSubmitAPI: return "Run cardano-submit-api."
            case .ogmios: return "Run Ogmios."
            case .kupo: return "Run Kupo."
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
            case .cardanoNode: return RunMainCommand.Node.self
            case .cardanoDbSync: return RunMainCommand.DbSync.self
            case .cardanoWallet: return RunMainCommand.Wallet.self
            case .cardanoSubmitAPI: return RunMainCommand.SubmitApi.self
            case .ogmios: return RunMainCommand.Ogmios.self
            case .kupo: return RunMainCommand.Kupo.self
            case .back: return MainMenuCommand.self
            case .exit: return ExitCommand.self
        }
    }
}

/// Starts Cardano node services using settings from the active config file.
///
/// Covers the full Cardano service stack: node, db-sync, wallet, submit API,
/// Ogmios, and Kupo. See <doc:RunCommand> for full documentation.
struct RunMainCommand: AsyncParsableCommand, MainCommandable {
    typealias E = RunCommands

    var name: String { "Run" }

    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Start Cardano node services (node, db-sync, wallet, ogmios, kupo).",
        discussion: """
        Launch Cardano services in the foreground using parameters from the
        active configuration file. Requires the respective binaries to be
        installed — use `scm install` to download missing tools.
        """,
        subcommands: RunCommands.subcommands
    )
    
    func run() async throws {        
        let selectedOption: RunCommands = noora.singleChoicePrompt(
            title: "Select Run Command",
            question: "Select the operation that you would like to perform.",
            description: "Available commands:" ,
        )
        
        spacedPrint(
            "Running \(.command(selectedOption.rawValue)) command...\n"
        )
        
        await selectedOption.command().main([])
    }
}
