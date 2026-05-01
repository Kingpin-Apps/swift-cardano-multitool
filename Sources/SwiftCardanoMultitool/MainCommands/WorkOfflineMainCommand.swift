import Foundation
import ArgumentParser

enum WorkOfflineCommands: String, Subcommandable {
    case new
    case info
    case sync
    case execute
    case attach
    case extract
    case clearTx = "clear-tx"
    case clearHistory = "clear-history"
    case clearFiles = "clear-files"
    case back
    case exit

    var description: String {
        switch self {
            case .new: return "New - Create new offline transfer file."
            case .info: return "Info - Display contents of the offline transfer file."
            case .sync: return "Sync - Add UTXO or rewards info from the blockchain."
            case .execute: return "Execute - Submit a queued transaction."
            case .attach: return "Attach - Embed a file into the offline transfer file."
            case .extract: return "Extract - Extract embedded files from the offline transfer file."
            case .clearTx: return "ClearTx - Remove all queued transactions."
            case .clearHistory: return "ClearHistory - Clear the history entries."
            case .clearFiles: return "ClearFiles - Remove all attached files."
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
            case .new: return WorkOfflineMainCommand.New.self
            case .info: return WorkOfflineMainCommand.Info.self
            case .sync: return WorkOfflineMainCommand.Sync.self
            case .execute: return WorkOfflineMainCommand.Execute.self
            case .attach: return WorkOfflineMainCommand.Attach.self
            case .extract: return WorkOfflineMainCommand.Extract.self
            case .clearTx: return WorkOfflineMainCommand.ClearTx.self
            case .clearHistory: return WorkOfflineMainCommand.ClearHistory.self
            case .clearFiles: return WorkOfflineMainCommand.ClearFiles.self
            case .back: return MainMenuCommand.self
            case .exit: return ExitCommand.self
        }
    }
}

/// Offline transaction workflow for air-gapped machines.
///
/// Uses a portable transfer file to carry chain data to an offline machine
/// and bring signed transactions back for submission. No private keys ever
/// leave the offline environment. See <doc:WorkOfflineCommand> for the full
/// workflow and documentation.
struct WorkOfflineMainCommand: AsyncParsableCommand, MainCommandable {
    typealias E = WorkOfflineCommands

    var name: String { "Work Offline" }

    static let configuration = CommandConfiguration(
        commandName: "work-offline",
        abstract: "Offline transaction workflows for air-gapped machines.",
        discussion: """
        Manage a portable offline transfer file that carries UTxO data and
        protocol parameters to an air-gapped machine and returns signed
        transactions for submission — keeping private keys completely isolated
        from the internet.
        """,
        subcommands: WorkOfflineCommands.subcommands,
        aliases: ["offline"]
    )
}

