import Foundation
import ArgumentParser

enum ConfigCommands: String, Subcommandable {
    case `init`
    case show
    case select
    case back
    case exit
    
    var description: String {
        switch self {
            case .`init`:
                return "Initialize - Set up configuration for the first time or reset existing configuration."
            case .show:
                return "Show - Display the current configuration."
            case .select:
                return "Select - Choose configuration values."
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
            case .`init`:
                return ConfigMainCommand.Init.self
            case .show:
                return ConfigMainCommand.Show.self
            case .select:
                return ConfigMainCommand.Select.self
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
