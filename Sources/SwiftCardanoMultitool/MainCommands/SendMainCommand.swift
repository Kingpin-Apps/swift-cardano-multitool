import Foundation
import ArgumentParser

enum SendCommands: String, Subcommandable {
    case all
    case assets
    case lovelaces
    case back
    case exit
    
    var description: String {
        switch self {
            case .all: return "All - Send all ADA and assets, all assets, or all ADA from an address."
            case .assets: return "Assets - Send a specific native asset (amount, all, or min) to an address."
            case .lovelaces: return "Lovelaces - Send a lovelace amount (specific or minimum) to an address."
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
            case .all: return SendMainCommand.All.self
            case .assets: return SendMainCommand.Assets.self
            case .lovelaces: return SendMainCommand.Lovelaces.self
            case .back: return MainMenuCommand.self
            case .exit: return ExitCommand.self
        }
    }
}

struct SendMainCommand: AsyncParsableCommand, MainCommandable {
    typealias E = SendCommands
    
    var name: String { "Send" }
    
    static let configuration = CommandConfiguration(
        commandName: "send",
        abstract: "Send Ada and assets.",
        discussion: """
        This command allows you to send ADA and native assets from one address 
        to another. You can choose to send all ADA and assets, specific native 
        assets, or a specific amount of lovelaces. The command provides 
        flexibility in how you want to manage your transactions, whether it's 
        sending everything or just a portion of your holdings.
        """,
        subcommands: SendCommands.allCases.map { $0.command() }
    )
}
