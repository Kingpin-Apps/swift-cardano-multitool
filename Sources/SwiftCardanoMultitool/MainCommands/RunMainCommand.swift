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
        let selectedOption: RunCommands = noora.singleChoicePrompt(
            title: "Select Run Command",
            question: "Select the operation that you would like to perform.",
            description: "Available commands:" ,
        )
        
        print(noora.format(
            "Running \(.command(selectedOption.rawValue)) command...\n"
        ))
        
        await selectedOption.command().main([])
    }
}

extension RunMainCommand {
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
}
