import Foundation
import ArgumentParser

enum ConfigCommands: String, CaseIterable, CustomStringConvertible {
    case `init`
    case show
    case select
    case network
    case node
    case paths
    case back
    case exit
    
    var description: String {
        switch self {
            case .`init`:
                return "Initialize a new configuration file."
            case .show:
                return "Show current configuration."
            case .select:
                return "Select configuration values."
            case .network:
                return "Configure network settings."
            case .node:
                return "Configure node settings."
            case .paths:
                return "Configure file paths."
            case .back: 
                return "Go back to the main menu."
            case .exit:
                return "Exit the program."
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
            case .network:
                return ConfigMainCommand.Network.self
            case .node:
                return ConfigMainCommand.Node.self
            case .paths:
                return ConfigMainCommand.Paths.self
            case .back:
                return MainMenuCommand.self
            case .exit:
                return ExitCommand.self
        }
    }
}

struct ConfigMainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Configure Cardano SPO Tools.",
        subcommands: ConfigCommands.allCases.map { $0.command() }
    )
    
    func run() async throws {
        let selectedOption: ConfigCommands = noora.singleChoicePrompt(
            title: "Select Config Command",
            question: "Select the operation that you would like to perform.",
            description: "Config Commands:",
        )
        
        spacedPrint(
            "Running \(.command(selectedOption.rawValue)) command...\n"
        )
        
        await selectedOption.command().main([])
    }
}

extension ConfigMainCommand {
    struct Network: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Configure network settings."
        )
        
        func run() async throws {
            print("Config network command not yet implemented")
        }
    }
    
    struct Node: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Configure node settings."
        )
        
        func run() async throws {
            print("Config node command not yet implemented")
        }
    }
    
    struct Paths: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Configure file paths."
        )
        
        func run() async throws {
            print("Config paths command not yet implemented")
        }
    }
}
