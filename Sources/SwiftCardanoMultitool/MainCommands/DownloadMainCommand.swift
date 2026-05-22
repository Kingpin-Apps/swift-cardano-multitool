import Foundation
import ArgumentParser

enum DownloadCommands: String, Subcommandable, AlignedChoiceDescribable {
    case nodeConfigs
    case snapshot
    case back
    case exit

    var name: String {
        switch self {
            case .nodeConfigs: return "Node Configs"
            case .snapshot: return "Database Snapshot"
            case .back: return "Back"
            case .exit: return "Exit"
        }
    }

    var details: String {
        switch self {
            case .nodeConfigs: return "Download node configurations from https://book.world.dev.cardano.org/."
            case .snapshot: return "Download blockchain snapshot."
            case .back: return "Go back to the main menu."
            case .exit: return "Leave the program."
        }
    }
    
    static var subcommands: [any AsyncParsableCommand.Type] {
        return Self.allCases.compactMap {
            switch $0 {
                case .back, .exit:
                    return .none
                default:
                    return $0.command()
            }
        }
    }
    
    func command() -> any AsyncParsableCommand.Type {
        switch self {
            case .nodeConfigs: return DownloadMainCommand.ConfigurationFiles.self
            case .snapshot: return DownloadMainCommand.DatabaseSnapshot.self
            case .back: return MainMenuCommand.self
            case .exit: return ExitCommand.self
        }
    }
}

/// Downloads Cardano node configuration files and Mithril database snapshots.
///
/// See <doc:DownloadCommand> for full documentation.
struct DownloadMainCommand: AsyncParsableCommand, MainCommandable {
    typealias E = DownloadCommands

    var name: String { "Download" }

    static let configuration = CommandConfiguration(
        commandName: "download",
        abstract: "Download node configuration files or a Mithril blockchain snapshot.",
        discussion: """
        Download official Cardano network configuration files (config.json,
        topology.json, genesis files) and Mithril-certified blockchain snapshots
        for fast node bootstrapping without syncing from genesis.
        """,
        subcommands: DownloadCommands.subcommands
    )
}
