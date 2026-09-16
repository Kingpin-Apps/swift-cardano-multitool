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
            scm certificate pool-deregistration --pool-operator pool1... --cold-signing-key test.node.skey --generate-transaction --fee-payment-address wallet
            """,
            discussion: """
            This command generates a stake pool deregistration certificate. You 
            can specify the pool using the pool name (which will look for a file 
            named <poolName>.pool.json in the current working directory), the 
            path to the pool JSON file, or without a pool JSON file by giving the 
            pool operator (pool ID in bech32 or hex, a .pool.id file, or a 
            .node.vkey file) together with the pool cold signing key when a 
            transaction is generated. The command will 
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

        @Option(name: .long, help: "The pool operator to retire, without a pool.json. Supports: pool ID (pool1... or hex), cold verification key (pool_vk1... or hex), .pool.id file, or cold .vkey file.")
        var poolOperator: PoolOperator? = nil

        @Option(name: .long, help: "Path to the pool cold signing key (.node.skey). Required to sign the transaction when not using a pool.json.")
        var coldSigningKey: FilePath? = nil

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
            case poolOperator

            var name: String {
                switch self {
                    case .poolName: return "Pool Name"
                    case .poolJSON: return "Pool JSON"
                    case .poolOperator: return "Pool Operator"
                }
            }

            var details: String {
                switch self {
                    case .poolName: return "Use the pool name to find pool.json in the current directory."
                    case .poolJSON: return "Use a pool.json file path."
                    case .poolOperator: return "Use the pool ID (bech32 or hex), a .pool.id file, or a .node.vkey file. No pool.json needed."
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
                3. Pool Operator: Provide the pool ID or cold verification key, without a pool.json file.
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

                case .poolOperator:
                    poolOperator = try await getPoolOperator(title: "Pool Operator to Retire")
            }

            // The retirement epoch is prompted in run(), once the valid range is known.

            try await self.wizardForCertificate()
            if certificateOptions.generateTransaction {
                if poolOperator != nil && coldSigningKey == nil {
                    coldSigningKey = try promptColdSigningKey()
                }
                try await self.wizardForTransaction()
            }

            try self.validate()
        }

        /// Prompt for the pool cold signing key, offering the .node.skey files in the current directory.
        private func promptColdSigningKey() throws -> FilePath {
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let skeyFiles = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                .filter { $0.hasSuffix(".node.skey") }
                .sorted()

            if skeyFiles.isEmpty {
                return FilePath(noora.textPrompt(
                    title: "Pool Cold Signing Key",
                    prompt: "Enter the path to the pool cold signing key (.node.skey):",
                    description: "No .node.skey files were found in the current directory. The cold key must witness the retirement transaction.",
                    collapseOnAnswer: true,
                    validationRules: [NonEmptyValidationRule(error: "Cold signing key path cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines))
            }

            return cwd.appending(noora.singleChoicePrompt(
                title: "Pool Cold Signing Key",
                question: "Select the pool cold signing key:",
                options: skeyFiles,
                description: "The cold key must witness the retirement transaction."
            ))
        }
        
        // MARK: - Run
        
        mutating func run() async throws {
            // Run wizard if no input method was provided
            if poolName == nil && poolJSON == nil && poolOperator == nil , isInteractiveSession() {
                try await wizard()
            }

            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let timestamp = DateUtils.getCurrentTimestamp()

            // A pool operator identifies the pool without a pool.json. Otherwise
            // resolve the pool.json from --pool-json or <poolName>.pool.json.
            if poolOperator == nil {
                if poolJSON == nil, let poolName {
                    poolJSON = cwd.appending("\(poolName).pool.json")
                }
                if poolName == nil, let poolJSON {
                    poolName = poolJSON.stem?.replacingOccurrences(of: ".pool", with: "")
                }
                guard poolJSON != nil, poolName != nil else {
                    noora.error(.alert(
                        "A pool is required.",
                        takeaways: ["Provide --pool-name, --pool-json, or --pool-operator."]
                    ))
                    throw ExitCode.validationFailure
                }
            }

            let config = try await MultitoolConfig.load()
            let cardanoConfig = try getCardanoConfig(config: config)
            try await resolveAdaHandles(network: cardanoConfig.network)
            let context = try await getContext(config: config)
            try await printContextInfo(config: config, context: context)

            var pool: Pool? = nil
            if poolOperator == nil, let poolJSON, let poolName {
                do {
                    try FileUtils.checkFileExists(poolJSON)
                } catch {
                    noora.warning(.alert(
                        "Pool JSON file not found at path: \(poolJSON)",
                        takeaway: "You can retire the pool without a pool.json by passing --pool-operator (and --cold-signing-key to sign)."
                    ))

                    let generateNew = isInteractiveSession() && noora.yesOrNoChoicePrompt(
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

                pool = try Pool.load(from: poolJSON)
            }

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

            // Resolve the pool key hash, from the pool operator or the pool JSON's cold vkey
            let poolKeyHash: PoolKeyHash
            var coldVkeyPath: FilePath? = nil
            if let poolOperator {
                poolKeyHash = poolOperator.poolKeyHash
            } else {
                guard let pool, let vkeyPath = pool.coldVkey else {
                    noora.error(.alert(
                        "Cold verification key file not found in pool JSON.",
                        takeaways: ["Ensure \(poolName ?? "<poolName>").node.vkey exists and is referenced in the pool JSON."]
                    ))
                    throw ExitCode.validationFailure
                }

                do {
                    try FileUtils.checkFileExists(vkeyPath)
                } catch {
                    noora.error(.alert(
                        "Cold verification key file not found: \(vkeyPath.string)",
                        takeaways: ["Ensure the file exists or run 'scm generate node-cold-keys' first."]
                    ))
                    throw ExitCode.validationFailure
                }

                // Generate Pool ID from cold vkey
                let stakePoolVKey = try StakePoolVerificationKey.load(from: vkeyPath.string)
                poolKeyHash = try stakePoolVKey.poolKeyHash()
                coldVkeyPath = vkeyPath
            }
            let poolIdBech = try PoolOperator(poolKeyHash: poolKeyHash).toBech32()
            let poolLabel = poolName ?? poolIdBech

            spacedPrint("""
            \n\(.primary("━━━ Pool Deregistration Summary ━━━"))
              Pool Name:       \(.primary(poolName ?? "-"))
              Pool ID:         \(.primary(poolIdBech))
              Retire Epoch:    \(.primary("\(retireEpoch)"))
            """)

            // Determine output certificate file path
            if certificateOptions.outFile == nil {
                certificateOptions.outFile = cwd.appending("\(poolLabel)-\(timestamp).pool-dereg.cert")
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
                // cardano-cli needs the cold vkey file; with only a pool ID the
                // certificate is built natively (the CBOR is identical).
                if transactionOptions.useCardanoCLI, let coldVkeyPath {
                    let logger = getLogger(config: config)
                    let cli = try await CardanoCLI(
                        configuration: config.toSwiftCardanoUtilsConfig(),
                        logger: logger
                    )
                    _ = try await cli.stakePool.deregistrationCertificate(arguments: [
                        "--cold-verification-key-file", FileUtils.absolutePath(coldVkeyPath).string,
                        "--epoch", "\(retireEpoch)",
                        "--out-file", FileUtils.absolutePath(outFile).string
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
            if var pool, let poolJSON {
                pool.deregistration = PoolDeregistration(
                    certCreated: Date(),
                    certificate: outFile,
                    epoch: retireEpoch
                )
                try pool.save(to: poolJSON, overwrite: true)
            }

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

                if transactionOptions.feePaymentAddress == nil && isInteractiveSession() {
                    transactionOptions.feePaymentAddress = try await getFeePaymentAddress(
                        title: "Fee Payment Address"
                    )
                }

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

                // Pool cold signing key: --cold-signing-key, else the pool JSON's cold_skey
                if coldSigningKey == nil && pool == nil && isInteractiveSession() {
                    coldSigningKey = try promptColdSigningKey()
                }
                if let coldSkeyPath = coldSigningKey ?? pool?.coldSkey {
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

                    // Catch a key for a different pool before paying fees. Encrypted
                    // keys can't be loaded here; the Sign step will decrypt them.
                    if let coldSKey = try? StakePoolSigningKey.load(from: coldSkeyPath.string) {
                        let coldVKey: StakePoolVerificationKey = try coldSKey.toVerificationKey()
                        guard try coldVKey.poolKeyHash() == poolKeyHash else {
                            noora.error(.alert(
                                "Cold signing key does not belong to pool \(poolIdBech).",
                                takeaways: ["Check that \(coldSkeyPath.string) is the cold key for the pool being retired."]
                            ))
                            throw ExitCode.validationFailure
                        }
                    }
                } else {
                    noora.error(.alert(
                        pool == nil
                            ? "A pool cold signing key is required to sign the retirement transaction."
                            : "Cold signing key path is not set in the pool JSON.",
                        takeaways: [pool == nil
                            ? "Provide --cold-signing-key <name>.node.skey."
                            : "Ensure the pool JSON contains a valid cold_skey path, or pass --cold-signing-key."]
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
                    ["--signing-keys", $0]
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
