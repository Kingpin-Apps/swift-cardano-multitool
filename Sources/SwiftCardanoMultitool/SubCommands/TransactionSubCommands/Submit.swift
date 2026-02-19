import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftCardanoChain
import Path

extension TransactionMainCommand {
    struct Submit: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Submit a transaction.",
            discussion: """
            Submit a signed transaction to the Cardano network.
            You need to provide the file path to the transaction file.
            The transaction should be signed and valid before submission.
            """
        )
        
        
        // MARK: - Required Arguments
        
        @Option(name: [.short, .long], help: "The file path to the transaction to submit.")
        var txFile: FilePath?
        
        // MARK: - Wizard
        
        mutating func wizard() async throws {
            txFile = try await getTransactionFilePath()
        }
        
        mutating func run() async throws {
            // If no arguments provided, run wizard
            if txFile == nil {
                try await self.wizard()
            }
            
            guard let txFile = txFile else {
                noora.error("Transaction file path is required.")
                throw ExitCode.validationFailure
            }
            
            let config = try await MultitoolConfig.load()
            let context = try await getContext(config: config)
            try await printContextInfo(config: config, context: context)
            
            let confirm = noora.yesOrNoChoicePrompt(
                title: "Confim Submission",
                question: "Does this look good for you, continue?",
                defaultAnswer: false,
                description: "Please confirm if you would like to submit the transaction to the network."
            )
            
            if !confirm {
                noora.info("Transaction submission cancelled by user.")
                throw ExitCode.success
            }
            
            spacedPrint("\nSubmitting transaction...")
            
            do {
                let tx = try Transaction.load(from: txFile.string)
                let txId = try await context.submitTx(tx: .transaction(tx))
                
                print(noora.format(
                    "\n\(.success("━━━ Transaction Submitted Successfully ━━━"))\n"
                ))
                
                let cardanoConfig = try getCardanoConfig(config: config)
                
                let explorer = config.blockchainExplorer.explorer(
                    network: cardanoConfig.network
                )
                let trackingURL = try explorer.viewTransaction(
                    transactionId: tx.transactionBody.id
                )
                
                spacedPrint("Tracking: \(.link(title:trackingURL.absoluteString, href: trackingURL.absoluteString))")
                
                noora.success(
                    "Transaction submitted with ID: \(txId)"
                )
                
            } catch {
                noora.error(.alert(
                    "Transaction submission failed. Error: \(error)",
                    takeaways: [
                        "Check the transaction file is saved at: \(txFile.string)",
                        "Ensure the transaction is valid and signed correctly.",
                        "Make sure your endpoint is synced and reachable.",
                        "You can try submitting it manually."
                    ]
                ))
                throw ExitCode.failure
            }
        }
    }
}
