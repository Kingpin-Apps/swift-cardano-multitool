import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftCardanoChain
import SwiftCardanoTxBuilder


extension CertificateMainCommand {
    struct StakePoolDeregistrationCertificate: CertificateCommandable {
        static let configuration = CommandConfiguration(
            commandName: "pool-deregistration",
            abstract: "Generates a stake pool deregistration certificate.",
            usage: """
            scm certificate pool-deregistration --pool-name test
            """,
            discussion: """
            This command generates a stake pool deregistration certificate based 
            on the information provided in a pool JSON file. You can specify the 
            pool using either the pool name (which will look for a file named 
            <poolName>.pool.json in the current working directory) or by 
            providing the path to the pool JSON file directly. The command will 
            validate the pool information, generate the deregistration 
            certificate, and optionally build a transaction for submitting the 
            deregistration to the blockchain. If the transaction generation 
            option is selected, it will create a raw transaction file that 
            includes the deregistration certificate and can be signed and 
            submitted to the network.
            """,
            aliases: ["pool-dereg"]
        )
        
        @Option(name: .shortAndLong, help: "The name of the pool. Will look for a file named <poolName>.pool.json in current working directory.")
        var poolName: String? = nil

        @Option(name: [.customShort("j"), .long], help: "The path to the pool.json file.")
        var poolJSON: FilePath? = nil

        @Option(name: [.customShort("e"), .long], help: "The epoch to deregister the stake pool in.")
        var epoch: EpochNumber? = nil
        
        // MARK: - CertificateCommandable Arguments
        
        @OptionGroup var certificateOptions: SharedCertificateOptions
        
        // MARK: - TransactionCommandable Arguments
        
        @OptionGroup var transactionOptions: SharedTransactionOptions
        
        // MARK: - Input Enums
        
        enum SelectOption: String, CaseIterable, AlignedChoiceDescribable {
            case poolName
            case poolJSON

            var name: String {
                switch self {
                    case .poolName: return "Pool Name"
                    case .poolJSON: return "Pool JSON"
                }
            }

            var details: String {
                switch self {
                    case .poolName: return "Use the pool name to find pool.json in the current directory."
                    case .poolJSON: return "Use a pool.json file path."
                }
            }
        }
        
        // MARK: - Validation
        
        mutating func validate() throws {
            try self.validateForTransaction()
        }
        
        // MARK: - Wizard
        
        /// Interactive wizard to gather missing parameters
        mutating func wizard() async throws {
            let selectedOption: SelectOption = noora.singleChoicePrompt(
                title: "Select Input Method",
                question: "How would you like to identify the stake pool?",
                description: """
                Please select one of the following options:
                1. Pool Name: Provide the name of the pool to search for the pool.json file.
                2. Pool JSON: Provide the path to the pool.json file.
                """
            )
            
            switch selectedOption {
                case .poolName:
                    poolName = noora.textPrompt(
                        title: "Pool Name",
                        prompt: "Enter the name of the pool:",
                        description: "Searches for <poolName>.pool.json in the current directory.",
                        collapseOnAnswer: true,
                        validationRules: [NonEmptyValidationRule(error: "Pool name cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    let cwd = FilePath(FileManager.default.currentDirectoryPath)
                    poolJSON = cwd.appending("\(poolName!).pool.json")
                    
                case .poolJSON:
                    poolJSON = try await getPoolJSON()
                    poolName = poolJSON?.stem!.replacingOccurrences(
                        of: ".pool",
                        with: ""
                    )
            }
            
            epoch = EpochNumber(noora.textPrompt(
                title: "Deregistration Epoch",
                prompt: "Enter the epoch number to deregister the stake pool in (optional, defaults to current epoch):",
                description: "The epoch number when the deregistration should take effect. If left blank, it will default to the current epoch.",
                collapseOnAnswer: true,
                validationRules: [IntegerValidationRule(error: "Please enter a valid epoch number or leave blank for current epoch.")]
            ))
            
            try self.validate()
        }
        
        // MARK: - Run
        
        mutating func run() async throws {
            // Run wizard if no input method was provided
            if poolName == nil && poolJSON == nil {
                try await wizard()
            }

            guard let poolJSON = poolJSON else {
                noora.error("Pool JSON file path is required.")
                throw ExitCode.validationFailure
            }

            guard let poolName = poolName else {
                noora.error("Pool name is required.")
                throw ExitCode.validationFailure
            }

            let config = try await MultitoolConfig.load()
            let cardanoConfig = try getCardanoConfig(config: config)
            try await resolveAdaHandles(network: cardanoConfig.network)
            let context = try await getContext(config: config)
            try await printContextInfo(config: config, context: context)

            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let timestamp = DateUtils.getCurrentTimestamp()

            do {
                try FileUtils.checkFileExists(poolJSON)
            } catch {
                noora.warning("Pool JSON file not found at path: \(poolJSON)")

                let generateNew = noora.yesOrNoChoicePrompt(
                    title: "Create New Pool JSON",
                    question: "Would you like to create a new pool JSON file named \(poolName).pool.json in the current directory?",
                    defaultAnswer: true,
                    description: "Proceeding with the certificate generation requires a pool JSON file. You can generate a new one now, or use the command \(.command("scm generate pool-json")) to create one and then come back to this command to generate the certificate.",
                )

                if generateNew {
                    await GenerateMainCommand.PoolJSON.main([
                        "--pool-name", poolName
                    ])
                }

                throw ExitCode.validationFailure
            }

            var pool = try Pool.load(from: poolJSON)

            let protocolParamsFile = cwd.appending(
                "protocol-parameters.json"
            )

            let protocolParams = try await getProtocolParameters(
                context: context,
                protocolParamsFile: protocolParamsFile
            )

            let poolRetireMaxEpoch = protocolParams.poolRetireMaxEpoch

            // Fetch current epoch
            let currentEpoch = try await context.epoch()
            let minRetireEpoch = currentEpoch + 1
            let maxRetireEpoch = currentEpoch + Int(poolRetireMaxEpoch)

            spacedPrint("""
            \n\(.primary("━━━ Epoch Info ━━━"))
              Current Epoch:   \(.primary("\(currentEpoch)"))
              Earliest Retire: \(.primary("Epoch \(minRetireEpoch)"))
              Latest Retire:   \(.primary("Epoch \(maxRetireEpoch)"))
            """)

            // Resolve or prompt for retirement epoch
            let retireEpoch: Int
            if let providedEpoch = epoch {
                retireEpoch = Int(providedEpoch)
            } else {
                retireEpoch = Int(noora.textPrompt(
                    title: "Deregistration Epoch",
                    prompt: "Enter the epoch to retire the pool in [\(minRetireEpoch)-\(maxRetireEpoch)]:",
                    description: "Must be between current epoch + 1 (\(minRetireEpoch)) and current epoch + poolRetireMaxEpoch (\(maxRetireEpoch)).",
                    defaultValue: "\(minRetireEpoch)",
                    collapseOnAnswer: true,
                    validationRules: [IntegerValidationRule(
                        min: minRetireEpoch,
                        max: maxRetireEpoch,
                        error: "Please enter a valid epoch number.")
                    ]
                )) ?? minRetireEpoch
            }

            guard retireEpoch >= minRetireEpoch && retireEpoch <= maxRetireEpoch else {
                noora.error(.alert(
                    "Retirement epoch \(retireEpoch) is outside the valid range.",
                    takeaways: [
                        "Must be between \(minRetireEpoch) and \(maxRetireEpoch).",
                        "Current epoch is \(currentEpoch), poolRetireMaxEpoch is \(poolRetireMaxEpoch)."
                    ]
                ))
                throw ExitCode.validationFailure
            }

            // Validate cold verification key
            guard let coldVkeyPath = pool.coldVkey else {
                noora.error(.alert(
                    "Cold verification key file not found in pool JSON.",
                    takeaways: ["Ensure \(poolName).node.vkey exists and is referenced in the pool JSON."]
                ))
                throw ExitCode.validationFailure
            }

            do {
                try FileUtils.checkFileExists(coldVkeyPath)
            } catch {
                noora.error(.alert(
                    "Cold verification key file not found: \(coldVkeyPath.string)",
                    takeaways: ["Ensure the file exists or run 'scm generate node-cold-keys' first."]
                ))
                throw ExitCode.validationFailure
            }

            // Generate Pool ID from cold vkey
            let stakePoolVKey = try StakePoolVerificationKey.load(from: coldVkeyPath.string)
            let poolKeyHash = try stakePoolVKey.poolKeyHash()
            let poolOperator = PoolOperator(poolKeyHash: poolKeyHash)
            let poolIdBech = try poolOperator.toBech32()

            spacedPrint("""
            \n\(.primary("━━━ Pool Deregistration Summary ━━━"))
              Pool Name:       \(.primary(poolName))
              Pool ID:         \(.primary(poolIdBech))
              Retire Epoch:    \(.primary("\(retireEpoch)"))
            """)

            // Determine output certificate file path
            if certificateOptions.outFile == nil {
                certificateOptions.outFile = cwd.appending("\(poolName)-\(timestamp).pool-dereg.cert")
            }

            guard let outFile = certificateOptions.outFile else {
                noora.error("Output file path is invalid.")
                throw ExitCode.validationFailure
            }

            do {
                try await FileUtils.checkFile(outFile)
            } catch {
                throw ExitCode.validationFailure
            }

            // Generate the deregistration certificate
            do {
                if transactionOptions.useCardanoCLI {
                    let logger = getLogger(config: config)
                    let cli = try await CardanoCLI(
                        configuration: config.toSwiftCardanoUtilsConfig(),
                        logger: logger
                    )
                    _ = try await cli.stakePool.deregistrationCertificate(arguments: [
                        "--cold-verification-key-file", coldVkeyPath.string,
                        "--epoch", "\(retireEpoch)",
                        "--out-file", outFile.string
                    ])
                } else {
                    let deregCert = SwiftCardanoCore.PoolRetirement(
                        poolKeyHash: poolKeyHash,
                        epoch: EpochNumber(retireEpoch)
                    )
                    try deregCert.save(to: outFile.string)
                }
            } catch {
                noora.error(.alert(
                    "Could not generate the pool deregistration certificate!",
                    takeaways: ["\(error)"]
                ))
                throw ExitCode.failure
            }

            // Update pool.json with deregistration info
            pool.deregistration = PoolDeregistration(
                certCreated: Date(),
                certificate: outFile,
                epoch: retireEpoch
            )
            try pool.save(to: poolJSON, overwrite: true)

            noora.success(.alert(
                "Pool deregistration certificate created successfully.",
                takeaways: [
                    "Certificate: \(outFile.string)",
                    "Pool ID (bech32): \(poolIdBech)",
                    "Pool will be retired at the start of epoch \(retireEpoch).",
                    "Include this certificate when building your pool deregistration transaction."
                ]
            ))

            try await FileUtils.displayFile(outFile)

            if certificateOptions.generateTransaction {
                let logger = getLogger(config: config)
                let txBuilder = TxBuilder(context: context, logger: logger)

                let poolRetirementCert = try SwiftCardanoCore.PoolRetirement.load(from: outFile.string)
                txBuilder.certificates = [.poolRetirement(poolRetirementCert)]

                // Witnesses: cold skey + fee payment skey
                let witnessCount = 2
                txBuilder.witnessOverride = witnessCount

                guard let feePaymentAddress = transactionOptions.feePaymentAddress else {
                    noora.error(.alert(
                        "Fee payment address is required to generate the transaction.",
                        takeaways: ["Provide a valid fee payment address."]
                    ))
                    throw ExitCode.validationFailure
                }

                var signingKeys: [String] = [
                    try feePaymentAddress.info.getSigningMethod().path.string
                ]

                // Pool cold signing key
                if let coldSkeyPath = pool.coldSkey {
                    do {
                        try FileUtils.checkFileExists(coldSkeyPath)
                        signingKeys += [coldSkeyPath.string]
                    } catch {
                        noora.error(.alert(
                            "Cold signing key not found: \(coldSkeyPath.string)",
                            takeaways: ["Ensure the file exists or run 'scm generate node-cold-keys' first."]
                        ))
                        throw ExitCode.validationFailure
                    }
                } else {
                    noora.error(.alert(
                        "Cold signing key path is not set in the pool JSON.",
                        takeaways: ["Ensure the pool JSON contains a valid cold_skey path."]
                    ))
                    throw ExitCode.validationFailure
                }

                spacedPrint(
                    "\nSubmit Pool Deregistration Certificate \(.primary("\(outFile.string)")) with funds from Address \(.primary("\(feePaymentAddress.info.name!)"))"
                )

                spacedPrint(
                    "Witnesses needed: \(.primary("\(witnessCount)")) (pool cold key + payment key)"
                )

                // Transaction file paths
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
                if transactionOptions.useCardanoCLI {
                    args.append("--use-cardano-cli")
                }
                if transactionOptions.save {
                    args.append("--save")
                }
                if transactionOptions.submit {
                    args.append("--submit")
                }

                let signingKeysArgs: [String] = signingKeys.flatMap {
                    ["--signing-key-file", $0]
                }

                await TransactionMainCommand.Sign.main([
                    "--tx-file", txFile.string,
                    "--out-file", txSignedFile.string,
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
