import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoChain


extension TransactionMainCommand {
    struct View: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "View transaction details.",
            usage: """
            scm transaction view \\
                --tx-file test.tx
            """,
            discussion: """
            View the details of a Cardano transaction stored in a file.
            """)
        
        // MARK: - Required Arguments
        
        @Option(name: [.short, .long], help: "Staking address file base name (without .stake.addr). Example: owner → owner.stake.addr")
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
            
            let tx = try Transaction.load(from: txFile.string)
            
            spacedPrint(
                "Transaction Details: \n\n \(tx.debugDescription)",
            )
        }
    }
}
