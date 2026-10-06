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
    struct Witness: TransactionAsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Witness a transaction.",
            usage: """
            scm transaction witness \\
                --tx-file test.tx \\
                --signing-keys test.payment.skey \\
                --signing-keys test.stake.skey \\
                --out-file test.payment.witness \\
                --out-file test.stake.witness
            """,
            discussion: """
            Creates one witness file per signing key. The transaction can be
            provided as a file or as a raw CBOR hex string. Each witness is saved
            to the matching --out-file (given in the same order as
            --signing-keys), or to <transaction-name>.<key-role>.witness in the
            current directory (e.g. qwe1.unwitnessed.tx and qwe1.node.skey give
            qwe1.node.witness). Combine the witnesses with `scm transaction assemble`, or
            pass --submit to assemble and submit straight away.
            """
        )
        
        
        // MARK: - Required Arguments
        
        @Option(name: [.short, .long], help: "The file path to the transaction to submit.")
        var txFile: FilePath?
        
        @Option(name: .long, help: "Raw CBOR hex string of the transaction.")
        var cborHex: String?
        
        @Option(name: [.short, .long], help: "The file paths to the signing keys (repeat option to pass multiple).")
        var signingKeys: [FilePath] = []
        
        @Option(name: [.short, .long], help: "Witness file to write, one per signing key in the same order (repeat option to pass multiple). Defaults to '<transaction-name>.<key-role>.witness' in the current directory, e.g. qwe1.node.witness.")
        var outFile: [FilePath] = []
        
        @Flag(help: "Use cardano-cli to witness the transaction (default: use SwiftCardano)")
        var useCardanoCLI = false
        
        @Flag(inversion: .prefixedNo, help: "Save the witness files (with --no-save they are printed instead)")
        var save = true
        
        @Flag(help: "Assemble the transaction with the witnesses and submit it to the blockchain")
        var submit = false

        /// A path relative to the current directory when it is inside it, for shorter output.
        static func displayPath(_ path: FilePath, cwd: FilePath) -> String {
            let prefix = cwd.string.hasSuffix("/") ? cwd.string : cwd.string + "/"
            return path.string.hasPrefix(prefix) ? String(path.string.dropFirst(prefix.count)) : path.string
        }

        // MARK: - Validation

        mutating func validate() throws {
            guard outFile.isEmpty || outFile.count == signingKeys.count else {
                throw ValidationError("Pass one --out-file per --signing-keys (got \(outFile.count) for \(signingKeys.count) keys), or none to use the default names.")
            }
        }

        /// The witness file for each signing key: the matching --out-file, else
        /// `<transaction-name>.<key-role>.witness` in the current directory, e.g.
        /// `qwe1.unwitnessed.tx` + `qwe1.node.skey` → `qwe1.node.witness`. Keys sharing a
        /// role (two payment keys) fall back to their full name: `qwe1.alice.payment.witness`.
        static func witnessFiles(for signingKeys: [FilePath], outFiles: [FilePath], transactionName: String, cwd: FilePath) -> [FilePath] {
            let roles = signingKeys.map(signingKeyRole)
            return signingKeys.enumerated().map { index, key in
                if outFiles.indices.contains(index) {
                    let out = outFiles[index]
                    return out.isAbsolute ? out : cwd.pushing(out)
                }
                let role = roles.filter { $0 == roles[index] }.count > 1 ? (key.stem ?? roles[index]) : roles[index]
                return cwd.appending("\(transactionName).\(role).witness")
            }
        }

        /// The name witness files are based on: the transaction file's name, or the
        /// transaction ID for CBOR hex input.
        func transactionName() throws -> String {
            if let txFile { return transactionBaseName(txFile) }
            return try resolveTransaction().id?.description ?? "transaction"
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
            
            useCardanoCLI = noora.yesOrNoChoicePrompt(
                title: "Witness Method",
                question: "Use cardano-cli to witness the transaction?",
                defaultAnswer: false,
                description: "Default: SwiftCardano. Alternative: cardano-cli"
            )
            
            save = noora.yesOrNoChoicePrompt(
                title: "Save Witness",
                question: "Save the witness files?",
                defaultAnswer: true,
                description: "Choose no to print the witnesses instead."
            )

            if save {
                // One witness file per signing key; Enter keeps the default name.
                let cwd = FilePath(FileManager.default.currentDirectoryPath)
                let defaults = Self.witnessFiles(for: signingKeys, outFiles: [], transactionName: try transactionName(), cwd: cwd)
                outFile = try zip(signingKeys, defaults).map { key, defaultFile in
                    let defaultName = defaultFile.lastComponent?.string ?? defaultFile.string
                    return try filePathPrompt(
                        title: "Witness File",
                        question: "Where should the witness for \(key.lastComponent?.string ?? key.string) be saved?",
                        description: "A new file, or an existing one to overwrite.",
                        fileMatches: { $0.hasSuffix(".witness") },
                        defaultValue: defaultName,
                        mustExist: false
                    )
                }
            }
            
            submit = noora.yesOrNoChoicePrompt(
                title: "Submit Transaction",
                question: "Assemble the transaction with the witnesses and submit it?",
                defaultAnswer: false,
                description: "Only when these witnesses are all the transaction needs. Requires network connectivity."
            )

            try validate()
        }
        
        // MARK: - Run
        
        mutating func run() async throws {
            if (txFile == nil && cborHex == nil) || signingKeys.isEmpty , isInteractiveSession() {
                try await self.wizard()
            }
            
            guard !signingKeys.isEmpty else {
                noora.error(.alert(
                    "At least one signing key is required.",
                    takeaways: ["Provide at least one signing key."]
                ))
                throw ExitCode.validationFailure
            }
            
            for key in signingKeys {
                guard FileManager.default.fileExists(atPath: key.string) else {
                    noora.error(.alert(
                        "Signing key file does not exist at path: \(key.string)",
                        takeaways: ["Check the file path and try again."]
                    ))
                    throw ExitCode.validationFailure
                }
            }
            
            let config = try await MultitoolConfig.load()
            let context = try await getContext(config: config)
            let logger = getLogger(config: config)
            
            spacedPrint("\nWitnessing transaction...")
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
                "Witness the unsigned transaction \(.primary("\(txId)")) with:",
                takeaways: signingMethods.map {
                    switch $0 {
                        case .hardwareWallet(let hwsfile):
                            return "  - Hardware Wallet signing key: \(hwsfile.string)"
                        case .softwareKey(let skey):
                            return "  - Software signing key: \(skey.string)"
                    }
                }
            ))
            
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            // Submitting needs the witness files, so without --save they go to a temporary folder.
            let writesWitnessFiles = save || submit
            let witnessDirectory = save
                ? cwd
                : FilePath(FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path)
            if !save && submit {
                try FileManager.default.createDirectory(atPath: witnessDirectory.string, withIntermediateDirectories: true)
            }
            defer {
                if !save && submit { try? FileManager.default.removeItem(atPath: witnessDirectory.string) }
            }
            let witnessFiles = Self.witnessFiles(
                for: signingKeys,
                outFiles: save ? outFile : [],
                transactionName: try transactionName(),
                cwd: witnessDirectory
            )

            // Two keys with the same name would write to the same default witness file.
            guard Set(witnessFiles.map(\.string)).count == witnessFiles.count else {
                noora.error(.alert(
                    "Several signing keys would write to the same witness file.",
                    takeaways: ["Pass one --out-file per signing key to name them."]
                ))
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
                    logger: logger
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
                
            } else if isAllSoftware {
                if useCardanoCLI {
                    
                    let cli = try await CardanoCLI(
                        configuration: Config(cardano: config.cardano),
                        logger: logger
                    )
                    
                    for (signingKey, witnessFile) in zip(signingKeys, witnessFiles) {
                        
                        // Absolutize input/output paths — cardano-cli does not resolve
                        // relative paths against the user's cwd.
                        let resolvedTxFile = try await effectiveTxFile
                        let txBodyArg = FileUtils.absolutePath(resolvedTxFile).string
                        let signingKeyArg = FileUtils.absolutePath(signingKey).string
                        if writesWitnessFiles {
                            try await FileUtils.unlockIfExists(witnessFile)
                            _ = try await cli.transaction.witness(
                                arguments: [
                                    "--tx-body-file", txBodyArg,
                                    "--signing-key-file", signingKeyArg,
                                    "--out-file", FileUtils.absolutePath(witnessFile).string
                                ]
                            )
                            try await FileUtils.fileLock(witnessFile)
                        } else {
                            let witness = try await cli.transaction.witness(
                                arguments: [
                                    "--tx-body-file", txBodyArg,
                                    "--signing-key-file", signingKeyArg,
                                    "--out-file", "/dev/stdout"
                                ]
                            )
                            print(witness)
                        }
                    }
                    
                }
                else {
                    let txBuilder = TxBuilder(context: context, logger: logger)
                    
                    for (method, witnessFile) in zip(signingMethods, witnessFiles) {
                        let skeyType: SigningKeyType
                        
                        switch method {
                            case .softwareKey(let skeyPath):
                                skeyType = try SigningKeyType.load(from: skeyPath.string)
                            case .hardwareWallet:
                                noora.error("Hardware wallet signing is not supported in software key signing method.")
                                throw ExitCode.validationFailure
                        }
                        
                        let witness = try txBuilder.transactions.witness(
                            transaction: tx,
                            keys: [skeyType]
                        )
                        
                        if writesWitnessFiles {
                            try await FileUtils.dumpLockedFile(
                                witnessFile,
                                data: try witness[0].toTextEnvelope()!
                            )
                        } else {
                            print(witness[0])
                        }
                    }
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
            
            spacedPrint("\n\(.success("✓")) Transaction witnessed successfully.")

            if save {
                noora.success(.alert(
                    "Witness files saved.",
                    takeaways: witnessFiles.map { "\(Self.displayPath($0, cwd: cwd))" }
                ))
            }

            if submit {
                let witnessArgs = witnessFiles.flatMap { ["--witness-file", $0.string] }
                await TransactionMainCommand.Assemble.main([
                    "--tx-file", try await effectiveTxFile.string,
                    "--submit"
                ] + (useCardanoCLI ? ["--use-cardano-cli"] : []) + witnessArgs)
            } else if save {
                let witnessArgs = witnessFiles.map { "--witness-file \(Self.displayPath($0, cwd: cwd))" }.joined(separator: " ")
                noora.info(.alert(
                    "Transaction not submitted.",
                    takeaways: ["Assemble and submit it later with: scm transaction assemble --tx-file \(txFile?.string ?? "<tx file>") \(witnessArgs) --submit"]
                ))
            }
        }
    }
}
