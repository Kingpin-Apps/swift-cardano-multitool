import ArgumentParser
import Noora
import Foundation
import Logging

enum MainCommands: String, CaseIterable, CustomStringConvertible {
    case build
    case certificates
    case config
    case convert
    case download
    case generate
    case protect
    case query
    case run
    case send
    case transaction
    case version
    case workOffline = "work-offline"
    case exit
    
    /// The chronological index of this era (0-based)
    public var index: Int {
        MainCommands.allCases.firstIndex(of: self)!
    }
    
    var description: String {
        switch self {
            case .build: return "Build - Build payment and stake address from keys."
            case .certificates: return "Certificates - Create and submit various certificates."
            case .config: return "Config - Manage configuration settings."
            case .convert: return "Convert - Show data in various other formats."
            case .download: return "Download - Download necessary files or data."
            case .generate: return "Generate - Create keys, addresses, or other data."
            case .protect: return "Protect - Secure sensitive data with a password."
            case .query: return "Query - Get various data from the blockchain."
            case .run: return "Run - Start various Cardano services."
            case .send: return "Send - Trasnfer ADA or assets."
            case .transaction: return "Transaction - Operate on Cardano transactions."
            case .version: return "Version - Show version information."
            case .workOffline: return "Work Offline - Operations for working offline."
            case .exit: return "Exit - Quit the program."
        }
    }
    
    func command() -> any AsyncParsableCommand.Type {
        switch self {
            case .build: return BuildMainCommand.self
            case .certificates: return CertificateMainCommand.self
            case .config: return ConfigMainCommand.self
            case .convert: return ConvertMainCommand.self
            case .download: return DownloadMainCommand.self
            case .generate: return GenerateMainCommand.self
            case .protect: return ProtectMainCommand.self
            case .query: return QueryMainCommand.self
            case .run: return RunMainCommand.self
            case .send: return SendMainCommand.self
            case .transaction: return TransactionMainCommand.self
            case .version: return VersionMainCommand.self
            case .workOffline: return WorkOfflineMainCommand.self
            case .exit: return ExitCommand.self
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
        let banner = """
        ███████╗ ██████╗███╗   ███╗
        ██╔════╝██╔════╝████╗ ████║
        ███████╗██║     ██╔████╔██║
        ╚════██║██║     ██║╚██╔╝██║
        ███████║╚██████╗██║ ╚═╝ ██║
        ╚══════╝ ╚═════╝╚═╝     ╚═╝
        Swift Cardano Multitool
        
        """
        print(banner)
        
        // Bootstrap Logging
        LoggingSystem.bootstrap { label in
            OSLogHandler(subsystem: "com.swift-cardano-multitool", category: label)
        }
        
        await MainMenuCommand.main()
    }
    
}
