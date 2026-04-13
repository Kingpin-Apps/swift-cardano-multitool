import Foundation
import ArgumentParser

enum DownloadCommands: String, Subcommandable {
    case nodeConfigs
    case snapshot
    case back
    case exit
    
    var description: String {
        switch self {
            case .nodeConfigs: return "Node Configs - Download node configurations from https://book.world.dev.cardano.org/."
            case .snapshot: return "Database Snapshot - Download blockchain snapshot."
            case .back: return "Back - Go back to the main menu."
            case .exit: return "Exit - Leave the program."
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

struct DownloadMainCommand: AsyncParsableCommand, MainCommandable {
    typealias E = DownloadCommands
    
    var name: String { "Download" }
    
    static let configuration = CommandConfiguration(
        commandName: "download",
        abstract: "Download various files.",
        discussion: """
        Downloading files can be essential for various operations, such as 
        setting up a node or restoring a wallet. This command provides an easy 
        way to download necessary files directly from trusted sources. Select 
        he desired option to proceed with the download process.
        """,
        subcommands: DownloadCommands.subcommands
    )
}
