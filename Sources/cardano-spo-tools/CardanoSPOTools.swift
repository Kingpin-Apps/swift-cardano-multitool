import ArgumentParser
import Noora
import Foundation
import Picker
import SwiftFigletKit

enum MainCommands: String, CaseIterable, CustomStringConvertible {
    case build
    case check
    case config
    case convert
    case deregister
    case download
    case get
    case generate
    case query
    case register
    case run
    case send
    case transaction
    case version
    case workOffline = "work-offline"
    
    var description: String {
        switch self {
            case .build:
                return "Build operations"
            case .check:
                return "Check operations"
            case .config:
                return "Configuration operations"
            case .convert:
                return "Convert operations"
            case .deregister:
                return "Deregister operations"
            case .download:
                return "Download operations"
            case .get:
                return "Get various data from the Cardano node"
            case .generate:
                return "Generate operations"
            case .query:
                return "Query operations"
            case .register:
                return "Register operations"
            case .run:
                return "Run operations"
            case .send:
                return "Send operations"
            case .transaction:
                return "Transaction operations"
            case .version:
                return "Show version information"
            case .workOffline:
                return "Work offline operations"
        }
    }
    
    func command() -> any AsyncParsableCommand.Type {
        switch self {
            case .build:
                return BuildMainCommand.self
            case .check:
                return CheckMainCommand.self
            case .config:
                return ConfigMainCommand.self
            case .convert:
                return ConvertMainCommand.self
            case .deregister:
                return DeregisterMainCommand.self
            case .download:
                return DownloadMainCommand.self
            case .get:
                return GetMainCommand.self
            case .generate:
                return GenerateMainCommand.self
            case .query:
                return QueryMainCommand.self
            case .register:
                return RegisterMainCommand.self
            case .run:
                return RunMainCommand.self
            case .send:
                return SendMainCommand.self
            case .transaction:
                return TransactionMainCommand.self
            case .version:
                return VersionMainCommand.self
            case .workOffline:
                return WorkOfflineMainCommand.self
        }
    }
}

@main
struct CardanoSPOTools: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cspo",
        abstract: "Cardano SPO Tools - A collection of tools for Cardano Stake Pool Operators",
        version: "0.1.0",
        subcommands: MainCommands.allCases.map { $0.command() },
        defaultSubcommand: nil
    )
    
    func run() async throws {
        let greeting = SFKRenderer.render(
            text: "Cardano SPO Tools",
            font: .named("ANSI Shadow"),
            color: .gradient(palette: [.blue, .white, .black]),
            options: .init(newline: true)
        )
        
        print(greeting)
        
        let noora = try await Terminal.shared.noora()
        
        let selectedOption: MainCommands = noora.singleChoicePrompt(
            title: "Select Command",
            question: "Select the operation that you would like to perform.",
            description: "CSPO Tools can help you manage and optimize your Cardano Stake Pool Operations."
        )
        
        print(noora.format(
            "Runing \(.command(selectedOption.rawValue)) command...\n"
        ))
        
        await selectedOption.command().main()
    }
}
