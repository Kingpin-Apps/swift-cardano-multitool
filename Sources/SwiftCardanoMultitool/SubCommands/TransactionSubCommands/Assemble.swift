import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoChain
import SwiftCardanoTxBuilder
import SwiftCardanoUtils
import Path


extension TransactionMainCommand {
    struct Assemble: TransactionAsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Assemble a transaction.",
            usage: """
            scm transaction assemble \\
                --tx-file test.tx \\
                --witness-file test.payment.skey \\
                --witness-file test.stake.skey \\
                --out-file test.signed.tx \\
            """,
            discussion: """
            Assemble a transaction by providing the transaction file and witness 
            files. The transaction can be signed using either SwiftCardano or 
            cardano-cli. By default, the assembled transaction will be saved to 
            a file, but you can choose to skip saving and/or submit the 
            transaction directly to the blockchain.
            """
        )
        
        
        // MARK: - Required Arguments
        
        @Option(name: [.short, .long], help: "The file path to the transaction to submit.")
        var txFile: FilePath?
        
        @Option(name: .long, help: "Raw CBOR hex string of the transaction.")
        var cborHex: String?
        
        @Option(name: [.short, .long], help: "The file paths to the witness files (repeat option to pass multiple).")
        var witnessFiles: [FilePath] = []
        
        @Option(name: [.short, .long], help: "The file name to save the signed transaction to. If not specified, '.signed.tx' will be used with the name of the input transaction.")
        var outFile: FilePath? = nil
        
        @Flag(help: "Use cardano-cli to sign the transaction (default: use SwiftCardano)")
        var useCardanoCLI = false
        
        @Flag(inversion: .prefixedNo, help: "Save signed transaction to file")
        var save = true
        
        @Flag(help: "Submit the transaction to the blockchain")
        var submit = false
        
        // MARK: - Validation
        
        mutating func validate() throws {
            
            guard !witnessFiles.isEmpty else {
                throw ValidationError("At least one witness files is required.")
            }
            
            for key in witnessFiles {
                guard FileManager.default.fileExists(atPath: key.string) else {
                    throw ValidationError("Witness file does not exist at path: \(key.string)")
                }
            }
        }
        
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
            
            var addMore = true
            while addMore {
                let witnessFile = try await getWitnessFilePath()
                witnessFiles.append(witnessFile)
                
                addMore = noora.yesOrNoChoicePrompt(
                    title: "Add Another Witness File",
                    question: "Add another witness file?",
                    defaultAnswer: false
                )
            }
            
            let outputFile = noora.textPrompt(
                title: "Output File",
                prompt: "Enter the output file path for the signed transaction (leave blank for default):",
                collapseOnAnswer: true
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            outFile = outputFile.isEmpty ? FilePath("\(txFile!.stem!).signed.tx") : FilePath(
                outputFile
            )
            
            useCardanoCLI = noora.yesOrNoChoicePrompt(
                title: "Build Method",
                question: "Use cardano-cli to build transaction?",
                defaultAnswer: false,
                description: "Default: SwiftCardano. Alternative: cardano-cli"
            )
            
            save = noora.yesOrNoChoicePrompt(
                title: "Save Transaction",
                question: "Save signed transaction to file?",
                defaultAnswer: true,
                description: "You can submit it later if desired."
            )
            
            submit = noora.yesOrNoChoicePrompt(
                title: "Submit Transaction",
                question: "Submit the transaction to the blockchain?",
                defaultAnswer: false,
                description: "Requires network connectivity and sufficient funds."
            )
            
            try self.validate()
        }
        
        // MARK: - Run
        
        mutating func run() async throws {
            if (txFile == nil && cborHex == nil) || witnessFiles.isEmpty {
                try await self.wizard()
            }
            
            let config = try await MultitoolConfig.load()
            let context = try await getContext(config: config)
            let logger = getLogger(config: config)
            
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            
            spacedPrint("\nAssembling transaction...")
            let tx = try resolveTransaction()
            
            guard let txId = tx.id?.description else {
                noora.error("Failed to compute transaction ID.")
                throw ExitCode.failure
            }
            
            if outFile == nil && txFile != nil {
                guard let txFile = txFile else {
                    noora.error("Transaction file path is required to determine default output file name.")
                    throw ExitCode.validationFailure
                }
                outFile = cwd.appending("\(txFile.stem!).signed.tx")
            } else if outFile == nil && cborHex != nil {
                let timestamp = DateUtils.getCurrentTimestamp()
                outFile = cwd.appending("\(txId)-\(timestamp).signed.tx")
            }
            
            guard let outFile = outFile else {
                noora.error("Output file path is required.")
                throw ExitCode.validationFailure
            }
            
            noora.info(.alert(
                "Assemble the unsigned transaction \(.primary("\(txId)")) with:",
                takeaways: try witnessFiles.map {
                    "  - Witness File: \(.path(try AbsolutePath(validating: $0.string)))"
                }
            ))
            
            if useCardanoCLI {
                let cli = try await CardanoCLI(
                    configuration: Config(cardano: config.cardano),
                    logger: logger
                )
                
                let witnessArgs = witnessFiles.flatMap { ["--witness-file", $0.string] }
                
                _ = try await cli.transaction.assemble(
                    arguments: [
                        "--tx-body-file", effectiveTxFile.string,
                        "--out-file", outFile.string
                    ] + witnessArgs
                )
            } else {
                let txBuilder = TxBuilder(context: context, logger: logger)
                
                let signedTx = try txBuilder.transactions.assemble(
                    transaction: tx,
                    vkeyWitnesses: .nonEmptyOrderedSet(
                        NonEmptyOrderedSet(
                            witnessFiles.map {
                                try VerificationKeyWitness.load(from: $0.string)
                            }
                        )
                    )
                )
                
                guard let data = try signedTx.toTextEnvelope() else {
                    noora.error("Failed to save signed transaction to file: \(signedTx)")
                    throw ExitCode.failure
                }
                try await FileUtils.dumpLockedFile(outFile, data: data)
            }
            
            noora.success(.alert("Transaction assembled."))
            
            // Load the signed transaction from the output file to display it
            let signedTx = try Transaction.load(from: outFile.string)
            
            if save {
                spacedPrint(
                    "Signed transaction saved to: \(.path(try AbsolutePath(validating: outFile.string))) \n\n \(signedTx.debugDescription)"
                )
            } else {
                spacedPrint(
                    "Signed transaction: \n\n \(signedTx.debugDescription) \n\n \(String(describing: try signedTx.toTextEnvelope()))"
                )
            }
            
            let protocolParameters = try await getProtocolParameters(
                context: context
            )
            
            try checkTransactionSize(
                transaction: signedTx,
                protocolParameters: protocolParameters
            )
            
            if submit {
                await TransactionMainCommand.Submit.main([
                    "--tx-file", outFile.string
                ])
            } else {
                noora.info(.alert(
                    "Transaction not submitted. You can submit it later using the saved transaction file or cbor-encoded data."
                ))
            }
            
            if !save {
                try FileManager.default.removeItem(atPath: outFile.string)
            }
        }
    }
}
