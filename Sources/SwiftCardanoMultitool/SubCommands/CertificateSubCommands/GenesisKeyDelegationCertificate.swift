import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftCardanoChain
import SwiftCardanoTxBuilder

extension CertificateMainCommand {

    struct GenesisKeyDelegationCertificate: CertificateCommandable {
        static let configuration = CommandConfiguration(
            commandName: "genesis-key-delegation",
            abstract: "Generates a genesis key delegation certificate.",
            usage: """
            scm certificate genesis-key-delegation
            """,
            discussion: """
            Creates a genesis key delegation certificate that delegates a genesis
            key to a stake pool for block production. This is a legacy Shelley-era
            certificate. You will need the genesis verification key file, genesis
            delegate verification key file, and VRF verification key file. If the
            `--generate-transaction` flag is used, a transaction will also be
            created to submit the certificate on-chain.
            """,
            aliases: ["gen-deleg"]
        )

        // MARK: - Optional CLI Arguments (native Swift path uses interactive prompts)

        @Option(name: .long, help: "Path to the genesis verification key file.")
        var genesisVerificationKeyFile: String?

        @Option(name: .long, help: "Path to the genesis delegate verification key file.")
        var genesisDelegateVerificationKeyFile: String?

        @Option(name: .long, help: "Path to the VRF verification key file (.vrf.vkey).")
        var vrfVerificationKeyFile: String?

        // MARK: - CertificateCommandable Arguments

        @OptionGroup var certificateOptions: SharedCertificateOptions

        // MARK: - TransactionCommandable Arguments

        @OptionGroup var transactionOptions: SharedTransactionOptions

        // MARK: - Validation

        mutating func validate() throws {
            try self.validateForTransaction()
        }

        // MARK: - Wizard

        mutating func wizard() async throws {
            let cwd = FilePath(FileManager.default.currentDirectoryPath)

            if genesisVerificationKeyFile == nil {
                let files = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                    .filter { $0.hasSuffix(".genesis.vkey") || $0.hasSuffix(".genesis-vkey") }

                if !files.isEmpty {
                    genesisVerificationKeyFile = noora.singleChoicePrompt(
                        title: "Genesis VKey",
                        question: "Select the genesis verification key file:",
                        options: files,
                        description: "Available genesis verification key files in current directory",
                        collapseOnSelection: true,
                        filterMode: .enabled
                    )
                } else {
                    genesisVerificationKeyFile = noora.textPrompt(
                        title: "Genesis VKey",
                        prompt: "Enter the path to the genesis verification key file:",
                        collapseOnAnswer: true,
                        validationRules: [NonEmptyValidationRule(error: "File path cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            if genesisDelegateVerificationKeyFile == nil {
                let files = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                    .filter { $0.hasSuffix(".delegate.vkey") || $0.hasSuffix(".genesis-delegate.vkey") }

                if !files.isEmpty {
                    genesisDelegateVerificationKeyFile = noora.singleChoicePrompt(
                        title: "Genesis Delegate VKey",
                        question: "Select the genesis delegate verification key file:",
                        options: files,
                        description: "Available genesis delegate verification key files",
                        collapseOnSelection: true,
                        filterMode: .enabled
                    )
                } else {
                    genesisDelegateVerificationKeyFile = noora.textPrompt(
                        title: "Genesis Delegate VKey",
                        prompt: "Enter the path to the genesis delegate verification key file:",
                        collapseOnAnswer: true,
                        validationRules: [NonEmptyValidationRule(error: "File path cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            if vrfVerificationKeyFile == nil {
                let files = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                    .filter { $0.hasSuffix(".vrf.vkey") || $0.hasSuffix(".node.vrf.vkey") }

                if !files.isEmpty {
                    vrfVerificationKeyFile = noora.singleChoicePrompt(
                        title: "VRF VKey",
                        question: "Select the VRF verification key file:",
                        options: files,
                        description: "Available VRF verification key files",
                        collapseOnSelection: true,
                        filterMode: .enabled
                    )
                } else {
                    vrfVerificationKeyFile = noora.textPrompt(
                        title: "VRF VKey",
                        prompt: "Enter the path to the VRF verification key file (.vrf.vkey):",
                        collapseOnAnswer: true,
                        validationRules: [NonEmptyValidationRule(error: "File path cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            try await self.wizardForCertificate()
            if certificateOptions.generateTransaction {
                try await self.wizardForTransaction()
            }
            try self.validate()
        }

        // MARK: - Run

        mutating func run() async throws {
            let cwd = FilePath(FileManager.default.currentDirectoryPath)

            if genesisVerificationKeyFile == nil || genesisDelegateVerificationKeyFile == nil || vrfVerificationKeyFile == nil {
                try await wizard()
            }

            guard let genesisVKeyPath = genesisVerificationKeyFile else {
                noora.error(.alert("Genesis verification key file is required.", takeaways: ["Provide the path to a genesis verification key file."]))
                throw ExitCode.validationFailure
            }
            guard let delegateVKeyPath = genesisDelegateVerificationKeyFile else {
                noora.error(.alert("Genesis delegate verification key file is required.", takeaways: ["Provide the path to a genesis delegate verification key file."]))
                throw ExitCode.validationFailure
            }
            guard let vrfVKeyPath = vrfVerificationKeyFile else {
                noora.error(.alert("VRF verification key file is required.", takeaways: ["Provide the path to a VRF verification key file."]))
                throw ExitCode.validationFailure
            }

            // Resolve paths relative to cwd if not absolute
            let genesisVKeyFilePath = genesisVKeyPath.hasPrefix("/") ? genesisVKeyPath : cwd.appending(genesisVKeyPath).string
            let delegateVKeyFilePath = delegateVKeyPath.hasPrefix("/") ? delegateVKeyPath : cwd.appending(delegateVKeyPath).string
            let vrfVKeyFilePath = vrfVKeyPath.hasPrefix("/") ? vrfVKeyPath : cwd.appending(vrfVKeyPath).string

            for (label, path) in [("Genesis vkey", genesisVKeyFilePath), ("Genesis delegate vkey", delegateVKeyFilePath), ("VRF vkey", vrfVKeyFilePath)] {
                guard FileManager.default.fileExists(atPath: path) else {
                    noora.error(.alert("\(label) file not found: \(path)", takeaways: ["Ensure the file exists and is readable."]))
                    throw ExitCode.validationFailure
                }
            }

            let config = try await MultitoolConfig.load()
            let context = try await getContext(config: config)
            try await printContextInfo(config: config, context: context)

            let timestamp = DateUtils.getCurrentTimestamp()
            let stem = FilePath(genesisVKeyFilePath).stem ?? "genesis"

            if certificateOptions.outFile == nil {
                certificateOptions.outFile = cwd.appending("\(stem)-\(timestamp).genesis-deleg.cert")
            }

            guard let outFile = certificateOptions.outFile else {
                noora.error(.alert("Output file path is invalid.", takeaways: ["Provide a valid output file path."]))
                throw ExitCode.validationFailure
            }

            do {
                try await FileUtils.checkFile(outFile)
            } catch {
                noora.error(.alert("Output file already exists: \(outFile.string)", takeaways: ["\(error.localizedDescription)"]))
                throw ExitCode.validationFailure
            }

            print(noora.format("\nGenerating genesis key delegation certificate"))
            print(noora.format("  Genesis VKey:   \(.path(try .init(validating: genesisVKeyFilePath)))"))
            print(noora.format("  Delegate VKey:  \(.path(try .init(validating: delegateVKeyFilePath)))"))
            print(noora.format("  VRF VKey:       \(.path(try .init(validating: vrfVKeyFilePath)))"))

            do {
                if transactionOptions.useCardanoCLI {
                    let logger = getLogger(config: config)
                    let cli = try await CardanoCLI(configuration: config.toSwiftCardanoUtilsConfig(), logger: logger)

                    let arguments = [
                        "create-genesis-key-delegation-certificate",
                        "--genesis-verification-key-file", genesisVKeyFilePath,
                        "--genesis-delegate-verification-key-file", delegateVKeyFilePath,
                        "--vrf-verification-key-file", vrfVKeyFilePath,
                        "--out-file", outFile.string
                    ]

                    try await FileUtils.unlockIfExists(outFile)
                    _ = try await cli.legacy.governance(arguments: arguments)
                    try await FileUtils.fileLock(outFile)
                } else {
                    // Native Swift: compute hashes from key files
                    // Genesis keys use the raw payload hash (blake2b-256 of the key bytes)
                    let genesisVKeyData = try Data(contentsOf: URL(fileURLWithPath: genesisVKeyFilePath))
                    let delegateVKeyData = try Data(contentsOf: URL(fileURLWithPath: delegateVKeyFilePath))

                    let vrfVKey = try VRFVerificationKey.load(from: vrfVKeyFilePath)
                    let vrfKeyHash = try vrfVKey.hash()

                    // For genesis/delegate, we read their hashes from the cardano-cli text envelope
                    // and use them directly as the payload bytes.
                    // Use hex-encoded payload from the JSON envelope.
                    guard let genesisJson = try? JSONSerialization.jsonObject(with: genesisVKeyData) as? [String: Any],
                          let genesisPayloadHex = genesisJson["cborHex"] as? String else {
                        noora.error(.alert(
                            "Failed to read genesis verification key from \(genesisVKeyFilePath).",
                            takeaways: ["Ensure the file is a valid cardano-cli text envelope."]
                        ))
                        throw ExitCode.failure
                    }
                    guard let delegateJson = try? JSONSerialization.jsonObject(with: delegateVKeyData) as? [String: Any],
                          let delegatePayloadHex = delegateJson["cborHex"] as? String else {
                        noora.error(.alert(
                            "Failed to read genesis delegate verification key from \(delegateVKeyFilePath).",
                            takeaways: ["Ensure the file is a valid cardano-cli text envelope."]
                        ))
                        throw ExitCode.failure
                    }

                    // Strip the CBOR header (first 4 bytes = 2 hex chars prefix "5820")
                    let genesisRawHex = genesisPayloadHex.hasPrefix("5820") ? String(genesisPayloadHex.dropFirst(4)) : genesisPayloadHex
                    let delegateRawHex = delegatePayloadHex.hasPrefix("5820") ? String(delegatePayloadHex.dropFirst(4)) : delegatePayloadHex

                    let genesisHash = GenesisHash(payload: genesisRawHex.hexStringToData)
                    let genesisDelegateHash = GenesisDelegateHash(payload: delegateRawHex.hexStringToData)

                    let cert = SwiftCardanoCore.GenesisKeyDelegation(
                        genesisHash: genesisHash,
                        genesisDelegateHash: genesisDelegateHash,
                        vrfKeyHash: vrfKeyHash
                    )
                    try cert.save(to: outFile.string, overwrite: true)
                }
            } catch {
                noora.error(.alert(
                    "Could not write certificate file \(.primary(outFile.string))!",
                    takeaways: ["\(error)"]
                ))
                throw ExitCode.failure
            }

            noora.success(.alert(
                "Genesis Key Delegation certificate created successfully.",
                takeaways: [
                    "File: \(outFile.string)",
                    "Include this certificate when building your transaction."
                ]
            ))

            try await FileUtils.displayFile(outFile)

            if certificateOptions.generateTransaction {
                let logger = getLogger(config: config)
                let txBuilder = TxBuilder(context: context, logger: logger)

                let loadedCert = try SwiftCardanoCore.GenesisKeyDelegation.load(from: outFile.string)
                txBuilder.certificates = [.genesisKeyDelegation(loadedCert)]

                guard let feePaymentAddress = transactionOptions.feePaymentAddress else {
                    noora.error(.alert("Fee payment address is required.", takeaways: ["Provide a valid fee payment address."]))
                    throw ExitCode.validationFailure
                }

                let signingKeys: [String] = [
                    try feePaymentAddress.info.getSigningMethod().path.string
                ]

                let protocolParamsFile = cwd.appending("protocol-parameters.json")
                _ = try await getProtocolParameters(context: context, protocolParamsFile: protocolParamsFile)

                let txTimestamp = DateUtils.getCurrentTimestamp()
                let txRawFile = cwd.appending("\(feePaymentAddress.info.name!)-\(txTimestamp).raw.tx")
                let txFile = cwd.appending("\(feePaymentAddress.info.name!)-\(txTimestamp).tx")
                let txSignedFile = cwd.appending("\(feePaymentAddress.info.name!)-\(txTimestamp).signed.tx")

                try await buildTransaction(
                    txBuilder: txBuilder,
                    config: config,
                    witnessOverride: signingKeys.count,
                    protocolParamsFile: protocolParamsFile,
                    txRawFile: txRawFile,
                    txFile: txFile,
                    txSignedFile: txSignedFile
                )

                var args: [String] = []
                if transactionOptions.useCardanoCLI { args.append("--use-cardano-cli") }
                if transactionOptions.save { args.append("--save") }
                if transactionOptions.submit { args.append("--submit") }

                let signingKeysArgs = signingKeys.flatMap { ["--signing-key-file", $0] }
                await TransactionMainCommand.Sign.main([
                    "--tx-file", txFile.string,
                    "--out-file", txSignedFile.string
                ] + args + signingKeysArgs)

                if !transactionOptions.save {
                    try FileManager.default.removeItem(atPath: txRawFile.string)
                    try FileManager.default.removeItem(atPath: txFile.string)
                    try FileManager.default.removeItem(atPath: txSignedFile.string)
                }
            }
        }
    }
}
