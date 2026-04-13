import Foundation
import ArgumentParser

enum RunCommands: String, Subcommandable {
    case cardanoNode
    case cardanoDbSync = "db-sync"
    case cardanoWallet
    case cardanoSubmitAPI = "submit-api"
    case ogmios
    case kupo
    case back
    case exit
    
    var description: String {
        switch self {
            case .cardanoNode: return "Cardano Node  - Run cardano-node."
            case .cardanoDbSync: return "Cardano DB Sync - Run cardano-db-sync."
            case .cardanoWallet: return "Cardano Wallet - Run cardano-wallet."
            case .cardanoSubmitAPI: return "Cardano Submit API - Run cardano-submit-api."
            case .ogmios: return "Ogmios - Run Ogmios."
            case .kupo: return "Kupo - Run Kupo."
            case .back: return "Back - Go back to the main menu."
            case .exit: return "Exit - Leave the program."
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

struct RunMainCommand: AsyncParsableCommand, MainCommandable {
    typealias E = RunCommands
    
    var name: String { "Run" }
    
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run various cardano tools.",
        discussion: """
        Run various Cardano tools such as cardano-node, cardano-db-sync, 
        cardano-wallet, cardano-submit-api, Ogmios, and Kupo. Select the desired 
        tool from the options to proceed with running the selected tool. You can 
        also choose to go back to the main menu
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
