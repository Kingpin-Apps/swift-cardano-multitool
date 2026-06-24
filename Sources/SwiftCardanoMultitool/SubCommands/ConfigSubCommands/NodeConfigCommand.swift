import Foundation
import ArgumentParser

enum NodeConfigCommands: String, Subcommandable, AlignedChoiceDescribable {
    case show
    case set
    case back
    case exit

    var name: String {
        switch self {
            case .show: return "Show"
            case .set: return "Set"
            case .back: return "Back"
            case .exit: return "Exit"
        }
    }

    var details: String {
        switch self {
            case .show: return "Display the node configuration (config.json)."
            case .set: return "Store the path to the node configuration file."
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
                return ConfigMainCommand.NodeConfig.Show.self
            case .set:
                return ConfigMainCommand.NodeConfig.Set.self
            case .back:
                return MainMenuCommand.self
            case .exit:
                return ExitCommand.self
        }
    }
}

extension ConfigMainCommand {
    struct NodeConfig: AsyncParsableCommand, MainCommandable {
        typealias E = NodeConfigCommands

        var name: String { "Node Config" }

        static let configuration = CommandConfiguration(
            commandName: "node-config",
            abstract: "Show or set the Cardano node configuration file.",
            subcommands: NodeConfigCommands.subcommands
        )
    }
}
