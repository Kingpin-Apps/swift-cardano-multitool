import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoChain
import SwiftCardanoUtils


extension TransactionMainCommand {
    struct Id: TransactionAsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "txid",
            abstract: "View transaction id.",
            usage: """
            scm transaction txid --tx-file test.tx
            """,
            discussion: """
            View the id of a Cardano transaction stored in a file or provided as raw CBOR hex.
            """,
            aliases: ["id"]
        )
        
        // MARK: - Required Arguments
        
        @Option(name: [.short, .long], help: "The file path to the transaction file.")
        var txFile: FilePath?
        
        @Option(name: .shortAndLong, help: "Raw CBOR hex string of the transaction.")
        var cborHex: String?
        
        @Flag(
            name: .shortAndLong,
            help: "Output as JSON instead of formatted text."
        )
        var json: Bool = false
        
        @Option(name: .long, help: "Whether to use the cardano-cli or SwiftCardano to get the transaction id.")
        var tool: Tool = .swiftCardano
        
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
                    txFile = try await getTransactionFilePath(title: "Select a transaction file.")
            }
            
            tool = try await getToolToUse()
        }
        
        mutating func run() async throws {
            if txFile == nil && cborHex == nil {
                try await self.wizard()
            }
            
            let tx = try resolveTransaction()
            
            let config = try await MultitoolConfig.load(quiet: json)
            let cardanoConfig = try getCardanoConfig(config: config)
            
            if !json{
                try await printToolInfo(config: config, tool: tool)
            }
            
            let explorer = config.blockchainExplorer.explorer(
                network: cardanoConfig.network
            )
            
            let id: String
            switch tool {
                case .cardanoCLI:
                    let cli = try await CardanoCLI(
                        configuration: config.toSwiftCardanoUtilsConfig()
                    )
                    
                    id = try await cli.transaction.txId(
                        arguments: [
                            "--tx-body-file", effectiveTxFile.string,
                            "--output-json"
                        ]
                    )
                case .swiftCardano:
                    id = tx.id!.description
            }
            
            let txURL = try explorer.viewTransaction(
                transactionId: TransactionId(payload: id.hexStringToData)
            )
            
            if !json{
                spacedPrint(
                    "Transaction ID (\(.muted("using \(tool.description)")): \(.primary(id))"
                )
                spacedPrint("Transaction URL: \(.link(title:txURL.absoluteString, href: txURL.absoluteString))")
            } else {
                let outputDictionary: [String: String] = [
                    "id": id,
                    "explorerUrl": txURL.absoluteString
                ]
                
                let outputJSON = try JSONSerialization.data(
                    withJSONObject: outputDictionary,
                    options: [
                        .prettyPrinted,
                        .withoutEscapingSlashes
                    ]
                )
                
                let jsonString = String(
                    data: outputJSON,
                    encoding: .utf8
                ) ?? "{}"
                
                print(
                    jsonString,
                    terminator: "\n\n"
                )
            }
        }
    }
}
