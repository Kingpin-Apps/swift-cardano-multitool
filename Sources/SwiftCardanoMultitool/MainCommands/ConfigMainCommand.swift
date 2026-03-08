import Foundation
import ArgumentParser

enum ConfigCommands: String, CaseIterable, CustomStringConvertible {
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
