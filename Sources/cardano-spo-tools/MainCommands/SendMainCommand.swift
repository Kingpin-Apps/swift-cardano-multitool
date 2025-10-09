import Foundation
import ArgumentParser

enum SendCommands: String, CaseIterable, CustomStringConvertible {
    case ada
    case token
    case nft
    case all
    
    var description: String {
        switch self {
        case .ada: return "Send ADA."
        case .token: return "Send native tokens."
        case .nft: return "Send NFTs."
        case .all: return "Send all assets from address."
        }
    }
    
    func command() -> any AsyncParsableCommand.Type {
        switch self {
        case .ada: return SendMainCommand.Ada.self
        case .token: return SendMainCommand.Token.self
        case .nft: return SendMainCommand.Nft.self
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
        print("Use 'send --help' to see available subcommands")
    }
}

extension SendMainCommand {
    struct Ada: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Send ADA.")
        func run() async throws { print("Send ada command not yet implemented") }
    }
    struct Token: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Send native tokens.")
        func run() async throws { print("Send token command not yet implemented") }
    }
    struct Nft: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Send NFTs.")
        func run() async throws { print("Send nft command not yet implemented") }
    }
    struct All: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Send all assets from address.")
        func run() async throws { print("Send all command not yet implemented") }
    }
}
