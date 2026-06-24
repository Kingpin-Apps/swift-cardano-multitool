import Foundation
import ArgumentParser

enum ConfigCommands: String, Subcommandable, AlignedChoiceDescribable {
    case `init`
    case show
    case select
    case nodeConfig
    case genesis
    case topology
    case back
    case exit

    var name: String {
        switch self {
            case .`init`: return "Initialize"
            case .show: return "Show"
            case .select: return "Select"
            case .nodeConfig: return "Node Config"
            case .genesis: return "Genesis"
            case .topology: return "Topology"
            case .back: return "Back"
            case .exit: return "Exit"
        }
    }

    var details: String {
        switch self {
            case .`init`: return "Set up configuration for the first time or reset existing configuration."
            case .show: return "Display the current configuration."
            case .select: return "Choose configuration values."
            case .nodeConfig: return "Show or set the node configuration file (config.json)."
            case .genesis: return "Show genesis files (byron, shelley, alonzo, conway)."
            case .topology: return "Show or set the topology file."
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
            case .`init`:
                return ConfigMainCommand.Init.self
            case .show:
                return ConfigMainCommand.Show.self
            case .select:
                return ConfigMainCommand.Select.self
            case .nodeConfig:
                return ConfigMainCommand.NodeConfig.self
            case .genesis:
                return ConfigMainCommand.Genesis.self
            case .topology:
                return ConfigMainCommand.Topology.self
            case .back:
                return MainMenuCommand.self
            case .exit:
                return ExitCommand.self
        }
    }
}

struct ConfigMainCommand: AsyncParsableCommand, MainCommandable {
    typealias E = ConfigCommands
    
    var name: String { "Config" }
    
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Configure Swift Cardano Multitool.",
        discussion: """
        Set up and manage your configuration for Cardano SPO Tools. This 
        includes initializing the configuration, displaying current settings, 
        and selecting specific configuration values.
        """,
        subcommands: ConfigCommands.subcommands,
        aliases: ["conf"]
    )
}
