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
            scm certificate pool-registration --pool-operator pool1... --pledge 50K --cost 340 --margin 1.5%
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

            To update a registered pool without a pool JSON file, pass 
            --pool-operator (or choose "Registered Pool" in the wizard). The 
            registered parameters are fetched from the chain, and only the 
            fields you change are edited: interactively you pick which fields to 
            edit, or pass --pledge, --cost, --margin, --relay, --owner, 
            --reward-account, --vrf-vkey and --metadata-url. Relays and owners 
            given as flags replace the registered lists. Key files in the 
            current directory are matched to the registered hashes, and the 
            updated parameters can be saved to a pool.json.
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

        // MARK: - Registered Pool Arguments

        @Option(name: .long, help: "Update a registered pool from its on-chain parameters (no pool.json needed). Supports: pool ID (pool1... or hex), cold verification key (pool_vk1... or hex), .pool.id file, or cold .vkey file.")
        var poolOperator: PoolOperator? = nil

        @Option(name: .long, help: "New pledge, e.g. 100K, 1.5M ADA or 100000000000 lovelace. Requires --pool-operator.")
        var pledge: String? = nil

        @Option(name: .long, help: "New fixed cost per epoch, e.g. 340 ADA or 340000000 lovelace. Requires --pool-operator.")
        var cost: String? = nil

        @Option(name: .long, help: "New margin, e.g. 0.015, 1.5% or 3/200. Requires --pool-operator.")
        var margin: String? = nil

        @Option(name: .customLong("relay"), help: "Relay, repeatable; replaces the registered relays. Formats: ipv4:1.2.3.4:3001, ipv6:[2001:db8::1]:3001, dns:relay.example.com:3001, srv:_cardano._tcp.example.com. Requires --pool-operator.")
        var relays: [PoolRelay] = []

        @Option(name: .customLong("owner"), help: "Pool owner stake key, repeatable; replaces the registered owners. Accepts a stake address, stake key hash, or stake .vkey file. Requires --pool-operator.")
        var owners: [StakeKeyArgument] = []

        @Option(name: .long, help: "Stake key receiving the pool rewards. Accepts a stake address, stake key hash, or stake .vkey file. Requires --pool-operator.")
        var rewardAccount: StakeKeyArgument? = nil

        @Option(name: .long, help: "New VRF verification key file. Requires --pool-operator.")
        var vrfVkey: FilePath? = nil

        @Option(name: .long, help: "New metadata URL. The hash comes from --metadata-hash, --metadata-file, or by downloading the URL. Requires --pool-operator.")
        var metadataUrl: String? = nil

        @Option(name: .long, help: "Hash of the metadata file at --metadata-url (64 hex characters).")
        var metadataHash: String? = nil

        @Option(name: .long, help: "Local copy of the metadata file at --metadata-url, used to compute its hash.")
        var metadataFile: FilePath? = nil

        @Option(name: .long, help: "Pool cold signing key (.skey) for the transaction, when not using a pool.json.")
        var coldSigningKey: FilePath? = nil

        @Option(name: .customLong("owner-signing-key"), help: "Owner stake signing key (.skey) for the transaction, repeatable, when not using a pool.json.")
        var ownerSigningKeys: [FilePath] = []
        
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
                    case .poolOperator: return "Registered Pool"
                }
            }

            var details: String {
                switch self {
                    case .poolName: return "Use the pool name to find pool.json in the current directory."
                    case .poolJSON: return "Use a pool.json file path."
                    case .poolOperator: return "Fetch a registered pool's parameters from the chain and choose which to change. No pool.json needed."
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
        
        /// Whether any flag edits registered parameters.
        private var hasParamEditFlags: Bool {
            pledge != nil || cost != nil || margin != nil || !relays.isEmpty || !owners.isEmpty
                || rewardAccount != nil || vrfVkey != nil || metadataUrl != nil
        }

        mutating func validate() throws {
            try self.validateForTransaction()

            if poolOperator == nil && (hasParamEditFlags || metadataHash != nil || metadataFile != nil) {
                throw ValidationError("--pledge, --cost, --margin, --relay, --owner, --reward-account, --vrf-vkey and --metadata-* edit a registered pool and require --pool-operator. With a pool.json, edit the file instead.")
            }
            let ada = AdaFormatter(defaultUnit: .ada)
            if let pledge, ada.toLovelace(pledge) == nil {
                throw ValidationError("Invalid --pledge '\(pledge)'. Use an ADA amount like 100K or 1.5M, or lovelace like 100000000000 lovelace.")
            }
            if let cost, ada.toLovelace(cost) == nil {
                throw ValidationError("Invalid --cost '\(cost)'. Use an ADA amount like 340, or lovelace like 340000000 lovelace.")
            }
            if let margin, PoolParamsFormat.parseMargin(margin) == nil {
                throw ValidationError("Invalid --margin '\(margin)'. Use a number between 0 and 1 (0.015), a percentage (1.5%), or a fraction (3/200).")
            }
            if (metadataHash != nil || metadataFile != nil) && metadataUrl == nil {
                throw ValidationError("--metadata-hash and --metadata-file require --metadata-url.")
            }
            if metadataHash != nil && metadataFile != nil {
                throw ValidationError("Use either --metadata-hash or --metadata-file, not both.")
            }
            if let metadataHash, metadataHash.count != 64 || metadataHash.hexStringToData.count != 32 {
                throw ValidationError("--metadata-hash must be 64 hex characters.")
            }
            if let metadataUrl, metadataUrl.utf8.count > 64 {
                throw ValidationError("--metadata-url must be 64 bytes or less.")
            }
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

                case .poolOperator:
                    poolOperator = try await getPoolOperator(title: "Registered Pool")
            }

            try await self.wizardForCertificate()
            if certificateOptions.generateTransaction {
                try await self.wizardForTransaction()
            }
            
            try self.validate()
        }
        
        // MARK: - Run
        
        mutating func run() async throws {
            // Run wizard if no input method was provided
            if poolName == nil && poolJSON == nil && poolOperator == nil , isInteractiveSession() {
                try await wizard()
            }

            if let poolOperator {
                try await runFromChain(poolOperator: poolOperator)
                return
            }

            let workingDirectory = FilePath(FileManager.default.currentDirectoryPath)
            if poolJSON == nil, let poolName {
                poolJSON = workingDirectory.appending("\(poolName).pool.json")
            }
            if poolName == nil, let poolJSON {
                poolName = poolJSON.stem?.replacingOccurrences(of: ".pool", with: "")
            }
            
            guard let poolJSON = poolJSON, let poolName = poolName else {
                noora.error(.alert(
                    "A pool is required.",
                    takeaways: ["Provide --pool-name, --pool-json, or --pool-operator for a registered pool."]
                ))
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
                    "--pool-metadata-file", FileUtils.absolutePath(metadataFilePath).string
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

                    // Absolutize key paths — they often come from pool.json as paths
                    // relative to the user's cwd, but cardano-cli resolves them against
                    // its own working directory.
                    var cliArgs: [String] = [
                        "--cold-verification-key-file", FileUtils.absolutePath(coldVkeyPath).string,
                        "--vrf-verification-key-file", FileUtils.absolutePath(vrfVkeyPath).string,
                        "--pool-pledge", "\(pool.pledge ?? 0)",
                        "--pool-cost", "\(pool.cost ?? 0)",
                        "--pool-margin", "\(pool.margin ?? 0)",
                    ]

                    // Rewards stake vkey
                    let rewardsVkeyPath = pool.rewardsOwner?.stakeVkey ?? pool.owners.first?.stakeVkey
                    if let rewardsVkeyPath {
                        cliArgs += ["--pool-reward-account-verification-key-file", FileUtils.absolutePath(rewardsVkeyPath).string]
                    }

                    // Owner stake vkeys
                    for owner in pool.owners {
                        if let ownerVkey = owner.stakeVkey {
                            cliArgs += ["--pool-owner-stake-verification-key-file", FileUtils.absolutePath(ownerVkey).string]
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
                        "--out-file", FileUtils.absolutePath(outFile).string
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
                
                guard let feePaymentAddress = transactionOptions.feePaymentAddress else {
                    noora.error(.alert(
                        "Fee payment address is required to generate the transaction.",
                        takeaways: ["Provide a valid fee payment address."]
                    ))
                    throw ExitCode.validationFailure
                }

                // Pool cold signing key
                let coldSkeyPath: FilePath
                if let path = pool.coldSkey {
                    do {
                        try FileUtils.checkFileExists(path)
                        coldSkeyPath = path
                    } catch {
                        noora.error(.alert(
                            "Cold signing key not found: \(path.string)",
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

                // Each pool owner must witness the registration with their stake
                // signing key — otherwise the ledger rejects the tx with
                // MissingVKeyWitnessesUTXOW for the owner's key hash.
                var ownerSkeys: [FilePath] = []
                for owner in pool.owners {
                    guard let ownerStakeSkey = owner.stakeSkey else {
                        noora.error(.alert(
                            "Owner '\(owner.name ?? "unknown")' is missing a stake signing key (stake_skey).",
                            takeaways: ["Every pool owner must sign the registration; set stake_skey for each owner in the pool JSON."]
                        ))
                        throw ExitCode.validationFailure
                    }
                    do {
                        try FileUtils.checkFileExists(ownerStakeSkey)
                    } catch {
                        noora.error(.alert(
                            "Owner stake signing key not found: \(ownerStakeSkey.string)",
                            takeaways: ["Ensure the file exists for owner '\(owner.name ?? "unknown")'."]
                        ))
                        throw ExitCode.validationFailure
                    }
                    ownerSkeys.append(ownerStakeSkey)
                }

                try await buildAndSignRegistrationTransaction(
                    txBuilder: txBuilder,
                    config: config,
                    certificates: certs,
                    certificateFile: outFile,
                    isInitialRegistration: isInitialRegistration,
                    stakePoolDeposit: Int(stakePoolDeposit),
                    feePaymentAddress: feePaymentAddress,
                    coldSigningKey: coldSkeyPath,
                    ownerSigningKeys: ownerSkeys,
                    protocolParamsFile: protocolParamsFile
                )
            }
        }
    }
}

// MARK: - Shared transaction building

extension CertificateMainCommand.StakePoolRegistrationCertificate {
    /// Build, sign and optionally submit a pool registration transaction.
    fileprivate func buildAndSignRegistrationTransaction(
        txBuilder: TxBuilder,
        config: MultitoolConfig,
        certificates: [Certificate],
        certificateFile: FilePath,
        isInitialRegistration: Bool,
        stakePoolDeposit: Int,
        feePaymentAddress: PaymentAddressInfo,
        coldSigningKey: FilePath,
        ownerSigningKeys: [FilePath],
        protocolParamsFile: FilePath
    ) async throws {
        let cwd = FilePath(FileManager.default.currentDirectoryPath)
        txBuilder.certificates = certificates
        txBuilder.initialStakePoolRegistration = isInitialRegistration

        var signingKeys: [String] = [
            try feePaymentAddress.info.getSigningMethod().path.string,
            coldSigningKey.string
        ]
        for ownerKey in ownerSigningKeys where !signingKeys.contains(ownerKey.string) {
            signingKeys.append(ownerKey.string)
        }

        // Witness count: pool node skey + fee payment skey + each owner stake skey
        let witnessCount = signingKeys.count
        txBuilder.witnessOverride = witnessCount

        spacedPrint(
            "\nSubmit Pool Registration Certificate \(.primary("\(certificateFile.string)")) with funds from Address \(.primary("\(feePaymentAddress.info.name!)"))"
        )

        spacedPrint(
            "Stake Pool Deposit Fee: \(.primary("\(lovelaceToAdaFormatString(UInt64(isInitialRegistration ? stakePoolDeposit : 0)))")) / \(isInitialRegistration ? stakePoolDeposit : 0) lovelaces\(isInitialRegistration ? "" : " (re-registration, no deposit)")."
        )

        spacedPrint(
            "Certificates: \(.primary("\(certificates.count)")) (1 pool registration + \(certificates.count - 1) owner delegation(s))"
        )

        spacedPrint(
            "Witnesses needed: \(.primary("\(witnessCount)")) (pool node + payment + \(ownerSigningKeys.count) owner(s))"
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

// MARK: - Registered pool (no pool.json)

extension CertificateMainCommand.StakePoolRegistrationCertificate {
    /// Apply the parameter edit flags. Returns whether any were given.
    private func applyFlagEdits(_ draft: inout PoolParamsDraft, network: NetworkId) async throws -> Bool {
        let ada = AdaFormatter(defaultUnit: .ada)
        if let pledge, let lovelace = ada.toLovelace(pledge) { draft.pledge = Int(lovelace) }
        if let cost, let lovelace = ada.toLovelace(cost) { draft.cost = Int(lovelace) }
        if let margin, let interval = PoolParamsFormat.parseMargin(margin) { draft.margin = interval }
        if !relays.isEmpty { draft.relays = relays }
        if !owners.isEmpty { draft.owners = owners.map(\.keyHash) }
        if let rewardAccount { draft.rewardAccount = try rewardAccount.rewardAccount(network: network) }
        if let vrfVkey { draft.vrfKeyHash = try VRFVerificationKey.load(from: vrfVkey.string).hash() }
        if let metadataUrl {
            draft.metadataUrl = metadataUrl
            if let metadataHash {
                draft.metadataHash = metadataHash.lowercased()
            } else if let metadataFile {
                guard let data = FileManager.default.contents(atPath: metadataFile.string) else {
                    throw SwiftCardanoMultitoolError.valueError("Could not read --metadata-file \(metadataFile.string).")
                }
                draft.metadataHash = try poolMetadataHash(of: data)
            } else {
                draft.metadataHash = try await noora.progressStep(
                    message: "Downloading \(metadataUrl) to compute its hash...",
                    successMessage: "Computed the metadata hash.",
                    errorMessage: "Could not download the metadata file. Pass --metadata-hash or --metadata-file instead.",
                    showSpinner: true
                ) { _ in try await downloadPoolMetadataHash(url: metadataUrl) }
            }
            // The fetched content described the old metadata file, so don't carry it over
            draft.metadataName = nil
            draft.metadataTicker = nil
            draft.metadataDescription = nil
            draft.metadataHomepage = nil
        }
        return hasParamEditFlags
    }

    /// Prompt for a signing key file, listing files with the given suffixes.
    private func promptSigningKeyFile(title: String, question: String, suffixes: [String]) -> FilePath {
        let cwd = FilePath(FileManager.default.currentDirectoryPath)
        let files = ((try? FileManager.default.contentsOfDirectory(atPath: cwd.string)) ?? [])
            .filter { name in suffixes.contains { name.hasSuffix($0) } }
            .sorted()
        let enterPath = "Enter a file path"
        let choice = files.isEmpty ? enterPath : noora.singleChoicePrompt(
            title: TerminalText(stringLiteral: title),
            question: TerminalText(stringLiteral: question),
            options: files + [enterPath],
            filterMode: .enabled
        )
        if choice != enterPath {
            return cwd.appending(choice)
        }
        return FilePath(noora.textPrompt(
            title: TerminalText(stringLiteral: title),
            prompt: "Enter the path to the signing key:",
            collapseOnAnswer: true,
            validationRules: [NonEmptyValidationRule(error: "Path cannot be empty.")]
        ).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Update a registered pool: fetch its on-chain parameters, apply the requested
    /// edits, and build the registration certificate from the result.
    fileprivate mutating func runFromChain(poolOperator: PoolOperator) async throws {
        let config = try await MultitoolConfig.load()
        let cardanoConfig = try getCardanoConfig(config: config)
        try await resolveAdaHandles(network: cardanoConfig.network)
        let context = try await getContext(config: config)
        try await printContextInfo(config: config, context: context)

        let network = config.cardano?.network.networkId ?? .mainnet
        let cwd = FilePath(FileManager.default.currentDirectoryPath)
        let timestamp = DateUtils.getCurrentTimestamp()
        let interactive = isInteractiveSession()

        let protocolParamsFile = cwd.appending("protocol-parameters.json")
        let protocolParams = try await getProtocolParameters(
            context: context,
            protocolParamsFile: protocolParamsFile
        )
        let minPoolCost = Int(protocolParams.minPoolCost)

        // 1. Registered parameters
        let info: StakePoolInfo
        let original: PoolParamsDraft
        do {
            (info, original) = try await fetchOnChainPoolParams(context: context, poolOperator: poolOperator)
        } catch {
            noora.error(.alert(
                "Could not fetch the registered parameters for \((try? poolOperator.toBech32()) ?? "the pool").",
                takeaways: [
                    "Only registered pools can be updated from on-chain parameters.",
                    "For a first registration, create a pool.json with \(.command("scm generate pool-json")).",
                    "\(error.localizedDescription)"
                ]
            ))
            throw ExitCode.failure
        }

        let keys = PoolKeyFileMatcher()
        let poolIdBech = try original.poolOperator.toBech32()
        PoolParamsFormat.printSummary(original, title: "Registered Pool Parameters", keys: keys)

        var isInitialRegistration = false
        switch info.status {
            case .retiring(let epoch):
                noora.warning(.alert(
                    "This pool is scheduled to retire in epoch \(epoch).",
                    takeaway: "Re-registering the pool cancels the retirement."
                ))
            case .retired:
                isInitialRegistration = true
                noora.warning(.alert(
                    "This pool is retired.",
                    takeaway: "Registering it again requires a new pool deposit."
                ))
            default:
                break
        }

        // 2. Edits: flags, else pick fields interactively
        var draft = original
        let flagEdits = try await applyFlagEdits(&draft, network: network)
        if !flagEdits && interactive {
            let fields: [PoolParamField] = noora.multipleChoicePrompt(
                title: "Edit Pool Parameters",
                question: "Select the parameters to change:",
                description: "Unselected parameters keep their registered values. Select nothing to re-register unchanged."
            )
            try await editPoolParams(&draft, fields: fields, minPoolCost: minPoolCost, network: network, keys: keys)
        }

        // 3. New metadata.json for content edits
        let label = poolName ?? draft.metadataTicker?.lowercased() ?? String(poolIdBech.prefix(12))
        var metadataFilePath: FilePath? = nil
        if draft.metadataContentEdited {
            let metadata = try PoolMetadata(
                name: draft.metadataName,
                description: draft.metadataDescription,
                ticker: draft.metadataTicker,
                homepage: try draft.metadataHomepage.map { try Url($0) }
            )
            guard let json = try metadata.toJSON() else {
                throw SwiftCardanoMultitoolError.valueError("Could not encode the pool metadata.")
            }
            let path = cwd.appending("\(label).metadata.json")
            try FileUtils.dumpFile(path, data: json)
            draft.metadataHash = try poolMetadataHash(of: Data(json.utf8))
            metadataFilePath = path
        }

        // 4. Validate and confirm
        do {
            try draft.validate(minPoolCost: minPoolCost)
        } catch {
            noora.error(.alert("The pool parameters are not valid.", takeaways: ["\(error.localizedDescription)"]))
            throw ExitCode.validationFailure
        }

        PoolParamsFormat.printSummary(draft, title: "New Registration Parameters", original: original, keys: keys)
        if draft == original {
            spacedPrint("No parameters changed; the certificate re-registers the pool with its current parameters.")
        }

        if interactive {
            let proceed = noora.yesOrNoChoicePrompt(
                title: "Create Certificate",
                question: "Create the registration certificate with these parameters?",
                defaultAnswer: true
            )
            guard proceed else { throw ExitCode.success }
        }

        // 5. Certificate
        if certificateOptions.outFile == nil {
            certificateOptions.outFile = cwd.appending("\(label)-\(timestamp).pool-reg.cert")
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

        do {
            // cardano-cli needs every verification key as a file; on-chain params
            // only give hashes, so build natively unless all of them are local.
            let coldVkey = keys.coldVkey(for: draft.poolKeyHash)
            let vrfVkeyFile = keys.vrfVkey(for: draft.vrfKeyHash)
            let rewardVkey = draft.rewardStakeKeyHash.flatMap { keys.stakeVkey(for: $0) }
            let ownerVkeys = draft.owners.compactMap { keys.stakeVkey(for: $0) }
            let cliReady = coldVkey != nil && vrfVkeyFile != nil && rewardVkey != nil && ownerVkeys.count == draft.owners.count

            if transactionOptions.useCardanoCLI && !cliReady {
                noora.warning(.alert(
                    "Building the certificate without cardano-cli.",
                    takeaway: "cardano-cli needs the cold, VRF, reward and owner verification key files, and not all of them were found. The certificate is identical either way."
                ))
            }

            if transactionOptions.useCardanoCLI, cliReady, let coldVkey, let vrfVkeyFile, let rewardVkey {
                let logger = getLogger(config: config)
                let cli = try await CardanoCLI(configuration: config.toSwiftCardanoUtilsConfig(), logger: logger)
                let margin = "\(draft.margin.numerator)/\(draft.margin.denominator)"
                var cliArgs: [String] = [
                    "--cold-verification-key-file", FileUtils.absolutePath(coldVkey).string,
                    "--vrf-verification-key-file", FileUtils.absolutePath(vrfVkeyFile).string,
                    "--pool-pledge", "\(draft.pledge)",
                    "--pool-cost", "\(draft.cost)",
                    "--pool-margin", margin,
                    "--pool-reward-account-verification-key-file", FileUtils.absolutePath(rewardVkey).string,
                ]
                for ownerVkey in ownerVkeys {
                    cliArgs += ["--pool-owner-stake-verification-key-file", FileUtils.absolutePath(ownerVkey).string]
                }
                for relay in draft.relays {
                    switch (relay.type, relay.hostType) {
                        case (.ip, .ipv6): cliArgs += ["--pool-relay-ipv6", relay.host ?? "", "--pool-relay-port", relay.port ?? ""]
                        case (.ip, _): cliArgs += ["--pool-relay-ipv4", relay.host ?? "", "--pool-relay-port", relay.port ?? ""]
                        case (.dns, .multi): cliArgs += ["--multi-host-pool-relay", relay.host ?? ""]
                        case (.dns, _): cliArgs += ["--single-host-pool-relay", relay.host ?? "", "--pool-relay-port", relay.port ?? ""]
                        default: break
                    }
                }
                if let metadataUrl = draft.metadataUrl, let metadataHash = draft.metadataHash {
                    cliArgs += ["--metadata-url", metadataUrl, "--metadata-hash", metadataHash]
                }
                cliArgs += ["--out-file", FileUtils.absolutePath(outFile).string]
                _ = try await cli.stakePool.registrationCertificate(arguments: cliArgs)
            } else {
                let regCert = SwiftCardanoCore.PoolRegistration(poolParams: try draft.toPoolParams())
                try regCert.save(to: outFile.string)
            }
        } catch {
            noora.error(.alert(
                "Could not generate the pool registration certificate!",
                takeaways: ["\(error)"]
            ))
            throw ExitCode.failure
        }

        var takeaways: [TerminalText] = [
            "Certificate: \(outFile.string)",
            "Pool ID (bech32): \(poolIdBech)",
        ]
        if let metadataFilePath, let url = draft.metadataUrl {
            takeaways.append("Upload \(.primary(metadataFilePath.lastComponent?.string ?? "metadata.json")) to \(url) BEFORE submitting the transaction.")
        }
        takeaways.append("Include this certificate when building your pool registration transaction.")
        noora.success(.alert("Pool registration certificate created successfully.", takeaways: takeaways))

        try await FileUtils.displayFile(outFile)
        if let metadataFilePath {
            try await FileUtils.displayJSONFile(metadataFilePath)
        }

        // 6. Offer to save a pool.json
        try await saveRegisteredPoolJSON(draft: draft, label: label, certificate: outFile, metadataFile: metadataFilePath, keys: keys)

        // 7. Transaction
        guard certificateOptions.generateTransaction else { return }

        if transactionOptions.feePaymentAddress == nil && interactive {
            transactionOptions.feePaymentAddress = try await getFeePaymentAddress(title: "Fee Payment Address")
        }
        guard let feePaymentAddress = transactionOptions.feePaymentAddress else {
            noora.error(.alert(
                "Fee payment address is required to generate the transaction.",
                takeaways: ["Provide --fee-payment-address."]
            ))
            throw ExitCode.validationFailure
        }

        // Cold signing key: --cold-signing-key, a matching local key, or ask
        var coldSkey = coldSigningKey ?? keys.coldSkey(for: draft.poolKeyHash)
        if coldSkey == nil && interactive {
            coldSkey = promptSigningKeyFile(
                title: "Pool Cold Signing Key",
                question: "Select the pool cold signing key:",
                suffixes: [".skey", ".hwsfile"]
            )
        }
        guard let coldSkey else {
            noora.error(.alert(
                "No cold signing key found for \(poolIdBech).",
                takeaways: ["Provide --cold-signing-key <pool>.cold.skey."]
            ))
            throw ExitCode.validationFailure
        }
        if let type = PoolKeyFileMatcher.envelopeType(of: coldSkey), !type.hasPrefix("StakePoolSigningKey") {
            noora.error(.alert(
                "\(coldSkey.string) is not a pool cold signing key (it is \(type)).",
                takeaways: ["Provide the pool's cold signing key, e.g. <pool>.cold.skey."]
            ))
            throw ExitCode.validationFailure
        }
        if let hash = PoolKeyFileMatcher.poolKeyHash(ofColdSkeyFile: coldSkey), hash.payload != draft.poolKeyHash.payload {
            noora.error(.alert(
                "The cold signing key \(coldSkey.string) does not belong to pool \(poolIdBech).",
                takeaways: ["Check that you selected the pool's cold key."]
            ))
            throw ExitCode.validationFailure
        }

        // Owner signing keys: every owner must witness the registration
        var ownerSkeys: [FilePath] = []
        for owner in draft.owners {
            let label = keys.stakeVkey(for: owner).flatMap(PoolKeyFileMatcher.keyName) ?? owner.payload.toHex
            var skey = ownerSigningKeys.first { PoolKeyFileMatcher.stakeKeyHash(ofSkeyFile: $0)?.payload == owner.payload }
                ?? keys.stakeSkey(for: owner)
            if skey == nil && interactive {
                skey = promptSigningKeyFile(
                    title: "Owner Stake Signing Key",
                    question: "Select the stake signing key for owner \(label):",
                    suffixes: [".skey", ".hwsfile"]
                )
                if let chosen = skey, PoolKeyFileMatcher.envelopeType(of: chosen) != nil,
                   PoolKeyFileMatcher.stakeKeyHash(ofSkeyFile: chosen)?.payload != owner.payload {
                    noora.error(.alert(
                        "\(chosen.string) is not the stake signing key for owner \(label).",
                        takeaways: ["Every owner must sign with their own stake signing key."]
                    ))
                    throw ExitCode.validationFailure
                }
            }
            guard let skey else {
                noora.error(.alert(
                    "No stake signing key found for owner \(label).",
                    takeaways: ["Every pool owner must sign the registration. Provide --owner-signing-key for each owner."]
                ))
                throw ExitCode.validationFailure
            }
            ownerSkeys.append(skey)
        }

        let logger = getLogger(config: config)
        let txBuilder = TxBuilder(context: context, logger: logger)
        let certificate = try SwiftCardanoCore.PoolRegistration.load(from: outFile.string)

        try await buildAndSignRegistrationTransaction(
            txBuilder: txBuilder,
            config: config,
            certificates: [.poolRegistration(certificate)],
            certificateFile: outFile,
            isInitialRegistration: isInitialRegistration,
            stakePoolDeposit: Int(protocolParams.stakePoolDeposit),
            feePaymentAddress: feePaymentAddress,
            coldSigningKey: coldSkey,
            ownerSigningKeys: ownerSkeys,
            protocolParamsFile: protocolParamsFile
        )
    }

    /// Offer to write the registered parameters to a pool.json, updating an existing one in place.
    private func saveRegisteredPoolJSON(
        draft: PoolParamsDraft,
        label: String,
        certificate: FilePath,
        metadataFile: FilePath?,
        keys: PoolKeyFileMatcher
    ) async throws {
        let cwd = FilePath(FileManager.default.currentDirectoryPath)
        let name: String
        if isInteractiveSession() {
            let save = noora.yesOrNoChoicePrompt(
                title: "Save Pool JSON",
                question: "Save these parameters to a pool.json?",
                defaultAnswer: true,
                description: "Future commands can then use the pool name instead of fetching from the chain. An existing pool.json keeps its other fields."
            )
            guard save else { return }
            name = noora.textPrompt(
                title: "Pool Name",
                prompt: "Enter the pool name (saved as <poolName>.pool.json):",
                defaultValue: label,
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Pool name cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // Non-interactive runs only save when a pool name was given explicitly
            guard let poolName else { return }
            name = poolName
        }

        let path = cwd.appending("\(name).pool.json")
        let registered = try Pool.fromOnChain(draft: draft, name: name, keys: keys)
        var pool: Pool
        if FileManager.default.fileExists(atPath: path.string), var existing = try? Pool.load(from: path) {
            existing.pledge = registered.pledge
            existing.cost = registered.cost
            existing.margin = registered.margin
            existing.relays = registered.relays
            existing.owners = registered.owners.map { owner in
                // Keep an existing owner's name, witness type and files when it is still an owner
                if let current = existing.owners.first(where: { $0.stakeKeyHash == owner.stakeKeyHash
                    || ($0.stakeVkey != nil && $0.stakeVkey == owner.stakeVkey) }) {
                    var merged = current
                    merged.stakeKeyHash = owner.stakeKeyHash
                    merged.stakeVkey = current.stakeVkey ?? owner.stakeVkey
                    merged.stakeSkey = current.stakeSkey ?? owner.stakeSkey
                    return merged
                }
                return owner
            }
            existing.rewardsOwner = registered.rewardsOwner
            existing.vrfKeyHash = registered.vrfKeyHash
            existing.vrfVkey = registered.vrfVkey ?? existing.vrfVkey
            existing.coldVkey = existing.coldVkey ?? registered.coldVkey
            existing.coldSkey = existing.coldSkey ?? registered.coldSkey
            existing.metaUrl = registered.metaUrl
            existing.metadataHash = registered.metadataHash
            existing.metaName = registered.metaName
            existing.metaTicker = registered.metaTicker
            existing.metaDescription = registered.metaDescription
            existing.metaHomepage = registered.metaHomepage
            existing.idBech = registered.idBech
            existing.idHex = registered.idHex
            pool = existing
        } else {
            pool = registered
        }
        if let metadataFile {
            pool.metadataFile = metadataFile
        }
        pool.registration = PoolRegistration(certCreated: Date(), certificate: certificate)
        try pool.save(to: path, overwrite: true)
        noora.success(.alert("Saved the pool parameters to \(path.lastComponent?.string ?? path.string)."))
    }
}
