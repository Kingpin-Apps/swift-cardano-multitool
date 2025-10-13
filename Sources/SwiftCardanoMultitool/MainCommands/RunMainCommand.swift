import Foundation
import ArgumentParser

enum RunCommands: String, CaseIterable, CustomStringConvertible {
    case node
    case dbSync = "db-sync"
    case wallet
    case submitApi = "submit-api"
    case ogmios
    case kupo
    
    var description: String {
        switch self {
        case .node: return "Run cardano-node."
        case .dbSync: return "Run cardano-db-sync."
        case .wallet: return "Run cardano-wallet."
        case .submitApi: return "Run cardano-submit-api."
        case .ogmios: return "Run Ogmios."
        case .kupo: return "Run Kupo."
        }
    }
    
    func command() -> any AsyncParsableCommand.Type {
        switch self {
        case .node: return RunMainCommand.Node.self
        case .dbSync: return RunMainCommand.DbSync.self
        case .wallet: return RunMainCommand.Wallet.self
        case .submitApi: return RunMainCommand.SubmitApi.self
        case .ogmios: return RunMainCommand.Ogmios.self
        case .kupo: return RunMainCommand.Kupo.self
        }
    }
}

struct RunMainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run various cardano tools.",
        subcommands: RunCommands.allCases.map { $0.command() }
    )
    
    func run() async throws {
        print("Use 'run --help' to see available subcommands")
    }
}

extension RunMainCommand {
    struct Node: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Run cardano-node.")
        func run() async throws { print("Run node command not yet implemented") }
    }
    struct DbSync: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Run cardano-db-sync.")
        func run() async throws { print("Run db-sync command not yet implemented") }
    }
    struct Wallet: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Run cardano-wallet.")
        func run() async throws { print("Run wallet command not yet implemented") }
    }
    struct SubmitApi: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Run cardano-submit-api.")
        func run() async throws { print("Run submit-api command not yet implemented") }
    }
    struct Ogmios: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Run Ogmios.")
        func run() async throws { print("Run ogmios command not yet implemented") }
    }
    struct Kupo: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Run Kupo.")
        func run() async throws { print("Run kupo command not yet implemented") }
    }
}
