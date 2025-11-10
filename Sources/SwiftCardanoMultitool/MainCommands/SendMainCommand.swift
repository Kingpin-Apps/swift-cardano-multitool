import Foundation
import ArgumentParser

enum SendCommands: String, CaseIterable, CustomStringConvertible {
    case ada
    case assets
    case all
    
    var description: String {
        switch self {
            case .ada: return "Send ADA."
            case .assets: return "Send native assets."
            case .all: return "Send all assets from address."
        }
    }
    
    func command() -> any AsyncParsableCommand.Type {
        switch self {
            case .ada: return SendMainCommand.Ada.self
            case .assets: return SendMainCommand.Assets.self
            case .all: return SendMainCommand.All.self
        }
    }
}

struct SendMainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "send",
        abstract: "Send Ada and assets.",
        subcommands: SendCommands.allCases.map { $0.command() }
    )
    
    func run() async throws {
        let selectedOption: SendCommands = noora.singleChoicePrompt(
            title: "Select Send Command",
            question: "Select the operation that you would like to perform.",
            description: "Available Send Commands:",
        )
        
        print(noora.format(
            "Running \(.command(selectedOption.rawValue)) command...\n"
        ))
        
        await selectedOption.command().main([])
    }
}

extension SendMainCommand {
    struct All: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Send all assets from address.")
        func run() async throws { print("Send all command not yet implemented") }
    }
}
