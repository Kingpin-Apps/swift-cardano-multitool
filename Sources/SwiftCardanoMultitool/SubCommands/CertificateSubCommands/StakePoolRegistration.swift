import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftCardanoChain
import SwiftCardanoTxBuilder


extension CertificateMainCommand {
    struct StakePoolRegistrationCertificate: CertificateCommandable {
        static let configuration = CommandConfiguration(
            commandName: "pool-registration",
            abstract: "Generates a stake pool registration certificate.",
            usage: """
            scm certificate pool-registration --pool-name test
            """,
            discussion: """
            This command generates a stake pool registration certificate based 
            on the information provided in a pool JSON file. You can specify 
            the pool JSON file directly, or provide the pool name to search for 
            a file named <poolName>.pool.json in the current directory. The 
            command will validate the pool information, generate the necessary 
            metadata, and create a registration certificate that can be used to 
            register your stake pool on the Cardano network. Optionally, you can 
            also generate a transaction with the certificate included to submit 
            to the network. If the pool is already registered, you can use the 
            --force option to create a new certificate for re-registration, but 
            use this with caution as it may lead to unexpected consequences if 
            the pool is already registered.
            """,
            aliases: ["pool-reg"]
        )
        
        @Option(name: .shortAndLong, help: "The name of the pool. Will look for a file named <poolName>.pool.json in current working directory.")
        var poolName: String? = nil
        
        @Option(name: [.customShort("j"), .long], help: "The path to the pool.json file.")
        var poolJSON: FilePath? = nil
        
        @Option(
            name: .long,
            help: "Force registration even if the pool is already registered. Use with caution, as this may lead to unexpected consequences if the pool is already registered."
        )
        var force: ForceOption? = nil
        
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

        enum ForceOption: String, CaseIterable, AlignedChoiceDescribable, ExpressibleByArgument {
            case registration
            case reregistration

            var name: String {
                switch self {
                    case .registration: return "Registration"
                    case .reregistration: return "Re-registration"
                }
            }

            var details: String {
                switch self {
                    case .registration: return "Force registration even if the pool is already registered (will create a new certificate that can be used for re-registration)."
                    case .reregistration: return "Force re-registration by creating a new certificate with the same pool ID (use with caution, as this may lead to unexpected consequences if the pool is already registered)."
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
            
            let minPoolCost = protocolParams.minPoolCost
            let stakePoolDeposit = protocolParams.stakePoolDeposit
            
            guard let poolCost = pool.cost else {
                fatalError("Pool cost is nil")
            }
            
            if poolCost < minPoolCost {
                noora.warning(
                    "The cost specified in the pool JSON (\(poolCost)) is below the minimum pool cost (\(minPoolCost)) defined in the protocol parameters. The transaction may be rejected by the network."
                )
                
                let updateCost = noora.yesOrNoChoicePrompt(
                    title: "Update Pool Cost",
                    question: "The cost specified in the pool JSON (\(String(describing: pool.cost))) is below the minimum pool cost (\(minPoolCost)) defined in the protocol parameters. Would you like to checnge it to the minimum?",
                    defaultAnswer: true,
                )
                
                if updateCost {
                    pool.cost = Int(minPoolCost)
                } else {
                    noora.warning(
                        .alert(
                            "Proceeding with the original pool cost may result in the transaction being rejected by the network.",
                            takeaway: "Consider updating the pool cost to meet the minimum requirement defined in the protocol parameters."
                        )
                        
                    )
                    throw ExitCode.validationFailure
                }
            }
            
            // Check PoolRelay Entries
            do {
                for relay in pool.relays {
                    try relay.validate()
                }
            } catch {
                noora.error("One or more relays in the pool JSON are invalid: \(error)")
                throw ExitCode.validationFailure
            }
            
            // Filter out forbidden chars and replace with _ in ticker
            guard let tickerOriginal = pool.metaTicker else {
                noora.error("Pool JSON is missing the required metaTicker field.")
                throw ExitCode.validationFailure
            }
            
            // Replace non-alphanumeric characters with underscore
            let tickerCorrected = String(tickerOriginal.map { $0.isLetter || $0.isNumber ? $0 : Character("_") })
            
            if tickerCorrected.count < 3 || tickerCorrected.count > 5 {
                noora.error("The poolMetaTicker entry must be between 3-5 chars long!")
                throw ExitCode.validationFailure
            }
            
            if tickerCorrected != tickerOriginal {
                let acceptCorrected = noora.yesOrNoChoicePrompt(
                    title: "Pool Ticker Correction",
                    question: "Your poolMetaTicker was corrected from '\(tickerOriginal)' to '\(tickerCorrected)' to fit the rules. Are you ok with this?",
                    defaultAnswer: false
                )
                
                if acceptCorrected {
                    pool.metaTicker = tickerCorrected
                    try pool.save(to: poolJSON, overwrite: true)
                } else {
                    noora.warning("Please re-edit the poolMetaTicker entry in your \(poolJSON.string) and try again.")
                    throw ExitCode.validationFailure
                }
            }

            // Validate required key files
            guard let coldVkeyPath = pool.coldVkey else {
                noora.error(.alert(
                    "Cold verification key file not found in pool JSON.",
                    takeaways: ["Ensure \(poolName).cold.vkey exists and is referenced in the pool JSON."]
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

            guard let vrfVkeyPath = pool.vrfVkey else {
                noora.error(.alert(
                    "VRF verification key file not found in pool JSON.",
                    takeaways: ["Ensure \(poolName).vrf.vkey exists and is referenced in the pool JSON."]
                ))
                throw ExitCode.validationFailure
            }

            do {
                try FileUtils.checkFileExists(vrfVkeyPath)
            } catch {
                noora.error(.alert(
                    "VRF verification key file not found: \(vrfVkeyPath.string)",
                    takeaways: ["Ensure the file exists or run 'scm generate node-vrf-keys' first."]
                ))
                throw ExitCode.validationFailure
            }

            // Validate owner stake vkeys
            guard !pool.owners.isEmpty else {
                noora.error(.alert(
                    "No pool owners found in the pool JSON.",
                    takeaways: ["At least one pool owner with a stake_vkey is required."]
                ))
                throw ExitCode.validationFailure
            }

            spacedPrint("\n\(.primary("━━━ Pool Owner Validation ━━━"))\n")
            for (i, owner) in pool.owners.enumerated() {
                guard let ownerStakeVkeyPath = owner.stakeVkey else {
                    noora.error(.alert(
                        "Owner \(owner.name ?? "#\(i + 1)") is missing a stake_vkey.",
                        takeaways: ["Set stake_vkey for each owner in the pool JSON."]
                    ))
                    throw ExitCode.validationFailure
                }
                do {
                    try FileUtils.checkFileExists(ownerStakeVkeyPath)
                    spacedPrint("  Owner \(.primary(owner.name ?? "#\(i + 1)")): \(ownerStakeVkeyPath.lastComponent?.string ?? ownerStakeVkeyPath.string)")
                } catch {
                    noora.error(.alert(
                        "Stake verification key not found for owner \(owner.name ?? "#\(i + 1)"): \(ownerStakeVkeyPath.string)",
                        takeaways: ["Ensure the file exists or update the path in the pool JSON."]
                    ))
                    throw ExitCode.validationFailure
                }
            }

            // Generate Pool IDs from cold vkey
            spacedPrint("\n\(.primary("━━━ Pool ID Generation ━━━"))\n")
            let stakePoolVKey = try StakePoolVerificationKey.load(from: coldVkeyPath.string)
            let poolKeyHash = try stakePoolVKey.poolKeyHash()
            let poolOperatorId = PoolOperator(poolKeyHash: poolKeyHash)
            let poolIdBech = try poolOperatorId.toBech32()
            let poolIdHex = try poolOperatorId.toBytes().toHex

            pool.idBech = poolIdBech
            pool.idHex = poolIdHex

            let idHexFile = pool.idHexFile ?? cwd.appending("\(poolName).pool.id")
            let idBechFile = pool.idBechFile ?? cwd.appending("\(poolName).pool.id-bech")
            try poolOperatorId.save(to: idHexFile.string, format: .hex)
            try poolOperatorId.save(to: idBechFile.string, format: .bech32)
            pool.idHexFile = idHexFile
            pool.idBechFile = idBechFile

            spacedPrint("Pool ID (Bech32): \(.primary(poolIdBech))")
            spacedPrint("Pool ID (Hex):    \(.primary(poolIdHex))")

            // Generate metadata.json
            spacedPrint("\n\(.primary("━━━ Pool Metadata Generation ━━━"))\n")

            guard let metaUrl = pool.metaUrl else {
                noora.error(.alert(
                    "Pool metadata URL (meta_url) is missing from the pool JSON.",
                    takeaways: ["Set meta_url to the URL where you will host the metadata.json file."]
                ))
                throw ExitCode.validationFailure
            }

            let metadataFilePath = pool.metadataFile ?? cwd.appending("\(poolName).metadata.json")
            pool.metadataFile = metadataFilePath

            if pool.extendedMetaUrl != nil && !transactionOptions.useCardanoCLI {
                noora.warning(
                    .alert(
                        "Extended metadata URL is set but --use-cardano-cli is not specified.",
                        takeaway: "The extended URL will be included in the metadata file, but the hash will be computed from the standard 4-field JSON. Use --use-cardano-cli to hash the full file including the extended URL."
                    )
                )
            }

            let metadataHash: String
            let metadataJsonContent: String

            if transactionOptions.useCardanoCLI {
                // Build metadata JSON with optional extended URL
                if let extendedMetaUrl = pool.extendedMetaUrl {
                    metadataJsonContent = """
                    {
                        "name": "\(pool.metaName ?? "")",
                        "description": "\(pool.metaDescription ?? "")",
                        "ticker": "\(pool.metaTicker ?? "")",
                        "homepage": "\(pool.metaHomepage?.absoluteString ?? "")",
                        "extended": "\(extendedMetaUrl.absoluteString)"
                    }
                    """
                } else {
                    let poolMetadata = try PoolMetadata(
                        name: pool.metaName,
                        description: pool.metaDescription,
                        ticker: pool.metaTicker,
                        homepage: pool.metaHomepage.flatMap { try? Url($0.absoluteString) }
                    )
                    metadataJsonContent = try poolMetadata.toJSON()!
                }

                guard metadataJsonContent.utf8.count <= 512 else {
                    noora.error(.alert(
                        "Pool metadata.json is too large (\(metadataJsonContent.utf8.count) bytes, max 512 bytes).",
                        takeaways: ["Shorten the pool name, description, or ticker."]
                    ))
                    throw ExitCode.validationFailure
                }

                try FileUtils.dumpFile(metadataFilePath, data: metadataJsonContent)

                let logger = getLogger(config: config)
                let cli = try await CardanoCLI(
                    configuration: config.toSwiftCardanoUtilsConfig(),
                    logger: logger
                )
                metadataHash = try await cli.stakePool.metadataHash(arguments: [
                    "--pool-metadata-file", metadataFilePath.string
                ]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                let poolMetadata = try PoolMetadata(
                    name: pool.metaName,
                    description: pool.metaDescription,
                    ticker: pool.metaTicker,
                    homepage: pool.metaHomepage.flatMap { try? Url($0.absoluteString) }
                )
                metadataJsonContent = try poolMetadata.toJSON()!

                guard metadataJsonContent.utf8.count <= 512 else {
                    noora.error(.alert(
                        "Pool metadata.json is too large (\(metadataJsonContent.utf8.count) bytes, max 512 bytes).",
                        takeaways: ["Shorten the pool name, description, or ticker."]
                    ))
                    throw ExitCode.validationFailure
                }

                try FileUtils.dumpFile(metadataFilePath, data: metadataJsonContent)
                metadataHash = try poolMetadata.hash()
            }

            pool.metadataHash = metadataHash

            spacedPrint("Metadata file:  \(.primary(metadataFilePath.lastComponent?.string ?? metadataFilePath.string))")
            spacedPrint("Metadata hash:  \(.primary(metadataHash))")

            // Print registration summary
            spacedPrint("""
            \n\(.primary("━━━ Pool Registration Summary ━━━"))
              Pool Name:   \(.primary(poolName))
              Pool ID:     \(.primary(poolIdBech))
              Owners:      \(.primary("\(pool.owners.count)"))
              Pledge:      \(.primary(lovelaceToAdaFormatString(UInt64(pool.pledge ?? 0)))) (\(pool.pledge ?? 0) lovelaces)
              Cost:        \(.primary(lovelaceToAdaFormatString(UInt64(pool.cost ?? 0)))) (\(pool.cost ?? 0) lovelaces)
              Margin:      \(.primary(String(format: "%.2f%%", (pool.margin ?? 0) * 100)))
            """)

            // Determine output certificate file path
            if certificateOptions.outFile == nil {
                certificateOptions.outFile = cwd.appending("\(poolName)-\(timestamp).pool-reg.cert")
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

            // Generate the registration certificate
            do {
                if transactionOptions.useCardanoCLI {
                    let logger = getLogger(config: config)
                    let cli = try await CardanoCLI(
                        configuration: config.toSwiftCardanoUtilsConfig(),
                        logger: logger
                    )

                    var cliArgs: [String] = [
                        "--cold-verification-key-file", coldVkeyPath.string,
                        "--vrf-verification-key-file", vrfVkeyPath.string,
                        "--pool-pledge", "\(pool.pledge ?? 0)",
                        "--pool-cost", "\(pool.cost ?? 0)",
                        "--pool-margin", "\(pool.margin ?? 0)",
                    ]

                    // Rewards stake vkey
                    let rewardsVkeyPath = pool.rewardsOwner?.stakeVkey ?? pool.owners.first?.stakeVkey
                    if let rewardsVkeyPath {
                        cliArgs += ["--pool-reward-account-verification-key-file", rewardsVkeyPath.string]
                    }

                    // Owner stake vkeys
                    for owner in pool.owners {
                        if let ownerVkey = owner.stakeVkey {
                            cliArgs += ["--pool-owner-stake-verification-key-file", ownerVkey.string]
                        }
                    }

                    // Relays
                    for relay in pool.relays {
                        switch relay.type {
                        case .ip:
                            if let host = relay.host, let port = relay.port {
                                switch relay.hostType {
                                case .ipv6:
                                    cliArgs += ["--pool-relay-ipv6", host, "--pool-relay-port", port]
                                default:
                                    cliArgs += ["--pool-relay-ipv4", host, "--pool-relay-port", port]
                                }
                            }
                        case .dns:
                            if let host = relay.host {
                                switch relay.hostType {
                                case .multi:
                                    cliArgs += ["--multi-host-pool-relay", host]
                                default:
                                    if let port = relay.port {
                                        cliArgs += ["--single-host-pool-relay", host, "--pool-relay-port", port]
                                    }
                                }
                            }
                        case nil:
                            break
                        }
                    }

                    // Metadata
                    cliArgs += [
                        "--metadata-url", metaUrl.absoluteString,
                        "--metadata-hash", metadataHash,
                        "--out-file", outFile.string
                    ]

                    _ = try await cli.stakePool.registrationCertificate(arguments: cliArgs)
                } else {
                    // Use SwiftCardanoCore PoolRegistration
                    // metadataHash must be set on pool before calling toPoolParams
                    let updatedPoolParams = try pool.toPoolParams(
                        network: config.cardano?.network.networkId ?? .mainnet
                    )
                    let regCert = SwiftCardanoCore.PoolRegistration(poolParams: updatedPoolParams)
                    try regCert.save(to: outFile.string)
                }
            } catch {
                noora.error(.alert(
                    "Could not generate the pool registration certificate!",
                    takeaways: ["\(error)"]
                ))
                throw ExitCode.failure
            }

            // Update pool.json with registration info
            pool.registration = PoolRegistration(
                certCreated: Date(),
                certificate: outFile
            )
            try pool.save(to: poolJSON, overwrite: true)

            // Display results
            noora.success(.alert(
                "Pool registration certificate created successfully.",
                takeaways: [
                    "Certificate: \(outFile.string)",
                    "Pool ID (bech32): \(poolIdBech)",
                    "Metadata hash: \(metadataHash)",
                    "Upload \(.primary(metadataFilePath.lastComponent?.string ?? "metadata.json")) to \(metaUrl.absoluteString) BEFORE submitting the transaction.",
                    "Include this certificate when building your pool registration transaction."
                ]
            ))

            try await FileUtils.displayFile(outFile)
            try await FileUtils.displayJSONFile(metadataFilePath)
            
            if certificateOptions.generateTransaction {
                let logger = getLogger(config: config)
                let txBuilder = TxBuilder(context: context, logger: logger)
                
                let poolRegistrationCert = try SwiftCardanoCore.PoolRegistration.load(from: outFile.string)
                
                // Build certificate list: pool registration + owner delegation certificates
                var certs: [Certificate] = [
                    .poolRegistration(poolRegistrationCert)
                ]
                
                for owner in pool.owners {
                    if let delegCertPath = owner.delegationCertificate {
                        do {
                            try FileUtils.checkFileExists(delegCertPath)
                            let delegCert = try SwiftCardanoCore.StakeDelegation.load(from: delegCertPath.string)
                            certs.append(.stakeDelegation(delegCert))
                        } catch {
                            noora.warning(
                                "Owner delegation certificate not found for \(owner.name ?? "unknown"): \(delegCertPath.string). Skipping."
                            )
                        }
                    }
                }
                
                txBuilder.certificates = certs
                
                // Determine if this is an initial registration or re-registration
                // by checking if the pool ID is already on-chain
                let isInitialRegistration: Bool
                do {
                    let onChainPools = try await context.stakePools()
                    let alreadyRegistered = try onChainPools.contains(
                        where: { try $0.id() == poolIdBech }
                    )
                    isInitialRegistration = !alreadyRegistered
                    
                    if alreadyRegistered {
                        spacedPrint(
                            "Pool ID is already on the chain, continuing with a \(.primary("Re-Registration"))."
                        )
                    } else {
                        spacedPrint(
                            "Pool ID is not on the chain yet, continuing with a normal \(.primary("Registration"))."
                        )
                    }
                } catch {
                    noora.warning(
                        "Unable to query on-chain stake pools to determine registration status. Defaulting to initial registration."
                    )
                    isInitialRegistration = true
                }
                
                txBuilder.initialStakePoolRegistration = isInitialRegistration
                
                // Witness count: pool node skey + fee payment skey + each owner stake skey
                let witnessCount = 2 + pool.owners.count
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
                    "\nSubmit Pool Registration Certificate \(.primary("\(outFile.string)")) with funds from Address \(.primary("\(feePaymentAddress.info.name!)"))"
                )
                
                spacedPrint(
                    "Stake Pool Deposit Fee: \(.primary("\(lovelaceToAdaFormatString(UInt64(isInitialRegistration ? stakePoolDeposit : 0)))")) / \(isInitialRegistration ? stakePoolDeposit : 0) lovelaces\(isInitialRegistration ? "" : " (re-registration, no deposit)")."
                )
                
                spacedPrint(
                    "Certificates: \(.primary("\(certs.count)")) (1 pool registration + \(certs.count - 1) owner delegation(s))"
                )
                
                spacedPrint(
                    "Witnesses needed: \(.primary("\(witnessCount)")) (pool node + payment + \(pool.owners.count) owner(s))"
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
