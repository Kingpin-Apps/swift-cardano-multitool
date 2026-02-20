import Foundation
import ArgumentParser

enum TransactionCommands: String, CaseIterable, CustomStringConvertible {
    case build
    case buildRaw = "build-raw"
    case sign
    case assemble
    case witness
    case submit
    case calculateMinFee = "calculate-min-fee"
    case calculateMinRequiredUtxo = "calculate-min-required-utxo"
    case hashScriptData = "hash-script-data"
    case rewardsWithdraw = "rewards-wirhdraw"
    case txid
    case view
    case back
    case exit
    
    var description: String {
        switch self {
            case .build: return "Build a transaction."
            case .buildRaw: return "Build a raw transaction."
            case .sign: return "Sign a transaction."
            case .assemble: return "Assemble a transaction."
            case .witness: return "Create a transaction witness."
            case .submit: return "Submit a transaction."
            case .calculateMinFee: return "Calculate minimum transaction fee."
            case .calculateMinRequiredUtxo: return "Calculate minimum required UTXO."
            case .hashScriptData: return "Hash script data."
            case .rewardsWithdraw: return "Generate a rewards withdraw transaction."
            case .txid: return "Calculate transaction ID."
            case .view: return "View transaction details."
            case .back: return "Go back to the main menu."
            case .exit: return "Exit the program."
        }
    }
    
    func command() -> any AsyncParsableCommand.Type {
        switch self {
            case .build: return TransactionMainCommand.Build.self
            case .buildRaw: return TransactionMainCommand.BuildRaw.self
            case .sign: return TransactionMainCommand.Sign.self
            case .assemble: return TransactionMainCommand.Assemble.self
            case .witness: return TransactionMainCommand.Witness.self
            case .submit: return TransactionMainCommand.Submit.self
            case .calculateMinFee: return TransactionMainCommand.CalculateMinFee.self
            case .calculateMinRequiredUtxo: return TransactionMainCommand.CalculateMinRequiredUtxo.self
            case .hashScriptData: return TransactionMainCommand.HashScriptData.self
            case .rewardsWithdraw: return TransactionMainCommand.RewardsWithdraw.self
            case .txid: return TransactionMainCommand.Txid.self
            case .view: return TransactionMainCommand.View.self
            case .back: return MainMenuCommand.self
            case .exit: return ExitCommand.self
        }
    }
}

struct TransactionMainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "transaction",
        abstract: "Transaction related commands.",
        subcommands: TransactionCommands.allCases.map { $0.command() },
        aliases: ["tx"]
    )
    
    func run() async throws {
        let selectedOption: TransactionCommands = noora.singleChoicePrompt(
            title: "Select Transaction Command",
            question: "Select the operation that you would like to perform.",
            description: "Available commands:" ,
        )
        
        print(noora.format(
            "Running \(.command(selectedOption.rawValue)) command...\n"
        ))
        
        await selectedOption.command().main([])
    }
}

extension TransactionMainCommand {
    struct Build: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Build a transaction.")
        func run() async throws { print("Transaction build command not yet implemented") }
    }
    struct BuildRaw: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Build a raw transaction.")
        func run() async throws { print("Transaction build-raw command not yet implemented") }
    }
    struct Assemble: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Assemble a transaction.")
        func run() async throws { print("Transaction assemble command not yet implemented") }
    }
    struct Witness: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Create a transaction witness.")
        func run() async throws { print("Transaction witness command not yet implemented") }
    }
    struct CalculateMinFee: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Calculate minimum transaction fee.")
        func run() async throws { print("Transaction calculate-min-fee command not yet implemented") }
    }
    struct CalculateMinRequiredUtxo: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Calculate minimum required UTXO.")
        func run() async throws { print("Transaction calculate-min-required-utxo command not yet implemented") }
    }
    struct HashScriptData: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Hash script data.")
        func run() async throws { print("Transaction hash-script-data command not yet implemented") }
    }
    struct Txid: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Calculate transaction ID.")
        func run() async throws { print("Transaction txid command not yet implemented") }
    }
}
