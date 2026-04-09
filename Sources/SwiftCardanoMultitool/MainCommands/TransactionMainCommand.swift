import Foundation
import ArgumentParser

enum TransactionCommands: String, CaseIterable, CustomStringConvertible {
    case build
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
    case inspect
    case validate
    case back
    case exit

    var description: String {
        switch self {
            case .build: return "Build - Create a transaction body from provided inputs, outputs, and metadata."
            case .sign: return "Sign - Sign a transaction."
            case .assemble: return "Assemble - Assemble a transaction."
            case .witness: return "Witness - Create a transaction witness."
            case .submit: return "Submit - Submit a transaction."
            case .calculateMinFee: return "Calculate Minimum Fee - Calculate minimum transaction fee."
            case .calculateMinRequiredUtxo: return "Calculate Minimum Required UTXO - Calculate the minimum required UTXO for a transaction."
            case .hashScriptData: return "Hash Script Data - Generate a hash for script data."
            case .rewardsWithdraw: return "Rewards Withdraw - Generate a rewards withdraw transaction."
            case .txid: return "Transaction ID - Calculate transaction ID."
            case .view: return "View - View transaction details."
            case .inspect: return "Inspect - Inspect transaction fields."
            case .validate: return "Validate - Validate a transaction against ledger rules."
            case .back: return "Back - Go back to the main menu."
            case .exit: return "Exit - Leave the program."
        }
    }

    func command() -> any AsyncParsableCommand.Type {
        switch self {
            case .build: return TransactionMainCommand.Build.self
            case .sign: return TransactionMainCommand.Sign.self
            case .assemble: return TransactionMainCommand.Assemble.self
            case .witness: return TransactionMainCommand.Witness.self
            case .submit: return TransactionMainCommand.Submit.self
            case .calculateMinFee: return TransactionMainCommand.CalculateMinFee.self
            case .calculateMinRequiredUtxo: return TransactionMainCommand.CalculateMinRequiredUtxo.self
            case .hashScriptData: return TransactionMainCommand.HashScriptData.self
            case .rewardsWithdraw: return TransactionMainCommand.RewardsWithdraw.self
            case .txid: return TransactionMainCommand.Id.self
            case .view: return TransactionMainCommand.View.self
            case .inspect: return TransactionMainCommand.Inspect.self
            case .validate: return TransactionMainCommand.Validate.self
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
}
