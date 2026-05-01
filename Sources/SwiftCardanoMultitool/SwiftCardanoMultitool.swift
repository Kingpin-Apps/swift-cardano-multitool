import ArgumentParser
import Noora
import Foundation
import Logging

/// Top-level command groups available from the main menu and as CLI subcommands.
enum MainCommands: String, CaseIterable, CustomStringConvertible {
    case build
    case certificates
    case config
    case download
    case generate
    case install
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
            case .download: return "Download - Download necessary files or data."
            case .generate: return "Generate - Create keys, addresses, or other data."
            case .install: return "Install - Install cli tools or dependencies."
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
            case .download: return DownloadMainCommand.self
            case .generate: return GenerateMainCommand.self
            case .install: return InstallMainCommand.self
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

/// Entry point called by the thin executable target.
@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
public func runApp() async {
    do {
        var command = try SwiftCardanoMultitool.parseAsRoot()
        if var asyncCmd = command as? any AsyncParsableCommand {
            do {
                try await asyncCmd.run()
            } catch {
                SwiftCardanoMultitool.exit(withError: error)
            }
        } else {
            do {
                try command.run()
            } catch {
                SwiftCardanoMultitool.exit(withError: error)
            }
        }
    } catch {
        SwiftCardanoMultitool.exit(withError: error)
    }
}

/// Root CLI command. When invoked with no subcommand, displays the interactive main menu.
@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
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
