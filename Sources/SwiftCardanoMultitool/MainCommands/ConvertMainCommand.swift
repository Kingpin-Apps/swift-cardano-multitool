import Foundation
import ArgumentParser

enum ConvertCommands: String, CaseIterable, CustomStringConvertible {
    case keys
    case address
    case certificate
    case metadata
    case transaction
    case back
    case exit
    
    var description: String {
        switch self {
            case .keys: return "Convert keys to new format."
            case .address: return "Convert address to new format."
            case .certificate: return "Convert certificate to new format."
            case .metadata: return "Convert metadata to new format."
            case .transaction: return "Convert transaction to new format."
            case .back: return "Go back to the main menu."
            case .exit: return "Exit the program."
        }
    }
    
    func command() -> any AsyncParsableCommand.Type {
        switch self {
            case .keys: return ConvertMainCommand.Keys.self
            case .address: return ConvertMainCommand.Address.self
            case .certificate: return ConvertMainCommand.Certificate.self
            case .metadata: return ConvertMainCommand.Metadata.self
            case .transaction: return ConvertMainCommand.Transaction.self
            case .back: return MainMenuCommand.self
            case .exit: return ExitCommand.self
        }
    }
}

struct ConvertMainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "convert",
        abstract: "Convert various files to new format.",
        subcommands: ConvertCommands.allCases.map { $0.command() }
    )
    
    func run() async throws {
        print("Use 'convert --help' to see available subcommands")
    }
}

extension ConvertMainCommand {
    struct Keys: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Convert keys to new format.")
        func run() async throws { print("Convert keys command not yet implemented") }
    }
    
    struct Address: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Convert address to new format.")
        func run() async throws { print("Convert address command not yet implemented") }
    }
    
    struct Certificate: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Convert certificate to new format.")
        func run() async throws { print("Convert certificate command not yet implemented") }
    }
    
    struct Metadata: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Convert metadata to new format.")
        func run() async throws { print("Convert metadata command not yet implemented") }
    }
    
    struct Transaction: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Convert transaction to new format.")
        func run() async throws { print("Convert transaction command not yet implemented") }
    }
}
