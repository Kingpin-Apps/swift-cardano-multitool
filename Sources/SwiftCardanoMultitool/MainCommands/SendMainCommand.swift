import Foundation
import ArgumentParser

enum SendCommands: String, Subcommandable, AlignedChoiceDescribable {
    case all
    case assets
    case lovelaces
    case back
    case exit

    var name: String {
        switch self {
            case .all: return "All"
            case .assets: return "Assets"
            case .lovelaces: return "Lovelaces"
            case .back: return "Back"
            case .exit: return "Exit"
        }
    }

    var details: String {
        switch self {
            case .all: return "Send all ADA and assets, all assets, or all ADA from an address."
            case .assets: return "Send a specific native asset (amount, all, or min) to an address."
            case .lovelaces: return "Send a lovelace amount (specific or minimum) to an address."
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
            case .all: return SendMainCommand.All.self
            case .assets: return SendMainCommand.Assets.self
            case .lovelaces: return SendMainCommand.Lovelaces.self
            case .back: return MainMenuCommand.self
            case .exit: return ExitCommand.self
        }
    }
}

/// Builds and submits transactions to transfer ADA and native assets.
///
/// Wraps the full build–sign–submit pipeline in a single guided workflow.
/// See <doc:SendCommand> for full documentation.
struct SendMainCommand: AsyncParsableCommand, MainCommandable {
    typealias E = SendCommands

    var name: String { "Send" }

    static let configuration = CommandConfiguration(
        commandName: "send",
        abstract: "Transfer ADA or native assets to another address.",
        discussion: """
        Send lovelaces, native assets, or your entire wallet balance to a
        recipient address. Fees are calculated automatically and a confirmation
        prompt is shown before submission.
        """,
        subcommands: SendCommands.allCases.map { $0.command() }
    )
}
