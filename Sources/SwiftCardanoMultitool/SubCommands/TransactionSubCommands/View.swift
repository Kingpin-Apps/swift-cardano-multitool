import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoChain


extension TransactionMainCommand {
    struct View: TransactionAsyncParsableCommand {
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
        
        @Option(name: [.short, .long], help: "The file path to the transaction to view.")
        var txFile: FilePath?
        
        @Option(name: .long, help: "Raw CBOR hex string of the transaction.")
        var cborHex: String?
        
        // MARK: - Wizard
        
        mutating func wizard() async throws {
            let enterTransactionBy = try await getTransactionBy()
            
            switch enterTransactionBy {
                case .cborHex:
                    cborHex = noora.textPrompt(
                        title: "Transaction CBOR Hex",
                        prompt: "Enter the raw CBOR hex string of the transaction:",
                        validationRules: [NonEmptyValidationRule(error: "CBOR hex cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                case .path:
                    txFile = try await getTransactionFilePath(title: "Select a transaction file to sign.")
            }
        }
        
        mutating func run() async throws {
            if txFile == nil && cborHex == nil {
                try await self.wizard()
            }
            
            guard (txFile != nil || cborHex != nil) else {
                noora.error(.alert(
                    "Missing transaction CBOR hex or tx file.",
                    takeaways: ["Provide either --tx-file or --cbor-hex."]
                ))
                throw ExitCode.validationFailure
            }
            
            let tx = try resolveTransaction()
            
            spacedPrint(
                "Transaction Details: \n\n \(tx.debugDescription)",
            )
        }
    }
}
