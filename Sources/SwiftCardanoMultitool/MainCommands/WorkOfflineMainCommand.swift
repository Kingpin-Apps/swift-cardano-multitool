import Foundation
import ArgumentParser

enum WorkOfflineCommands: String, CaseIterable, CustomStringConvertible {
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

struct WorkOfflineMainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "work-offline",
        abstract: "Work offline functions.",
        subcommands: WorkOfflineCommands.allCases.map { $0.command() },
        aliases: ["wo"]
    )
    
    func run() async throws {
        let selectedOption: WorkOfflineCommands = noora.singleChoicePrompt(
            title: "Select Work-Offline Command",
            question: "Select the operation that you would like to perform.",
            description: "Work-Offline Commands to perform offline operations.",
        )
        
        print(noora.format(
            "Running \(.command(selectedOption.rawValue)) command...\n"
        ))
        
        await selectedOption.command().main([])
    }
}

