import Foundation
import ArgumentParser

enum TransactionCommands: String, Subcommandable, AlignedChoiceDescribable {
    case build
    case sign
    case assemble
    case witness
    case submit
    case calculateMinFee = "calculate-min-fee"
    case calculateMinRequiredUtxo = "calculate-min-required-utxo"
    case hashScriptData = "hash-script-data"
    case rewardsWithdraw = "rewards-withdraw"
    case txid
    case view
    case inspect
    case validate
    case back
    case exit

    var name: String {
        switch self {
            case .build: return "Build"
            case .sign: return "Sign"
            case .assemble: return "Assemble"
            case .witness: return "Witness"
            case .submit: return "Submit"
            case .calculateMinFee: return "Calculate Minimum Fee"
            case .calculateMinRequiredUtxo: return "Calculate Minimum Required UTXO"
            case .hashScriptData: return "Hash Script Data"
            case .rewardsWithdraw: return "Rewards Withdraw"
            case .txid: return "Transaction ID"
            case .view: return "View"
            case .inspect: return "Inspect"
            case .validate: return "Validate"
            case .back: return "Back"
            case .exit: return "Exit"
        }
    }

    var details: String {
        switch self {
            case .build: return "Create a transaction body from provided inputs, outputs, and metadata."
            case .sign: return "Sign a transaction."
            case .assemble: return "Assemble a transaction."
            case .witness: return "Create a transaction witness."
            case .submit: return "Submit a transaction."
            case .calculateMinFee: return "Calculate minimum transaction fee."
            case .calculateMinRequiredUtxo: return "Calculate the minimum required UTXO for a transaction."
            case .hashScriptData: return "Generate a hash for script data."
            case .rewardsWithdraw: return "Generate a rewards withdraw transaction."
            case .txid: return "Calculate transaction ID."
            case .view: return "View transaction details."
            case .inspect: return "Inspect transaction fields."
            case .validate: return "Validate a transaction against ledger rules."
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

/// Low-level Cardano transaction operations: build, sign, assemble, and submit.
///
/// Provides full control over the transaction pipeline for advanced use cases
/// beyond the high-level `send` command. See <doc:TransactionCommand> for
/// full documentation.
struct TransactionMainCommand: AsyncParsableCommand, MainCommandable {
    typealias E = TransactionCommands

    var name: String { "Transaction" }

    static let configuration = CommandConfiguration(
        commandName: "transaction",
        abstract: "Build, sign, inspect, and submit Cardano transactions.",
        discussion: """
        Full control over the Cardano transaction lifecycle: construct balanced
        transaction bodies, create witnesses, assemble multi-sig transactions,
        calculate fees and minimum UTxO values, and submit to the network.
        """,
        subcommands: TransactionCommands.subcommands,
        aliases: ["tx"]
    )
}

