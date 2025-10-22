import Foundation
import ArgumentParser

enum DownloadCommands: String, CaseIterable, CustomStringConvertible {
    case nodeConfigs
    case snapshot
    
    var description: String {
        switch self {
        case .nodeConfigs: return "Download node configurations."
        case .snapshot: return "Download blockchain snapshot."
        }
    }
    
    func command() -> any AsyncParsableCommand.Type {
        switch self {
        case .nodeConfigs: return DownloadMainCommand.NodeConfigs.self
        case .snapshot: return DownloadMainCommand.Snapshot.self
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

extension DownloadMainCommand {    
    struct Snapshot: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Download blockchain snapshot.")
        func run() async throws { print("Download snapshot command not yet implemented") }
    }
}
