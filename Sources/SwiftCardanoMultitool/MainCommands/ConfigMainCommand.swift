import Foundation
import ArgumentParser

enum ConfigCommands: String, CaseIterable, CustomStringConvertible {
    case `init`
    case show
    case set
    case network
    case node
    case paths
    
    var description: String {
        switch self {
        case .`init`:
            return "Initialize a new configuration file."
        case .show:
            return "Show current configuration."
        case .set:
            return "Set configuration values."
        case .network:
            return "Configure network settings."
        case .node:
            return "Configure node settings."
        case .paths:
            return "Configure file paths."
        }
    }
    
    func command() -> any AsyncParsableCommand.Type {
        switch self {
        case .`init`:
            return ConfigMainCommand.Init.self
        case .show:
            return ConfigMainCommand.Show.self
        case .set:
            return ConfigMainCommand.Set.self
        case .network:
            return ConfigMainCommand.Network.self
        case .node:
            return ConfigMainCommand.Node.self
        case .paths:
            return ConfigMainCommand.Paths.self
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
        let noora = try await Terminal.shared.noora()
        
        let selectedOption: ConfigCommands = noora.singleChoicePrompt(
            title: "Select Config Command",
            question: "Select the operation that you would like to perform.",
            description: "Config Commands:",
        )
        
        print(noora.format(
            "Runing \(.command(selectedOption.rawValue)) command...\n"
        ))
        
        await selectedOption.command().main()
    }
}

extension ConfigMainCommand {
    struct Show: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show current configuration."
        )
        
        func run() async throws {
            print("Config show command not yet implemented")
        }
    }
    
    struct Set: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Set configuration values."
        )
        
        func run() async throws {
            print("Config set command not yet implemented")
        }
    }
    
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
