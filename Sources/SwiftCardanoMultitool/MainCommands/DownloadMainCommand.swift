import Foundation
import ArgumentParser

enum DownloadCommands: String, CaseIterable, CustomStringConvertible {
    case nodeConfigs
    case snapshot
    case back
    case exit
    
    var description: String {
        switch self {
            case .nodeConfigs: return "Node Configs - Download node configurations from https://book.world.dev.cardano.org/."
            case .snapshot: return "Database Snapshot - Download blockchain snapshot."
            case .back: return "Back - Go back to the main menu."
            case .exit: return "Exit - Leave the program."
        }
    }
    
    func command() -> any AsyncParsableCommand.Type {
        switch self {
            case .nodeConfigs: return DownloadMainCommand.NodeConfigs.self
            case .snapshot: return DownloadMainCommand.Snapshot.self
            case .back: return MainMenuCommand.self
            case .exit: return ExitCommand.self
        }
    }
}

struct DownloadMainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "download",
        abstract: "Download various files.",
        subcommands: DownloadCommands.allCases.map { $0.command() }
    )
    
    func run() async throws {
        let selectedOption: DownloadCommands = noora.singleChoicePrompt(
            title: "Select Download Command",
            question: "Select the operation that you would like to perform.",
            description: "Choose one of the following options:",
        )
        
        print(noora.format(
            "Running \(.command(selectedOption.rawValue)) command...\n"
        ))
        
        await selectedOption.command().main([])
    }
}
