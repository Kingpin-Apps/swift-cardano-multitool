import ArgumentParser
import Noora
import Foundation
import Logging

/// Top-level command groups available from the main menu and as CLI subcommands.
enum MainCommands: String, CaseIterable, AlignedChoiceDescribable {
    case asset
    case build
    case certificates
    case config
    case download
    case generate
    case governance
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

    var name: String {
        switch self {
            case .asset: return "Asset"
            case .build: return "Build"
            case .certificates: return "Certificates"
            case .config: return "Config"
            case .download: return "Download"
            case .generate: return "Generate"
            case .governance: return "Governance"
            case .install: return "Install"
            case .protect: return "Protect"
            case .query: return "Query"
            case .run: return "Run"
            case .send: return "Send"
            case .transaction: return "Transaction"
            case .version: return "Version"
            case .workOffline: return "Work Offline"
            case .exit: return "Exit"
        }
    }

    var details: String {
        switch self {
            case .asset: return "Mint and burn native assets."
            case .build: return "Build payment and stake address from keys."
            case .certificates: return "Create and submit various certificates."
            case .config: return "Manage configuration settings."
            case .download: return "Download necessary files or data."
            case .generate: return "Create keys, addresses, or other data."
            case .governance: return "Cast votes and (later) submit governance-action proposals."
            case .install: return "Install cli tools or dependencies."
            case .protect: return "Secure sensitive data with a password."
            case .query: return "Get various data from the blockchain."
            case .run: return "Start various Cardano services."
            case .send: return "Transfer ADA or assets."
            case .transaction: return "Operate on Cardano transactions."
            case .version: return "Show version information."
            case .workOffline: return "Operations for working offline."
            case .exit: return "Quit the program."
        }
    }

    func command() -> any AsyncParsableCommand.Type {
        switch self {
            case .asset: return AssetMainCommand.self
            case .build: return BuildMainCommand.self
            case .certificates: return CertificateMainCommand.self
            case .config: return ConfigMainCommand.self
            case .download: return DownloadMainCommand.self
            case .generate: return GenerateMainCommand.self
            case .governance: return GovernanceMainCommand.self
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
        version: Version.number,
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
