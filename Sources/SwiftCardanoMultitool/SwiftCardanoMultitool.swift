import ArgumentParser
import Noora
import Foundation
import SwiftFigletKit
import Logging

enum MainCommands: String, CaseIterable, CustomStringConvertible {
    case build
    case certificates
    case check
    case config
    case convert
    case deregister
    case download
    case get
    case generate
    case protect
    case query
    case register
    case run
    case send
    case transaction
    case version
    case workOffline = "work-offline"
    case exit
    
    var description: String {
        switch self {
            case .build:
                return "Build operations"
            case .certificates:
                return "Certificates - Create and submit certificates"
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
            case .protect:
                return "Protect operations"
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
            case .exit:
                return "Exit the program."
        }
    }
    
    func command() -> any AsyncParsableCommand.Type {
        switch self {
            case .build:
                return BuildMainCommand.self
            case .certificates:
                return CertificateMainCommand.self
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
            case .protect:
                return ProtectMainCommand.self
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
            case .exit:
                return ExitCommand.self
        }
    }
}

@main
struct SwiftCardanoMultitool: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scm",
        abstract: "SwiftCardanoMultitool - A collection of tools for Cardano.",
        version: SwiftCardanoMultitool.version?.description ?? "",
        subcommands: MainCommands.allCases.map { $0.command() },
        defaultSubcommand: nil
    )
    
    func run() async throws {
        let greeting = SFKRenderer.render(
            text: "Swift Cardano Multitool",
            font: .named("ANSI Shadow"),
            color: .gradient(palette: [.blue, .white, .black]),
            options: .init(newline: true)
        )
        
        print(greeting)
        
        // Bootstrap Logging
        LoggingSystem.bootstrap { label in
            OSLogHandler(subsystem: "com.swift-cardano-multitool", category: label)
        }
        
        await MainMenuCommand.main()
    }
    
}
