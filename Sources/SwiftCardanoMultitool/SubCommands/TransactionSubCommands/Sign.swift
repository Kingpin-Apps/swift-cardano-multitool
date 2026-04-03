import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftCardanoChain
import SwiftCardanoTxBuilder
import Path


extension TransactionMainCommand {
    struct Sign: TransactionAsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Sign a transaction.",
            usage: """
            scm transaction sign \\
                --tx-file test.tx \\
                --signing-keys test.payment.skey
                --signing-keys test.stake.skey
            """,
            discussion: """
            Sign a transaction using software signing keys (.skey files) or hardware wallet signing keys (.hwsfile files). You can provide multiple signing keys by repeating the --signing-keys option.
            The signed transaction can be saved to a specified output file and optionally submitted to the blockchain.
            """
        )
        
        
        // MARK: - Required Arguments
        
        @Option(name: [.short, .long], help: "The file path to the transaction to submit.")
        var txFile: FilePath?
        
        @Option(name: .long, help: "Raw CBOR hex string of the transaction.")
        var cborHex: String?
        
        @Option(name: [.short, .long], help: "The file paths to the signing keys (repeat option to pass multiple).")
        var signingKeys: [FilePath] = []
        
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
            
            guard !signingKeys.isEmpty else {
                throw ValidationError("At least one signing key is required.")
            }
            
            for key in signingKeys {
                guard FileManager.default.fileExists(atPath: key.string) else {
                    throw ValidationError("Signing key file does not exist at path: \(key.string)")
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
                let skeyFile = try await getSigningKeyFilePath()
                signingKeys.append(skeyFile)
                
                addMore = noora.yesOrNoChoicePrompt(
                    title: "Add Another Signing Key",
                    question: "Add another signing key file?",
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
            if (txFile == nil && cborHex == nil) || signingKeys.isEmpty {
                try await self.wizard()
            }
            
            let config = try await MultitoolConfig.load()
            let context = try await getContext(config: config)
            
            spacedPrint("\nSigning transaction...")
            let tx = try resolveTransaction()
            
            guard let txId = tx.id?.description else {
                noora.error("Failed to compute transaction ID.")
                throw ExitCode.failure
            }
            
            let signingMethods: [SigningMethod] = try signingKeys.map { keyPath in
                if keyPath.extension == "hwsfile" {
                    return .hardwareWallet(keyPath)
                } else if keyPath.extension == "skey" {
                    return .softwareKey(keyPath)
                } else {
                    noora.error("Unsupported signing key file format: \(keyPath.string)")
                    throw ExitCode.validationFailure
                }
            }
            
            noora.info(.alert(
                "Sign (Witness+Assemble) the unsigned transaction \(.primary("\(txId)")) with:",
                takeaways: try signingMethods.map {
                    switch $0 {
                        case .hardwareWallet(let hwsfile):
                            return "  - Hardware Wallet signing key: \(.path(try AbsolutePath(validating: hwsfile.string)))"
                        case .softwareKey(let skey):
                            return "  - Software signing key: \(.path(try AbsolutePath(validating: skey.string)))"
                    }
                }
            ))
            
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let witnessFiles = signingMethods.map { method -> FilePath in
                switch method {
                    case .hardwareWallet(let filePath), .softwareKey(let filePath):
                        return cwd.appending("\(filePath.stem!).witness")
                }
            }

            // Resolve effective tx file: write cborHex to a temp file if txFile not provided
            let effectiveTxFile: FilePath
            var tempTxFilePath: String? = nil
            if let file = txFile {
                effectiveTxFile = file
            } else {
                let tempFilePath = FilePath(FileManager.default.temporaryDirectory.path).appending("\(txId).tx")
                try await FileUtils.dumpLockedFile(tempFilePath, data: try tx.toTextEnvelope()!)
                effectiveTxFile = tempFilePath
                tempTxFilePath = tempFilePath.string
            }
            defer {
                if let path = tempTxFilePath {
                    try? FileManager.default.removeItem(atPath: path)
                }
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
            
            // Check if all signingMethods is hardware
            let isAllHardware = signingMethods.allSatisfy {
                if case .hardwareWallet = $0 {
                    return true
                }
                return false
            }
            
            // Check if all signingMethods is software
            let isAllSoftware = signingMethods.allSatisfy {
                if case .softwareKey = $0 {
                    return true
                }
                return false
            }
            
            if isAllHardware {
                noora.info("Autocorrect the TxBody for canonical order: ")
                let hwcli = try await CardanoHWCLI(
                    configuration: Config(cardano: config.cardano),
                    logger: getLogger(config: config)
                )
                
                try await hwcli.autocorrectTxBodyFile(txBodyFile: effectiveTxFile.string)

                try await FileUtils.displayFile(effectiveTxFile)


                _ = try await hwcli.startHardwareWallet()

                _ = try await hwcli.transaction.witness(
                    txFile: effectiveTxFile,
                    hwSigningFiles: signingKeys,
                    outFiles: witnessFiles,
                    changeOutputKeyFiles: signingKeys
                )

                let cli = try await CardanoCLI(
                    configuration: Config(cardano: config.cardano),
                    logger: getLogger(config: config)
                )

                let witnessArgs = witnessFiles.flatMap { ["--witness-file", $0.string] }

                _ = try await cli.transaction.assemble(
                    arguments: [
                        "--tx-body-file", effectiveTxFile.string,
                        "--out-file", outFile.string
                    ] + witnessArgs
                )
                
                print(noora.format("\(.success("✓")) Transaction Assembled ..."))
                
            } else if isAllSoftware {
                if useCardanoCLI {
                    
                    let cli = try await CardanoCLI(
                        configuration: Config(cardano: config.cardano),
                        logger: getLogger(config: config)
                    )
                    
                    let skeyArgs = witnessFiles.flatMap { ["--signing-key-file", $0.string] }

                    _ = try await cli.transaction.sign(
                        arguments: [
                            "--tx-body-file", effectiveTxFile.string,
                            "--out-file", outFile.string
                        ] + skeyArgs
                    )
                } else {
                    let logger = getLogger(config: config)
                    let txBuilder = TxBuilder(context: context, logger: logger)
                    
                    let keys: [SigningKeyType] = try signingMethods.map { method in
                        switch method {
                            case .softwareKey(let skeyPath):
                                return try SigningKeyType.load(from: skeyPath.string)
                            case .hardwareWallet:
                                noora.error("Hardware wallet signing is not supported in software key signing method.")
                                throw ExitCode.validationFailure
                        }
                    }
                    
                    let signedTx = try await txBuilder.transactions.sign(
                        transaction: tx,
                        keys: keys
                    )
                    
                    try await FileUtils.dumpLockedFile(outFile, data: try signedTx.toTextEnvelope()!)
                }
            } else {
                noora.error(.alert(
                    "This combination is not allowed!",
                    takeaways: [
                        "Either use software keys (.skey files) for both stake and fee payment,",
                        "or use a hardware wallet for the stake key and a software key for the fee payment."
                    ]
                ))
                throw ExitCode.validationFailure
            }
            
            spacedPrint("\n\(.success("✓")) Transaction signed successfully.")
            
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
                try FileManager.default.removeItem(atPath: outFile.string)
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
        }
    }
}
