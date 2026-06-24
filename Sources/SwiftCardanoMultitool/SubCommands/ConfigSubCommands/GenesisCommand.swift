import Foundation
import ArgumentParser

enum GenesisCommands: String, Subcommandable, AlignedChoiceDescribable {
    case show
    case back
    case exit

    var name: String {
        switch self {
            case .show: return "Show"
            case .back: return "Back"
            case .exit: return "Exit"
        }
    }

    var details: String {
        switch self {
            case .show: return "Display a genesis file (byron, shelley, alonzo, conway)."
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
            case .show:
                return ConfigMainCommand.Genesis.Show.self
            case .back:
                return MainMenuCommand.self
            case .exit:
                return ExitCommand.self
        }
    }
}

extension ConfigMainCommand {
    struct Genesis: AsyncParsableCommand, MainCommandable {
        typealias E = GenesisCommands

        var name: String { "Genesis" }

        static let configuration = CommandConfiguration(
            commandName: "genesis",
            abstract: "Show Cardano genesis files (byron, shelley, alonzo, conway).",
            discussion: """
            Genesis files are located via the node configuration: each era's
            file path is read from the node config (config.json) and resolved
            relative to it. Pass --path to point at a genesis file directly.
            """,
            subcommands: GenesisCommands.subcommands
        )
    }
}
