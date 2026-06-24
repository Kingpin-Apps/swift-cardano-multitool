import Foundation
import ArgumentParser

enum TopologyCommands: String, Subcommandable, AlignedChoiceDescribable {
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
            case .show: return "Display the topology file."
            case .set: return "Store the path to the topology file."
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
                return ConfigMainCommand.Topology.Show.self
            case .set:
                return ConfigMainCommand.Topology.Set.self
            case .back:
                return MainMenuCommand.self
            case .exit:
                return ExitCommand.self
        }
    }
}

extension ConfigMainCommand {
    struct Topology: AsyncParsableCommand, MainCommandable {
        typealias E = TopologyCommands

        var name: String { "Topology" }

        static let configuration = CommandConfiguration(
            commandName: "topology",
            abstract: "Show or set the Cardano node topology file.",
            subcommands: TopologyCommands.subcommands
        )
    }
}
