import Foundation
import ArgumentParser

enum WorkOfflineCommands: String, CaseIterable, CustomStringConvertible {
    case sync
    case buildTx = "build-tx"
    case signTx = "sign-tx"
    case calculateFee = "calculate-fee"
    case verify
    case exportData = "export-data"
    case importData = "import-data"
    case back
    case exit
    
    var description: String {
        switch self {
            case .sync: return "Sync offline data."
            case .buildTx: return "Build transaction offline."
            case .signTx: return "Sign transaction offline."
            case .calculateFee: return "Calculate fee offline."
            case .verify: return "Verify transaction offline."
            case .exportData: return "Export offline data."
            case .importData: return "Import offline data."
            case .back: return "Go back to the main menu."
            case .exit: return "Exit the program."
        }
    }
    
    func command() -> any AsyncParsableCommand.Type {
        switch self {
            case .sync: return WorkOfflineMainCommand.Sync.self
            case .buildTx: return WorkOfflineMainCommand.BuildTx.self
            case .signTx: return WorkOfflineMainCommand.SignTx.self
            case .calculateFee: return WorkOfflineMainCommand.CalculateFee.self
            case .verify: return WorkOfflineMainCommand.Verify.self
            case .exportData: return WorkOfflineMainCommand.ExportData.self
            case .importData: return WorkOfflineMainCommand.ImportData.self
            case .back: return MainMenuCommand.self
            case .exit: return ExitCommand.self
        }
    }
}

struct WorkOfflineMainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "work-offline",
        abstract: "Work offline functions.",
        subcommands: WorkOfflineCommands.allCases.map { $0.command() }
    )
    
    func run() async throws {
        print("Use 'work-offline --help' to see available subcommands")
    }
}

extension WorkOfflineMainCommand {
    struct Sync: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Sync offline data.")
        func run() async throws { print("Work offline sync command not yet implemented") }
    }
    struct BuildTx: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Build transaction offline.")
        func run() async throws { print("Work offline build-tx command not yet implemented") }
    }
    struct SignTx: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Sign transaction offline.")
        func run() async throws { print("Work offline sign-tx command not yet implemented") }
    }
    struct CalculateFee: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Calculate fee offline.")
        func run() async throws { print("Work offline calculate-fee command not yet implemented") }
    }
    struct Verify: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Verify transaction offline.")
        func run() async throws { print("Work offline verify command not yet implemented") }
    }
    struct ExportData: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Export offline data.")
        func run() async throws { print("Work offline export-data command not yet implemented") }
    }
    struct ImportData: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Import offline data.")
        func run() async throws { print("Work offline import-data command not yet implemented") }
    }
}
