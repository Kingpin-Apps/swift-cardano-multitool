import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftCardanoChain
import SwiftCardanoTxBuilder
import Logging
import Path

extension GenerateMainCommand {
    
    struct RewardsWithdraw: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Generates a rewards withdrawal transaction to withdraw staking rewards.",
            usage: """
            cardano-spo-tools generate rewards-withdraw \\
                --stake-address-name owner \\
                --to-address owner.payment
            
            cardano-spo-tools generate rewards-withdraw \\
                -s owner.stake \\
                -t addr1... \\
                -f fees.payment \\
                --message "Rewards for epoch 450" \\
                --encryption basic
            """,
            discussion: """
            Claims staking rewards from a stake address and sends them to a destination address.
            
            The transaction can withdraw all available rewards from a registered stake address.
            You can specify the same or different addresses for receiving rewards and paying fees.
            
            IMPORTANT: In Conway era (protocol version ≥ 10), a DRep delegation is required
            before claiming rewards.
            """
        )
        
        // MARK: - Required Arguments
        
        @Option(name: [.short, .long], help: "Staking address file base name (without .stake.addr). Example: owner → owner.stake.addr")
        var stakeAddressName: String?
        
        @Option(name: [.short, .long], help: "Destination for rewards. Accepts: bech32 address, file base name, payment key hash, or $adahandle")
        var toAddress: String?
        
        // MARK: - Optional Arguments
        
        @Option(name: [.short, .long], help: "Address to pay transaction fees from (defaults to destination address). Accepts same formats as --to-address")
        var feePaymentAddress: String?
        
        @Option(name: [.short, .long], parsing: .upToNextOption, help: "Transaction message(s). Max 64 bytes each. Can be specified multiple times.")
        var messages: [String] = []
        
        @Option(name: .long, help: "Message encryption mode. Options: basic")
        var encryption: TransactionMessage.EncryptionMode?
        
        @Option(name: .long, help: "Passphrase for message encryption (default: cardano)")
        var passphrase: String = "cardano"
        
        @Option(name: .long, parsing: .upToNextOption, help: "Path(s) to JSON metadata file(s). Can be specified multiple times.")
        var metadataJson: [FilePath] = []
        
        @Option(name: .long, parsing: .upToNextOption, help: "Path(s) to CBOR metadata file(s). Can be specified multiple times.")
        var metadataCbor: [FilePath] = []
        
        @Option(name: .long, parsing: .upToNextOption, help: "Specific UTXOs to use. Format: txHash#index. Can be specified multiple times.")
        var utxoFilter: [String] = []
        
        @Option(name: .long, help: "Maximum number of input UTXOs to use (positive integer)")
        var utxoLimit: Int?
        
        @Option(name: .long, parsing: .upToNextOption, help: "Skip UTXOs containing these assets. Format: policyId+assetNameHex. Can be specified multiple times.")
        var skipUtxoWithAsset: [String] = []
        
        @Option(name: .long, parsing: .upToNextOption, help: "Only use UTXOs containing these assets. Format: policyId+assetNameHex. Can be specified multiple times.")
        var onlyUtxoWithAsset: [String] = []
        
        @Flag(help: "Use cardano-cli to build the transaction (default: use SwiftCardano)")
        var useCardanoCLI = false
        
        // MARK: - Internal State
        
        struct ResolvedAddresses {
            let stakeAddress: Address
            let stakeSigningMethod: SigningMethod
            let destinationAddress: Address
            let feePaymentAddress: Address
            let feePaymentSigningMethod: SigningMethod
            
            public var isSame: Bool {
                return self.feePaymentAddress == self.destinationAddress
            }
        }
        
        // MARK: - Validation
        
        mutating func validate() throws {
            // Validate messages length (64 bytes max)
            for msg in messages {
                guard msg.utf8.count <= 64 else {
                    throw ValidationError("Message exceeds 64 bytes: '\(msg)' is \(msg.utf8.count) bytes")
                }
            }
            
            // Validate encryption mode
//            if let enc = encryption {
//                guard enc.lowercased() == "basic" else {
//                    throw ValidationError("Invalid encryption mode '\(enc)'. Only 'basic' is supported.")
//                }
//            }
            
            // Validate metadata files exist
            for jsonPath in metadataJson {
                guard FileManager.default.fileExists(atPath: jsonPath.string) else {
                    throw ValidationError("Metadata JSON file not found: \(jsonPath)")
                }
            }
            
            for cborPath in metadataCbor {
                guard FileManager.default.fileExists(atPath: cborPath.string) else {
                    throw ValidationError("Metadata CBOR file not found: \(cborPath)")
                }
            }
            
            // Validate UTXO filter format: 64 hex chars + # + digits
            for utxo in utxoFilter {
                let pattern = "^[0-9a-fA-F]{64}#[0-9]+$"
                guard utxo.range(of: pattern, options: .regularExpression) != nil else {
                    throw ValidationError("Invalid UTXO filter format '\(utxo)'. Expected: txHash#index")
                }
            }
            
            // Validate UTXO limit
            if let limit = utxoLimit {
                guard limit > 0 else {
                    throw ValidationError("UTXO limit must be a positive integer, got: \(limit)")
                }
            }
            
            // Validate asset filter format: 56 hex chars (policyId) + assetNameHex
            for asset in skipUtxoWithAsset + onlyUtxoWithAsset {
                let pattern = "^[0-9a-fA-F]{56}\\+[0-9a-fA-F]+$"
                guard asset.range(of: pattern, options: .regularExpression) != nil else {
                    throw ValidationError("Invalid asset filter format '\(asset)'. Expected: policyId+assetNameHex (hex format)")
                }
            }
        }
        
        // MARK: - Wizard
        
        mutating func wizard() async throws {
            // Step 1: Stake address name
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let stakingFiles = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                .filter { $0.hasSuffix(".stake.addr") }
                .map { String($0.dropLast(".stake.addr".count)) }
            
            if stakingFiles.isEmpty {
                noora.error(.alert(
                    "No stake address files found in current directory.",
                    takeaways: [
                        "Please create a stake address first using the 'generate payment-and-stake-address' command."
                    ]
                ))
                throw ExitCode.failure
            }
            
            stakeAddressName = noora.singleChoicePrompt(
                title: "Stake Address",
                question: "Select the stake address to claim rewards from:",
                options: stakingFiles,
                description: "Available .stake.addr files in current directory"
            )
            
            // Step 2: Destination address
            toAddress = noora.textPrompt(
                title: "Destination Address",
                prompt: "Enter the destination address for rewards:",
                description: "Accepts: bech32 address, file base name (e.g., owner.payment), or $adahandle",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Destination address cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Step 3: Fee payment address
            let useSameAddress = noora.yesOrNoChoicePrompt(
                title: "Fee Payment",
                question: "Use the same address to pay transaction fees?",
                defaultAnswer: true,
                description: "If 'No', you'll specify a different address to pay fees from."
            )
            
            if !useSameAddress {
                feePaymentAddress = noora.textPrompt(
                    title: "Fee Payment Address",
                    prompt: "Enter the address to pay fees from:",
                    description: "Accepts: bech32 address, file base name (e.g., fees.payment)",
                    collapseOnAnswer: true,
                    validationRules: [NonEmptyValidationRule(error: "Fee payment address cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // Step 4: Messages (optional)
            let includeMessages = noora.yesOrNoChoicePrompt(
                title: "Transaction Messages",
                question: "Include transaction messages?",
                defaultAnswer: false,
                description: "Optional metadata messages (max 64 bytes each)"
            )
            
            if includeMessages {
                var addMore = true
                while addMore {
                    let msg = noora.textPrompt(
                        title: "Message \(messages.count + 1)",
                        prompt: "Enter message:",
                        description: "Max 64 bytes. Leave empty to skip.",
                        collapseOnAnswer: true
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !msg.isEmpty {
                        if msg.utf8.count > 64 {
                            noora.warning(.alert("Message too long (\(msg.utf8.count) bytes). Skipped."))
                        } else {
                            messages.append(msg)
                        }
                        
                        addMore = noora.yesOrNoChoicePrompt(
                            title: "Add Another Message",
                            question: "Add another message?",
                            defaultAnswer: false
                        )
                    } else {
                        addMore = false
                    }
                }
                
                // Step 5: Encryption (if messages present)
                if !messages.isEmpty {
                    let encryptMessages = noora.yesOrNoChoicePrompt(
                        title: "Message Encryption",
                        question: "Encrypt messages?",
                        defaultAnswer: false,
                        description: "Uses basic encryption with a passphrase"
                    )
                    
                    if encryptMessages {
                        encryption = .basic
                        
                        let customPassphrase = noora.yesOrNoChoicePrompt(
                            title: "Custom Passphrase",
                            question: "Use a custom passphrase?",
                            defaultAnswer: false,
                            description: "Default passphrase is 'cardano'"
                        )
                        
                        if customPassphrase {
                            let promptText: TerminalText = "Enter passphrase for message encryption"
                            passphrase = try await PasswordUtils.getConfirmedPassword(
                                prompt: promptText,
                                cleanup: []
                            )
                        }
                    }
                }
            }
            
            // Step 6: Metadata JSON files (optional)
            let includeMetadataJson = noora.yesOrNoChoicePrompt(
                title: "Metadata JSON",
                question: "Include JSON metadata files?",
                defaultAnswer: false,
                description: "Add transaction metadata from JSON files"
            )
            
            if includeMetadataJson {
                var addMore = true
                while addMore {
                    let path = FilePath(noora.textPrompt(
                        title: "JSON Metadata File \(metadataJson.count + 1)",
                        prompt: "Enter path to JSON metadata file:",
                        description: "Relative or absolute path. Leave empty to skip.",
                        collapseOnAnswer: true
                    ).trimmingCharacters(in: .whitespacesAndNewlines))
                    
                    if !path.isEmpty {
                        if FileManager.default.fileExists(atPath: path.string) {
                            metadataJson.append(path)
                            addMore = noora.yesOrNoChoicePrompt(
                                title: "Add Another JSON File",
                                question: "Add another JSON metadata file?",
                                defaultAnswer: false
                            )
                        } else {
                            noora.warning(.alert("File not found: \(path). Skipped."))
                            addMore = noora.yesOrNoChoicePrompt(
                                title: "Try Again",
                                question: "Try another file?",
                                defaultAnswer: true
                            )
                        }
                    } else {
                        addMore = false
                    }
                }
            }
            
            // Step 7: Metadata CBOR files (optional)
            let includeMetadataCbor = noora.yesOrNoChoicePrompt(
                title: "Metadata CBOR",
                question: "Include CBOR metadata files?",
                defaultAnswer: false,
                description: "Add transaction metadata from CBOR files"
            )
            
            if includeMetadataCbor {
                var addMore = true
                while addMore {
                    let path = FilePath(noora.textPrompt(
                        title: "CBOR Metadata File \(metadataCbor.count + 1)",
                        prompt: "Enter path to CBOR metadata file:",
                        description: "Relative or absolute path. Leave empty to skip.",
                        collapseOnAnswer: true
                    ).trimmingCharacters(in: .whitespacesAndNewlines))
                    
                    if !path.isEmpty {
                        if FileManager.default.fileExists(atPath: path.string) {
                            metadataCbor.append(path)
                            addMore = noora.yesOrNoChoicePrompt(
                                title: "Add Another CBOR File",
                                question: "Add another CBOR metadata file?",
                                defaultAnswer: false
                            )
                        } else {
                            noora.warning(.alert("File not found: \(path). Skipped."))
                            addMore = noora.yesOrNoChoicePrompt(
                                title: "Try Again",
                                question: "Try another file?",
                                defaultAnswer: true
                            )
                        }
                    } else {
                        addMore = false
                    }
                }
            }
            
            // Step 8: UTXO filters (optional)
            let useUtxoFilters = noora.yesOrNoChoicePrompt(
                title: "UTXO Filters",
                question: "Apply UTXO filters?",
                defaultAnswer: false,
                description: "Specify which UTXOs to use or skip"
            )
            
            if useUtxoFilters {
                // Specific UTXOs
                let useSpecificUtxos = noora.yesOrNoChoicePrompt(
                    title: "Specific UTXOs",
                    question: "Use specific UTXOs only?",
                    defaultAnswer: false,
                    description: "Select specific transaction outputs to use"
                )
                
                if useSpecificUtxos {
                    var addMore = true
                    while addMore {
                        let utxo = noora.textPrompt(
                            title: "UTXO \(utxoFilter.count + 1)",
                            prompt: "Enter UTXO (format: txHash#index):",
                            description: "Example: a1b2c3...#0. Leave empty to finish.",
                            collapseOnAnswer: true
                        ).trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if !utxo.isEmpty {
                            // Validate format
                            let pattern = "^[0-9a-fA-F]{64}#[0-9]+$"
                            if utxo.range(of: pattern, options: .regularExpression) != nil {
                                utxoFilter.append(utxo)
                                addMore = noora.yesOrNoChoicePrompt(
                                    title: "Add Another UTXO",
                                    question: "Add another UTXO?",
                                    defaultAnswer: false
                                )
                            } else {
                                noora.warning(.alert("Invalid UTXO format. Expected: txHash#index (64 hex chars + # + number). Skipped."))
                                addMore = noora.yesOrNoChoicePrompt(
                                    title: "Try Again",
                                    question: "Try another UTXO?",
                                    defaultAnswer: true
                                )
                            }
                        } else {
                            addMore = false
                        }
                    }
                }
                
                // UTXO limit
                let useLimitUtxos = noora.yesOrNoChoicePrompt(
                    title: "UTXO Limit",
                    question: "Limit the number of UTXOs?",
                    defaultAnswer: false,
                    description: "Set a maximum number of input UTXOs to use"
                )
                
                if useLimitUtxos {
                    let limitStr = noora.textPrompt(
                        title: "UTXO Limit",
                        prompt: "Enter maximum number of UTXOs:",
                        description: "Positive integer (e.g., 10)",
                        collapseOnAnswer: true,
                        validationRules: [NonEmptyValidationRule(error: "UTXO limit cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if let limit = Int(limitStr), limit > 0 {
                        utxoLimit = limit
                    } else {
                        noora.warning(.alert("Invalid UTXO limit. Must be a positive integer. Skipped."))
                    }
                }
                
                // Asset filters
                let useAssetFilters = noora.yesOrNoChoicePrompt(
                    title: "Asset Filters",
                    question: "Filter UTXOs by assets?",
                    defaultAnswer: false,
                    description: "Include or exclude UTXOs containing specific assets"
                )
                
                if useAssetFilters {
                    let filterChoice = noora.singleChoicePrompt(
                        title: "Asset Filter Type",
                        question: "Choose filter type:",
                        options: ["Skip UTXOs with asset", "Only use UTXOs with asset", "Both"],
                        description: "Select how to filter UTXOs by assets"
                    )
                    
                    if filterChoice == "Skip UTXOs with asset" || filterChoice == "Both" {
                        var addMore = true
                        while addMore {
                            let asset = noora.textPrompt(
                                title: "Skip Asset \(skipUtxoWithAsset.count + 1)",
                                prompt: "Enter asset to skip (format: policyId+assetNameHex):",
                                description: "Example: abc123...+48656c6c6f. Leave empty to finish.",
                                collapseOnAnswer: true
                            ).trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            if !asset.isEmpty {
                                let pattern = "^[0-9a-fA-F]{56}\\+[0-9a-fA-F]+$"
                                if asset.range(of: pattern, options: .regularExpression) != nil {
                                    skipUtxoWithAsset.append(asset)
                                    addMore = noora.yesOrNoChoicePrompt(
                                        title: "Add Another Asset to Skip",
                                        question: "Add another asset to skip?",
                                        defaultAnswer: false
                                    )
                                } else {
                                    noora.warning(.alert("Invalid asset format. Expected: policyId+assetNameHex (56 hex chars + + hex). Skipped."))
                                    addMore = noora.yesOrNoChoicePrompt(
                                        title: "Try Again",
                                        question: "Try another asset?",
                                        defaultAnswer: true
                                    )
                                }
                            } else {
                                addMore = false
                            }
                        }
                    }
                    
                    if filterChoice == "Only use UTXOs with asset" || filterChoice == "Both" {
                        var addMore = true
                        while addMore {
                            let asset = noora.textPrompt(
                                title: "Required Asset \(onlyUtxoWithAsset.count + 1)",
                                prompt: "Enter asset to require (format: policyId+assetNameHex):",
                                description: "Example: abc123...+48656c6c6f. Leave empty to finish.",
                                collapseOnAnswer: true
                            ).trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            if !asset.isEmpty {
                                let pattern = "^[0-9a-fA-F]{56}\\+[0-9a-fA-F]+$"
                                if asset.range(of: pattern, options: .regularExpression) != nil {
                                    onlyUtxoWithAsset.append(asset)
                                    addMore = noora.yesOrNoChoicePrompt(
                                        title: "Add Another Required Asset",
                                        question: "Add another required asset?",
                                        defaultAnswer: false
                                    )
                                } else {
                                    noora.warning(.alert("Invalid asset format. Expected: policyId+assetNameHex (56 hex chars + + hex). Skipped."))
                                    addMore = noora.yesOrNoChoicePrompt(
                                        title: "Try Again",
                                        question: "Try another asset?",
                                        defaultAnswer: true
                                    )
                                }
                            } else {
                                addMore = false
                            }
                        }
                    }
                }
            }
            
            // Step 9: Build method
            useCardanoCLI = noora.yesOrNoChoicePrompt(
                title: "Build Method",
                question: "Use cardano-cli to build transaction?",
                defaultAnswer: false,
                description: "Default: SwiftCardano. Alternative: cardano-cli"
            )
            
            try self.validate()
        }
        
        // MARK: - Run
        
        mutating func run() async throws {
            // If no arguments provided, run wizard
            if stakeAddressName == nil && toAddress == nil {
                try await self.wizard()
            }
            
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            
            // Ensure required arguments are present
            guard let stakeName = stakeAddressName, let toAddr = toAddress else {
                throw ValidationError("Required arguments missing. Use --stake-address-name and --to-address or run without arguments for wizard mode.")
            }
            
            let config = try await MultitoolConfig.load()
            
            spacedPrint(
                "\n\(.primary("━━━ Rewards Withdrawal Transaction ━━━"))\n"
            )
            
            // Resolve all addresses
            let resolved = try await resolveAddresses(
                stakeName: stakeName,
                toAddr: toAddr,
                feeAddr: feePaymentAddress,
                config: config
            )
            
            noora.info(.alert(
                "Address Resolution Complete. Claim Staking Rewards with the following details:",
                takeaways: [
                    "Stake: \(resolved.stakeAddress)",
                    "Destination: \(resolved.destinationAddress)",
                    "Fee Payer: \(resolved.feePaymentAddress)",
                    "Signing: Payment via \(resolved.feePaymentSigningMethod.isHardware ? "Hardware" : "Software"), Stake via \(resolved.stakeSigningMethod.isHardware ? "Hardware" : "Software")"
                ]
            ))
            
            let metadataFile = FilePath(try FileManager
                .default
                .temporaryDirectory
                .appendingPathComponent("\(resolved.feePaymentAddress.toBech32()).transactionMessage")
                .appendingPathExtension("json" ).path)
            
//            let transactionMessageMetadata = try TransactionMessage.buildMetadata(
//                messages: self.messages,
//                encryption: self.encryption ?? .none,
//                passphrase: self.passphrase
//            )
            let auxilliaryData = try TransactionMessage
                .buildAuxiliaryData(
                    messages: self.messages,
                    encryption: self.encryption ?? .none,
                    metadataJson: self.metadataJson,
                    metadataCbor: self.metadataCbor
                )
            if auxilliaryData != nil {
                try auxilliaryData?.saveJSON(to: metadataFile.string)
            }
            
//            if transactionMessageMetadata != nil {
//                // create tmp file to save metadata
//                let transactionMessageMetadataFile = try FileManager
//                    .default
//                    .temporaryDirectory
//                    .appendingPathComponent("\(resolved.feePaymentAddress.toBech32()).transactionMessage")
//                    .appendingPathExtension("json" )
//            } else {
//                transactionMessageMetadataFile = nil
//            }
            
            
            // Get chain context
            let context = try await getContext(config: config)
            
            let protocolParamsFile = cwd.appending(
                "protocol-parameters.json"
            )
            
            let (tip, ttl, protocolParams) = try await queryChainState(
                context: context,
                config: config,
                protocolParamsFile: protocolParamsFile
            )
            
            try await displayChainInfo(
                resolved: resolved,
                context: context,
                tip: tip,
                ttl: ttl
            )
            
            let stakeAddressInfo = try await queryStakeAddressInfo(
                resolved: resolved,
                context: context,
                config: config,
                protocolParams: protocolParams
            )
            
            let filteredUtxos = try await queryAndFilterUtxos(
                resolved: resolved,
                context: context,
                config: config
            )
            
            try await utxoSummary(utxos: filteredUtxos, config: config)
            
            if !metadataJson.isEmpty {
                spacedPrint(
                    "Include Metadata-File(s): "
                )
                for file in metadataJson {
                    print(noora.format("• \(.primary("\(file)"))"))
                }
            }
            
            if !messages.isEmpty {
                if encryption == .basic {
                    spacedPrint(
                        "Original Transaction-Message(s): "
                    )
                    for message in messages {
                        print(noora.format("• \(.primary("\(message)"))"))
                    }
                    spacedPrint(
                        "Encrypted Transaction-Message mode \(.primary("\(encryption!.rawValue)")) with Passphrase \(.accent("\(passphrase)"))"
                    )
                }
                if auxilliaryData != nil {
                    spacedPrint(
                        "Include Transaction-Message-Metadata-File: \(.path(try AbsolutePath(validating: metadataFile.string)))"
                    )
                }
            }
            
            let totalLovelaces = filteredUtxos.reduce(0) {
                $0 + $1.output.lovelace
            }
            
            var assetsOutString = ""
            
            // Walk all UTxOs
            for utxo in filteredUtxos {
                // For each policy/script hash
                for (scriptHash, assetsUnderPolicy) in utxo.output.amount.multiAsset.data {
                    // Convert policyId (scriptHash) to hex
                    let policyIdHex = scriptHash.payload.hexEncodedString()
                    
                    // For each asset under that policy
                    for (assetName, amount) in assetsUnderPolicy.data {
                        // Convert asset name (bytes) to hex
                        let assetNameHex = assetName.payload.hexEncodedString()
                        
                        // The asset identifier (policyId + "." + assetNameHex) or "+" if you prefer
                        let assetHashName = "\(policyIdHex).\(assetNameHex)"
                        
                        // Append in the format: +<amount> <policyId.assetNameHex>
                        assetsOutString += "+\(amount) \(assetHashName)"
                    }
                }
            }
            
            let minOutUtxo = try await minLovelacePostAlonzo(
                filteredUtxos[0].output,
                context
            )
            
            let withdrawal = Withdrawals([
                resolved.stakeAddress.toBytes(): Coin(stakeAddressInfo.rewardAccountBalance)
            ])
            
            // Temporary file paths
            let tempDir = FilePath(FileManager.default.temporaryDirectory.absoluteString)
            let txRawFile = tempDir.appending("rewards-withdraw-raw.tx")
            let txBodyFile = tempDir.appending("rewards-withdraw.txbody")
            let txFile = tempDir.appending("rewards-withdraw.tx")
            let txWitnessFile = tempDir.appending("rewards-withdraw.witness")
            let txSignedFile = tempDir.appending("rewards-withdraw-signed.tx")
            
            var txBuilder = TxBuilder(context: context)
            
            try await buildTransaction(
                resolved: resolved,
                context: context,
                txBuilder: txBuilder,
                config: config,
                filteredUtxos: filteredUtxos,
                ttl: ttl,
                stakeAddressInfo: stakeAddressInfo,
                totalLovelaces: totalLovelaces,
                protocolParamsFile: protocolParamsFile,
                assetsOutString: assetsOutString,
                txRawFile: txRawFile,
                txBodyFile: txBodyFile,
                minOutUtxo: Int(minOutUtxo),
                withdrawal: withdrawal,
                messages: messages,
                metadataFile: metadataFile,
                metadataJson: metadataJson,
                metadataCbor: metadataCbor,
                
            )
            
            try await signTransaction(
                txFile: txBodyFile,
                signedFile: txSignedFile,
                resolved: resolved,
                txBuilder: txBuilder,
                config: config
            )
            
            try await FileUtils.displayJSONFile(txSignedFile)
            
            let tx = try Transaction.load(from: txSignedFile.string)
            
            try checkTransactionSize(
                transaction: tx,
                protocolParameters: protocolParams
            )
            
            try await submitTransaction(
                txFile: txSignedFile,
                context: context,
                config: config
            )
        }
        
        // MARK: - Address Resolution
        
        /// Resolves all addresses for the transaction
        private func resolveAddresses(
            stakeName: String,
            toAddr: String,
            feeAddr: String?,
            config: MultitoolConfig
        ) async throws -> ResolvedAddresses {
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            
            // 1. Resolve stake address
            let (stakeAddress, stakeSigningMethod) = try await resolveStakeAddress(
                name: stakeName,
                cwd: cwd
            )
            
            // 2. Resolve destination address
            let destinationAddress = try await resolveToAddress(
                input: toAddr,
                config: config,
                cwd: cwd
            )
            // 3. Resolve fee payment address (defaults to destination)
            let feePaymentInput = feeAddr ?? toAddr
            let (feePaymentAddress, feePaymentSigningMethod) = try await resolveFeePaymentAddress(
                input: feePaymentInput,
                config: config,
                cwd: cwd
            )
            return ResolvedAddresses(
                stakeAddress: stakeAddress,
                stakeSigningMethod: stakeSigningMethod,
                destinationAddress: destinationAddress,
                feePaymentAddress: feePaymentAddress,
                feePaymentSigningMethod: feePaymentSigningMethod
            )
        }
        
        /// Resolves stake address and its signing method
        private func resolveStakeAddress(
            name: String,
            cwd: FilePath
        ) async throws -> (address: Address, signingMethod: SigningMethod) {
            // Clean up the name (remove .stake or .stake.addr if present)
            var cleanName = name
            if cleanName.hasSuffix(".stake.addr") {
                cleanName = String(cleanName.dropLast(".stake.addr".count))
            } else if cleanName.hasSuffix(".stake") {
                cleanName = String(cleanName.dropLast(".stake".count))
            }
            
            // Check for address file
            let addrFile = cwd.appending("\(cleanName).stake.addr")
            do {
                try FileUtils.checkFileExists(addrFile)
            } catch {
                noora.error(.alert(
                    "Staking address file not found: \(addrFile.string)",
                    takeaways: [
                        "Make sure the file exists",
                        "Generate it using: generate payment-and-stake-address"
                    ]
                ))
                throw ExitCode.validationFailure
            }
            
            // Read address
            let address = try Address.load(from: addrFile.string)
            
            guard address.addressType == .noneKey || address.addressType == .noneScript else {
                noora.error(.alert(
                    "Address in file is not a stake address: \(addrFile.string)",
                    takeaways: [
                        "Ensure the file contains a valid stake address",
                        "Generate it using: generate payment-and-stake-address"
                    ]
                ))
                throw ExitCode.validationFailure
            }
            
            // Determine signing method
            let skeyFile = cwd.appending("\(cleanName).stake.skey")
            let hwsFile = cwd.appending("\(cleanName).stake.hwsfile")
            
            let signingMethod: SigningMethod
            if FileManager.default.fileExists(atPath: hwsFile.string) {
                signingMethod = .hardwareWallet(hwsFile)
            } else if FileManager.default.fileExists(atPath: skeyFile.string) {
                signingMethod = .softwareKey(skeyFile)
            } else {
                noora.error(.alert(
                    "No signing key found for stake address '\(cleanName)'",
                    takeaways: [
                        "Expected: \(skeyFile.string) or \(hwsFile.string)",
                        "Generate keys using: generate payment-and-stake-address"
                    ]
                ))
                throw ExitCode.validationFailure
            }
            
            return (address, signingMethod)
        }
        
        /// Resolves destination address (supports bech32, file name, or $adahandle)
        private func resolveToAddress(
            input: String,
            config: MultitoolConfig,
            cwd: FilePath
        ) async throws -> Address {
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            
            do {
                if trimmed.hasPrefix("$") {
                    // Case 1: $adahandle
                    return try await resolveAdahandle(
                        handle: trimmed,
                        network: config.cardano.network
                    )
                }
                else if trimmed.hasPrefix("addr") {
                    // Case 2: Bech32 address (starts with addr or addr_test)
                    // Validate it's a payment address
                    do {
                        let address = try Address(from: .string(trimmed))
                        guard address.paymentPart != nil else {
                            noora.error(.alert(
                                "Address is not a payment address: \(trimmed)",
                                takeaways: ["Provide a valid payment address (not stake-only)"]
                            ))
                            throw ExitCode.validationFailure
                        }
                        return address
                    } catch {
                        noora.error(.alert(
                            "Invalid bech32 address: \(trimmed)",
                            takeaways: ["Error: \(error.localizedDescription)"]
                        ))
                        throw ExitCode.validationFailure
                    }
                } else {
                    // Case 3: File name (e.g., owner.payment or owner)
                    var fileName = trimmed
                    if fileName.hasSuffix(".payment.addr") {
                        fileName = String(fileName.dropLast(".payment.addr".count))
                    } else if fileName.hasSuffix(".payment") {
                        fileName = String(fileName.dropLast(".payment".count))
                    } else if fileName.hasSuffix(".addr") {
                        fileName = String(fileName.dropLast(".addr".count))
                    }
                    
                    do {
                        let addrFile = cwd.appending("\(fileName).payment")
                        try FileUtils.checkFileExists(addrFile)
                        return try Address.load(from: addrFile.string)
                    } catch {
                        let addrFile = cwd.appending("\(fileName)")
                        try FileUtils.checkFileExists(addrFile)
                        return try Address.load(from: addrFile.string)
                    }
                }
                
            } catch {
                noora.error(.alert(
                    "Could not resolve destination address: \(trimmed)",
                    takeaways: [
                        "Tried: $adahandle, bech32 address, file at \(cwd.string)",
                        "Provide a valid address in one of these formats"
                    ]
                ))
                throw ExitCode.validationFailure
            }
        }
        
        /// Resolves fee payment address and its signing method
        private func resolveFeePaymentAddress(
            input: String,
            config: MultitoolConfig,
            cwd: FilePath
        ) async throws -> (address: Address, signingMethod: SigningMethod) {
            // First resolve the address
            let address = try await resolveToAddress(
                input: input,
                config: config,
                cwd: cwd
            )
            
            // Try to find signing method from file name
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // If it's a bech32 address or $adahandle, we can't determine signing method
            if trimmed.hasPrefix("addr") || trimmed.hasPrefix("$") {
                noora.error(.alert(
                    "Cannot determine signing key for fee payment address",
                    takeaways: [
                        "When using bech32 addresses or $adahandle for fee payment,",
                        "provide a file-based address (e.g., owner.payment) instead"
                    ]
                ))
                throw ExitCode.validationFailure
            }
            
            // Extract file name
            var fileName = trimmed
            if fileName.hasSuffix(".payment.addr") {
                fileName = String(fileName.dropLast(".payment.addr".count))
            } else if fileName.hasSuffix(".payment") {
                fileName = String(fileName.dropLast(".payment".count))
            } else if fileName.hasSuffix(".addr") {
                fileName = String(fileName.dropLast(".addr".count))
            }
            
            // Check for signing keys
            let skeyFile = cwd.appending("\(fileName).payment.skey")
            let hwsFile = cwd.appending("\(fileName).payment.hwsfile")
            
            let signingMethod: SigningMethod
            if FileManager.default.fileExists(atPath: hwsFile.string) {
                signingMethod = .hardwareWallet(hwsFile)
            } else if FileManager.default.fileExists(atPath: skeyFile.string) {
                signingMethod = .softwareKey(skeyFile)
            } else {
                // Try without .payment suffix
                let altSkeyFile = cwd.appending("\(fileName).skey")
                let altHwsFile = cwd.appending("\(fileName).hwsfile")
                
                if FileManager.default.fileExists(atPath: altHwsFile.string) {
                    signingMethod = .hardwareWallet(altHwsFile)
                } else if FileManager.default.fileExists(atPath: altSkeyFile.string) {
                    signingMethod = .softwareKey(altSkeyFile)
                } else {
                    noora.error(.alert(
                        "No signing key found for fee payment address '\(fileName)'",
                        takeaways: [
                            "Expected: \(skeyFile.string) or \(hwsFile.string)",
                            "Or: \(altSkeyFile.string) or \(altHwsFile.string)"
                        ]
                    ))
                    throw ExitCode.validationFailure
                }
            }
            
            return (address, signingMethod)
        }
        
        // MARK: - Chain State Querying
        
        /// Queries chain state for stake address info
        private func queryChainState(
            context: any ChainContext,
            config: MultitoolConfig,
            protocolParamsFile: FilePath,
        ) async throws -> (tip: Int, ttl: Int, protocolParams: ProtocolParameters) {
            // Query chain state
            print(noora.format(
                "\n\(.primary("━━━ Querying Chain State ━━━"))\n"
            ))
            
            let tip = try await noora.progressStep(
                message: "Querying blockchain tip...",
                successMessage: "Successfully retrieved the blockchain tip.",
                errorMessage: "Failed to retrieve the blockchain tip.",
                showSpinner: true
            ) { updateMessage in
                return try await context.lastBlockSlot()
            }
            
            let ttl = tip + config.cardano.ttlBuffer
            
            let protocolParams = try await noora.progressStep(
                message: "Querying protocol parameters...",
                successMessage: "Successfully retrieved protocol parameters.",
                errorMessage: "Failed to retrieve protocol parameters.",
                showSpinner: true
            ) { updateMessage in
                return try await context.protocolParameters()
            }
            try protocolParams.save(to: protocolParamsFile.string)
            
            return (tip, ttl, protocolParams)
        }
        
        /// Displays chain info to the user
        private func displayChainInfo(
            resolved: ResolvedAddresses,
            context: any ChainContext,
            tip: Int,
            ttl: Int
        ) async throws {
            // Display chain info
            print(noora.format(
                "\n\(.primary("━━━ Chain Status ━━━"))\n"
            ))
            
            spacedPrint(
                "Current Slot-Height: \(.primary("\(tip)")) \(.muted("(setting TTL[invalid_hereafter] to \(ttl))"))"
            )
            
            spacedPrint(
                "Current Epoch: ~\(String(describing: context.epoch)))"
            )
        }
        
        /// Query and display stake address info
        private func queryStakeAddressInfo(
            resolved: ResolvedAddresses,
            context: any ChainContext,
            config: MultitoolConfig,
            protocolParams: ProtocolParameters
        ) async throws -> StakeAddressInfo {
            
            spacedPrint(
                "\n\(.primary("━━━ Stake Address Info ━━━"))\n"
            )
            
            if resolved.isSame {
                spacedPrint(
                    "Using same address for rewards and fee payment."
                )
            } else {
                noora.warning(.alert(
                    "Using different addresses for rewards and fee payment."
                ))
            }
        
            let stakeAddressInfoResponse = try await noora.progressStep(
                message: "Fetching stake address info...",
                successMessage: "Successfully retrieved the blockchain tip.",
                errorMessage: "Failed to retrieve the blockchain tip.",
                showSpinner: true
            ) { updateMessage in
                return try await context
                    .stakeAddressInfo(address: resolved.stakeAddress)
            }
            
            guard let stakeAddressInfo = stakeAddressInfoResponse.first else {
                noora.error(.alert(
                    "Stake Registration: \(.danger("✗ Not Registered"))",
                    takeaways: [
                        "Register the stake address before withdrawing rewards.",
                        "Use 'generate stake-address-registration' command to register."
                    ]
                ))
                throw ExitCode.failure
            }
            
            print(noora.format(
                "Staking Address is \(.success("✓ Registered")) on the chain with a deposit of \(.primary("\(String(describing: stakeAddressInfo.stakeRegistrationDeposit))")) lovelaces\n"
            ))
            
            print(noora.format(
                "Rewards Balance: \(.primary(lovelaceToAdaString(UInt64(stakeAddressInfo.rewardAccountBalance)))) \(.muted("(\(stakeAddressInfo.rewardAccountBalance) lovelaces)"))"
            ))
            
            // If delegated to a pool, show the current pool ID
            if let poolOperator = stakeAddressInfo.stakeDelegation {
                print(noora.format(
                    "Account is delegated to a Pool with ID: \(.primary(try poolOperator.id()))"
                ))
                
                let koiosContext = try await KoiosChainContext(
                    apiKey: config.koiosApiKey,
                    network: config.cardano.network
                )
                
                let poolInfo = try await noora.progressStep(
                    message: "Fetching stake pool info...",
                    successMessage: "Successfully retrieved stake pool info.",
                    errorMessage: "Failed to retrieve stake pool info.",
                    showSpinner: true
                ) { updateMessage in
                    return try await withRetry() {
                        try await koiosContext.poolInfo(poolIds: [poolOperator.id()])
                    }
                }
                
                if let poolDetails = poolInfo.first {
                    noora.info(.alert(
                        "Delegated Stake Pool Details:",
                        takeaways: [
                            "Name: \(poolDetails.metaJson?.name ?? "N/A")",
                            "Ticker: \(poolDetails.metaJson?.ticker ?? "N/A")",
                            "Status: \(String(describing: poolDetails.poolStatus ?? .none))",
                            "Pledge: \(poolDetails.pledge ?? "N/A")",
                            "Live Pledge: \(poolDetails.livePledge ?? "N/A")",
                            "Live Stake: \(poolDetails.liveStake ?? "N/A")",
                            "Block Count: \(poolDetails.blockCount ?? 0)"
                        ]
                    ))
                } else {
                    noora.warning(.alert(
                        "Failed to retrieve details for stake pool ID: \(try poolOperator.id())"
                    ))
                }
            } else {
                print(noora.format(
                    "\(.danger("Account is not delegated to a Pool."))"
                ))
            }
            
            
            // Show the current status of the voteDelegation
            if let voteDelegation = stakeAddressInfo.voteDelegation {
                spacedPrint(
                    "DRep Delegation: \(.success("✓ Delegated")))"
                )
                switch voteDelegation.credential {
                    case .alwaysNoConfidence:
                        noora.info(.alert(
                            "Voting-Power of Staking Address is currently set to: \(.primary("ALWAYS NO CONFIDENCE"))"
                        ))
                    case .alwaysAbstain:
                        noora.info(.alert(
                            "Voting-Power of Staking Address is currently set to: \(.primary("ALWAYS ABSTAIN"))"
                        ))
                    case .scriptHash(let scriptHash):
                        noora.info(.alert(
                            "Voting-Power of Staking Address is delegated to the following DRep-Script:",
                            takeaways: [
                                "CIP129 DRep-ID: \(.primary(try voteDelegation.id((.bech32, .cip129))))",
                                "Legacy DRep-ID: \(.primary(try voteDelegation.id((.bech32, .cip105))))",
                                "DRep-HASH: \(.primary(try voteDelegation.id((.hex, .cip105))))",
                            ]
                        ))
                    case .verificationKeyHash(let vkeyHash):
                        let drepId = try voteDelegation.id((.bech32, .cip129))
                        noora.info(.alert(
                            "Voting-Power of Staking Address is delegated to the following DRep: \(.primary(drepId))",
                            takeaways: [
                                "CIP129 DRep-ID: \(.primary(try voteDelegation.id((.bech32, .cip129))))",
                                "Legacy DRep-ID: \(.primary(try voteDelegation.id((.bech32, .cip105))))",
                                "DRep-HASH: \(.primary(try voteDelegation.id((.hex, .cip105))))",
                            ]
                        ))
                }
            } else {
                print(noora.format(
                    "\(.danger("Voting-Power of Staking Address is not delegated to a DRep."))"
                ))
                
                if protocolParams.protocolVersion.major >= 10 {
                    noora.error(.alert(
                        "\(.danger("⚠️  You need to delegate your stake account to a DRep in order to claim your rewards!"))",
                        takeaways: [
                            "Run the appropriate generate and register command to delegate your stake account to a DRep."
                        ]
                    ))
                }
            }
            
            if let govActionDeposits = stakeAddressInfo.govActionDeposits,
               govActionDeposits.isEmpty == false {
                noora.info(.alert(
                    "👀 Staking Address is used in the following \(govActionDeposits.count) governance action(s):",
                    takeaways: try govActionDeposits
                        .map({ (key: String, value: UInt64) in
                            let govActionID = try GovActionID(from: .list([.string(key), .uint(UInt(value))]))
                            return "\(.primary(try govActionID.id())) -> \(.primary("\(lovelaceToAdaString(value)) deposit"))"
                        })
                ))
            }
            
            
            // Display chain info
            //            displayChainInfo(chainInfo: chainInfo, noora: noora)
            
            // Check if rewards are available
            guard stakeAddressInfo.rewardAccountBalance > 0 else {
                noora.error(.alert(
                    "No rewards available to withdraw.",
                    takeaways: [
                        "Rewards balance: 0 lovelaces",
                        "Wait for rewards to accumulate before claiming."
                    ]
                ))
                throw CleanExit.message("No rewards to withdraw. Exiting.")
            }
            
            return stakeAddressInfo
        }
        
        // MARK: - UTXO Query and Filtering
        
        /// Queries UTXOs from an address and applies filtering
        private func queryAndFilterUtxos(
            resolved: ResolvedAddresses,
            context: any ChainContext,
            config: MultitoolConfig
        ) async throws -> [UTxO] {
            
            spacedPrint(
                "\n\(.primary("━━━ Querying UTxOs ━━━"))\n"
            )
            
            let allUtxos = try await noora.progressStep(
                message: "Fetching UTXOs from fee payment address...",
                successMessage: "Successfully retrieved UTXOs.",
                errorMessage: "Failed to retrieve UTXOs.",
                showSpinner: true
            ) { updateMessage in
                return try await context.utxos(address: resolved.feePaymentAddress)
            }
            
            print(noora.format("Found \(.primary("\(allUtxos.count)")) UTXOs"))
            
            // Apply filters
            var filteredUtxos = allUtxos
            
            // Filter 1: Specific UTXOs
            if !utxoFilter.isEmpty {
                filteredUtxos = filteredUtxos.filter { utxo in
                    utxoFilter.contains(utxo.input.description)
                }
                print(noora.format("After specific UTXO filter: \(.primary("\(filteredUtxos.count)")) UTXOs"))
            }
            
            // Filter 2: Skip UTXOs with specific assets
            if !skipUtxoWithAsset.isEmpty {
                filteredUtxos = filteredUtxos.filter { utxo in
                    !utxo.output.amount.multiAsset.data.keys.contains(where: { (scriptHash: ScriptHash) in
                        // For each policy (script hash), see if any asset under it matches a skip filter
                        guard let assetsUnderPolicy = utxo.output.amount.multiAsset.data[scriptHash] else { return false }
                        // Iterate all skip filters and check if any matches this policy+asset name
                        return skipUtxoWithAsset.contains(where: { filter in
                            let parts = filter.split(separator: "+")
                            guard parts.count == 2 else { return false }
                            let policyIdHex = String(parts[0])
                            let assetNameHex = String(parts[1])
                            // Compare policy id
                            guard scriptHash.payload == policyIdHex.hexStringToData else { return false }
                            // Check any asset name within this policy matches
                            return assetsUnderPolicy.data.keys.contains(where: { (assetName: AssetName) in
                                assetName.payload == assetNameHex.hexStringToData
                            })
                        })
                    })
                }
                print(noora.format("After skip asset filter: \(.primary("\(filteredUtxos.count)")) UTXOs"))
            }
            
            // Filter 3: Only UTXOs with specific assets
            if !onlyUtxoWithAsset.isEmpty {
                filteredUtxos = try filteredUtxos.filter { utxo in
                    // All required assets must be present in the UTXO
                    return try onlyUtxoWithAsset.allSatisfy { filter in
                        let parts = filter.split(separator: "+")
                        guard parts.count == 2 else { return false }
                        let policyIdHex = String(parts[0])
                        let assetNameHex = String(parts[1])
                        
                        // Convert policyId hex -> ScriptHash
                        let scriptHash = ScriptHash(payload: policyIdHex.hexStringToData)
                        
                        // Find assets under this policy
                        guard let assetsUnderPolicy = utxo.output.amount.multiAsset.data[scriptHash] else { return false }
                        
                        // Convert asset name hex -> AssetName and check presence
                        let assetName = try AssetName(payload: assetNameHex.hexStringToData )
                        return assetsUnderPolicy.data.keys.contains(assetName)
                    }
                }
                print(noora.format("After required asset filter: \(.primary("\(filteredUtxos.count)")) UTXOs"))
            }
            
            // Filter 4: UTXO limit
            if let limit = utxoLimit, filteredUtxos.count > limit {
                // Sort by value (descending) and take top N
                filteredUtxos = Array(filteredUtxos.sorted(by: { (lhs: UTxO, rhs: UTxO) in
                    lhs.output.amount > rhs.output.amount
                }).prefix(limit))
                print(noora.format("After limit filter: \(.primary("\(filteredUtxos.count)")) UTXOs"))
            }
            
            guard !filteredUtxos.isEmpty else {
                noora.error(.alert(
                    "No UTXOs available after filtering.",
                    takeaways: [
                        "The fee payment address has no suitable UTXOs.",
                        "Check your filters or fund the address."
                    ]
                ))
                throw ExitCode.failure
            }
            
            return filteredUtxos
        }
        
        // MARK: - Transaction Building
        
        /// Builds, signs, and submits the withdrawal transaction
        private func buildTransaction(
            resolved: ResolvedAddresses,
            context: any ChainContext,
            txBuilder: TxBuilder,
            config: MultitoolConfig,
            filteredUtxos: [UTxO],
            ttl: Int,
            stakeAddressInfo: StakeAddressInfo,
            totalLovelaces: Int,
            protocolParamsFile: FilePath,
            assetsOutString: String,
            txRawFile: FilePath,
            txBodyFile: FilePath,
            minOutUtxo: Int,
            withdrawal: Withdrawals,
            messages: [String]? = nil,
            metadataFile: FilePath? = nil,
            metadataJson: [FilePath]? = nil,
            metadataCbor: [FilePath]? = nil,
        ) async throws {
            print(noora.format(
                "\n\(.primary("━━━ Building Transaction ━━━"))\n"
            ))
            
            if useCardanoCLI {
                try await buildWithCardanoCLI(
                    resolved: resolved,
                    config: config,
                    filteredUtxos: filteredUtxos,
                    ttl: ttl,
                    stakeAddressInfo: stakeAddressInfo,
                    totalLovelaces: totalLovelaces,
                    protocolParamsFile: protocolParamsFile,
                    assetsOutString: assetsOutString,
                    txRawFile: txRawFile,
                    txBodyFile: txBodyFile,
                    minOutUtxo: minOutUtxo,
                    messages: messages,
                    metadataFile: metadataFile,
                    metadataJson: metadataJson,
                    metadataCbor: metadataCbor,
                )
            } else {
                try await buildWithSwiftCardano(
                    resolved: resolved,
                    context: context,
                    txBuilder: txBuilder,
                    config: config,
                    filteredUtxos: filteredUtxos,
                    ttl: ttl,
                    stakeAddressInfo: stakeAddressInfo,
                    totalLovelaces: totalLovelaces,
                    protocolParamsFile: protocolParamsFile,
                    assetsOutString: assetsOutString,
                    txRawFile: txRawFile,
                    txBodyFile: txBodyFile,
                    minOutUtxo: minOutUtxo,
                    withdrawal: withdrawal,
                    messages: messages,
                    metadataFile: metadataFile,
                    metadataJson: metadataJson,
                    metadataCbor: metadataCbor,
                )
            }
        }
        
        /// Builds transaction using cardano-cli
        private func buildWithCardanoCLI(
            resolved: ResolvedAddresses,
            config: MultitoolConfig,
            filteredUtxos: [UTxO],
            ttl: Int,
            stakeAddressInfo: StakeAddressInfo,
            totalLovelaces: Int,
            protocolParamsFile: FilePath,
            assetsOutString: String,
            txRawFile: FilePath,
            txBodyFile: FilePath,
            minOutUtxo: Int,
            messages: [String]? = nil,
            metadataFile: FilePath? = nil,
            metadataJson: [FilePath]? = nil,
            metadataCbor: [FilePath]? = nil
        ) async throws {
            
            print(noora.format("Using \(.primary("cardano-cli")) to build transaction..."))
            
            let cli = try await CardanoCLI(
                configuration: Config(cardano: config.cardano),
                logger: getLogger(config: config)
            )
            
            // Build transaction command arguments
            var buildArgs: [String] = []
            
            // Add inputs
            for utxo in filteredUtxos {
                buildArgs.append("--tx-in")
                buildArgs.append(utxo.input.description)
            }
            
            // Add TTL
            buildArgs.append("--invalid-hereafter")
            buildArgs.append("\(ttl)")
            
            // Add metadata if present
            if let messages = messages, !messages.isEmpty,
               let metadataFile = metadataFile {
                buildArgs.append("--metadata-json-file")
                buildArgs.append(metadataFile.string)
            }
            
            if let metadataJson = metadataJson, !metadataJson.isEmpty {
                for metadataJsonFile in metadataJson {
                    buildArgs.append("--metadata-json-file")
                    buildArgs.append(metadataJsonFile.string)
                }
            }
            
            if let metadataCbor = metadataCbor, !metadataCbor.isEmpty {
                for cborFile in metadataCbor {
                    buildArgs.append("--metadata-cbor-file")
                    buildArgs.append(cborFile.string)
                }
            }
            
            // Add withdrawal
            buildArgs.append("--withdrawal")
            buildArgs.append("\(resolved.stakeAddress)+\(stakeAddressInfo.rewardAccountBalance)")
            
            if resolved.isSame {
                let dummySendAmount = totalLovelaces + stakeAddressInfo.rewardAccountBalance
                
                // Add output (destination address receives rewards)
                buildArgs.append("--tx-out")
                buildArgs.append("\(resolved.destinationAddress)+\(dummySendAmount)\(assetsOutString)")
            } else {
                // Add output (destination address receives rewards)
                buildArgs.append("--tx-out")
                buildArgs.append("\(resolved.feePaymentAddress)+\(totalLovelaces)\(assetsOutString)")
                buildArgs.append("--tx-out")
                buildArgs.append("\(resolved.destinationAddress)+\(stakeAddressInfo.rewardAccountBalance)")
            }
            
            // Build the raw transaction
            _ = try await cli.transaction.buildRaw(arguments: buildArgs + [
                "--fee", "200000",
                "--out-file", txRawFile.string
            ])
            
            let fee = try await cli.transaction.calculateMinFee(arguments: [
                "--output-text",
                "--tx-body-file", txRawFile.string,
                "--protocol-params-file", protocolParamsFile.string,
                "--witness-count", "2",
                "--reference-script-size", "0"
            ])
            
            let txInCount = filteredUtxos.count
            let txOutCount = resolved.isSame ? 1 : 2
            
            spacedPrint(
                "Minimum transfer Fee for \(.primary("\(txInCount)"))x TxIn & \(.primary("\(txOutCount)"))x TxOut & Withdrawal: \(.primary("\(lovelaceToAdaString(UInt64(fee)))")) / \(.primary("\(fee)")) lovelaces "
            )
            
            let lovelacesToReturn: UInt64
            if resolved.isSame {
                lovelacesToReturn = UInt64(
                    totalLovelaces + stakeAddressInfo.rewardAccountBalance - fee
                )
                
                spacedPrint(
                    "Lovelaces that will be returned to destination Address (UTXO-Sum - fees + rewards): \(.primary("\(lovelaceToAdaString(lovelacesToReturn))")) / \(.primary("\(lovelacesToReturn)")) lovelaces "
                )
            } else {
                lovelacesToReturn = UInt64(
                    totalLovelaces - fee
                )
                
                spacedPrint(
                    "Lovelaces that will be sent to the destination Address (rewards): \(.primary("\(lovelaceToAdaString(UInt64(stakeAddressInfo.rewardAccountBalance)))")) / \(.primary("\(stakeAddressInfo.rewardAccountBalance)")) lovelaces "
                )
                
                spacedPrint(
                    "Lovelaces that will be returned to fee payment Address (UTXO-Sum - fees): \(.primary("\(lovelaceToAdaString(lovelacesToReturn))")) / \(.primary("\(lovelacesToReturn)")) lovelaces "
                )
            }
            
            if lovelacesToReturn < minOutUtxo {
                noora.error(.alert(
                    "Not enough funds on the source address! Final output amount \(.primary("\(lovelacesToReturn)")) lovelaces is less than the minimum required UTXO of \(.primary("\(minOutUtxo)")) lovelaces.",
                    takeaways: [
                        "Increase the UTXO input amount or reduce the fee.",
                        "Ensure the final output meets the minimum UTXO requirement."
                    ]
                ))
                throw ExitCode.validationFailure
            }
            
            _ = try await cli.transaction.buildRaw(arguments: buildArgs + [
                "--fee", "\(fee)",
                "--out-file", txBodyFile.string
            ])
        }
        
        /// Builds transaction using SwiftCardano
        private func buildWithSwiftCardano(
            resolved: ResolvedAddresses,
            context: any ChainContext,
            txBuilder: TxBuilder,
            config: MultitoolConfig,
            filteredUtxos: [UTxO],
            ttl: Int,
            stakeAddressInfo: StakeAddressInfo,
            totalLovelaces: Int,
            protocolParamsFile: FilePath,
            assetsOutString: String,
            txRawFile: FilePath,
            txBodyFile: FilePath,
            minOutUtxo: Int,
            withdrawal: Withdrawals,
            messages: [String]? = nil,
            metadataFile: FilePath? = nil,
            metadataJson: [FilePath]? = nil,
            metadataCbor: [FilePath]? = nil
        ) async throws {
            
            print(noora.format("Using \(.primary("swift-cardano")) to build transaction..."))
            
            for utxo in filteredUtxos {
                txBuilder.addInput(utxo)
            }
            
            if !resolved.isSame {
                try txBuilder.addOutput(TransactionOutput(
                    address: resolved.destinationAddress,
                    amount: Value(coin: stakeAddressInfo.rewardAccountBalance)
                ))
            }
            
            txBuilder.ttl = ttl
            txBuilder.withdrawals = withdrawal
            txBuilder.auxiliaryData = try TransactionMessage
                .buildAuxiliaryData(
                    messages: messages,
                    metadataJson: metadataJson,
                    metadataCbor: metadataCbor
                )
            
            let txBody = try await txBuilder.build(changeAddress: resolved.feePaymentAddress)
            
            let txInCount = txBody.inputs.count
            let txOutCount = txBody.outputs.count
            let fee = txBody.fee
            
            spacedPrint(
                "Minimum transfer Fee for \(.primary("\(txInCount)"))x TxIn & \(.primary("\(txOutCount)"))x TxOut & Withdrawal: \(.primary("\(lovelaceToAdaString(UInt64(fee)))")) / \(.primary("\(fee)")) lovelaces "
            )
            
            let lovelacesToReturn: UInt64
            if resolved.isSame {
                lovelacesToReturn = UInt64(
                    txBody.outputs.reduce(0) {
                        if $1.address == resolved.destinationAddress {
                            return $0 + $1.lovelace
                        } else {
                            return $0
                        }
                    }
                )
                
                spacedPrint(
                    "Lovelaces that will be returned to destination Address (UTXO-Sum - fees + rewards): \(.primary("\(lovelaceToAdaString(lovelacesToReturn))")) / \(.primary("\(lovelacesToReturn)")) lovelaces "
                )
            } else {
                lovelacesToReturn = UInt64(
                    txBody.outputs.reduce(0) {
                        if $1.address == resolved.feePaymentAddress {
                            return $0 + $1.lovelace
                        } else {
                            return $0
                        }
                    }
                )
                
                spacedPrint(
                    "Lovelaces that will be sent to the destination Address (rewards): \(.primary("\(lovelaceToAdaString(UInt64(stakeAddressInfo.rewardAccountBalance)))")) / \(.primary("\(stakeAddressInfo.rewardAccountBalance)")) lovelaces "
                )
                
                spacedPrint(
                    "Lovelaces that will be returned to fee payment Address (UTXO-Sum - fees): \(.primary("\(lovelaceToAdaString(lovelacesToReturn))")) / \(.primary("\(lovelacesToReturn)")) lovelaces "
                )
            }
            
            if lovelacesToReturn < minOutUtxo {
                noora.error(.alert(
                    "Not enough funds on the source address! Final output amount \(.primary("\(lovelacesToReturn)")) lovelaces is less than the minimum required UTXO of \(.primary("\(minOutUtxo)")) lovelaces.",
                    takeaways: [
                        "Increase the UTXO input amount or reduce the fee.",
                        "Ensure the final output meets the minimum UTXO requirement."
                    ]
                ))
                throw ExitCode.validationFailure
            }
            let tx = Transaction(
                transactionBody: txBody,
                transactionWitnessSet: try txBuilder.buildWitnessSet(),
                auxiliaryData: txBuilder.auxiliaryData
            )
            try tx.save(to: txBodyFile.string, overwrite: true)
        }
        
        // MARK: - Transaction Signing
        
        /// Signs the transaction with appropriate keys
        private func signTransaction(
            txFile: FilePath,
            signedFile: FilePath,
            resolved: ResolvedAddresses,
            txBuilder: TxBuilder,
            config: MultitoolConfig
        ) async throws {
            print(noora.format("\nSigning transaction..."))
            var tx = try Transaction.load(from: txFile.string)
            
            if case let .hardwareWallet(stakeSkey) = resolved.stakeSigningMethod,
               case let .hardwareWallet(paymentSkey) = resolved.feePaymentSigningMethod, resolved.isSame {
                noora.info("Autocorrect the TxBody for canonical order: ")
                let hwcli = try await CardanoHWCLI(
                    configuration: Config(cardano: config.cardano),
                    logger: getLogger(config: config)
                )
                
                try await hwcli.autocorrectTxBodyFile(txBodyFile: txFile.string)
                
                try await FileUtils.displayFile(FilePath(txFile.string))
                
                spacedPrint(
                    "Sign (Witness+Assemble) the unsigned transaction body with the \(.path(try AbsolutePath(validating: paymentSkey.string))) & \(.path(try AbsolutePath(validating: stakeSkey.string))): \(.path(try AbsolutePath(validating: txFile.string)))"
                )
                
                let cwd = FilePath(FileManager.default.currentDirectoryPath)
                let paymentWitnessFile = cwd.appending("payment.tx.witness")
                let stakeWitnessFile = cwd.appending("stake.tx.witness")
                
                _ = try await hwcli.startHardwareWallet()
                
                _ = try await hwcli.transaction.witness(
                    txFile: FilePath(txFile.string),
                    hwSigningFiles: [
                        paymentSkey,
                        stakeSkey
                    ],
                    outFiles: [
                        paymentWitnessFile,
                        stakeWitnessFile
                    ],
                    changeOutputKeyFiles: [
                        paymentSkey,
                        stakeSkey
                    ]
                )
                
                let cli = try await CardanoCLI(
                    configuration: Config(cardano: config.cardano),
                    logger: getLogger(config: config)
                )
                
                _ = try await cli.transaction.assemble(arguments: [
                    "--tx-body-file", txFile.string,
                    "--witness-file", paymentWitnessFile.string,
                    "--witness-file", stakeWitnessFile.string,
                    "--out-file", signedFile.string
                ])
                
                
                print(noora.format("\(.success("✓")) Transaction Assembled ..."))
                
            } else if case let .softwareKey(stakeSkey) = resolved.stakeSigningMethod,
                       case let .softwareKey(paymentSkey) = resolved.feePaymentSigningMethod {
                spacedPrint(
                    "Sign the unsigned transaction body with the  \(.path(try AbsolutePath(validating: paymentSkey.string))) & \(.path(try AbsolutePath(validating: stakeSkey.string))): \(.path(try AbsolutePath(validating: txFile.string)))"
                )
                if useCardanoCLI {
                    
                    let cli = try await CardanoCLI(
                        configuration: Config(cardano: config.cardano),
                        logger: getLogger(config: config)
                    )
                    
                    _ = try await cli.transaction.sign(arguments: [
                        "--tx-body-file", txFile.string,
                        "--signing-key-file", paymentSkey.string,
                        "--signing-key-file", stakeSkey.string,
                        "--out-file", signedFile.string
                    ])
                } else {
                    
                    var witnessSet = try txBuilder.buildWitnessSet()
                    var vkeyWitnesses: [VerificationKeyWitness] = []
                    
                    let stakeSigningKey = try StakeSigningKey.load(from: stakeSkey.string)
                    let paymentSigningKey = try PaymentSigningKey.load(from: paymentSkey.string)
                    
                    let txId = tx.transactionBody.hash()
                    
                    let paymentSignature = try paymentSigningKey.sign(
                        data: txId
                    )
                    try vkeyWitnesses.append(
                        VerificationKeyWitness(
                            vkey:
                                    .verificationKey(
                                        paymentSigningKey
                                            .toVerificationKey() as PaymentVerificationKey
                                    ),
                            signature: paymentSignature
                        )
                    )
                    
                    let stakeSignature = try stakeSigningKey.sign(
                        data: txId
                    )
                    try witnessSet.vkeyWitnesses?.append(
                        VerificationKeyWitness(
                            vkey:
                                    .verificationKey(
                                        stakeSigningKey
                                            .toVerificationKey() as StakeVerificationKey
                                    ),
                            signature: stakeSignature
                        )
                    )
                    
                    witnessSet.vkeyWitnesses = .nonEmptyOrderedSet(NonEmptyOrderedSet(vkeyWitnesses))
                    tx.transactionWitnessSet = witnessSet
                    
                    try await FileUtils
                        .dumpLockedFile(
                            txFile,
                            data: try tx.toTextEnvelope()!
                        )
                }
            } else {
                noora.error(.alert(
                    "This combination is not allowed! A Hardware-Wallet can only be used to claim its own staking rewards on the chain.",
                    takeaways: [
                        "Either use software keys (.skey files) for both stake and fee payment,",
                        "or use a hardware wallet for the stake key and a software key for the fee payment."
                    ]
                ))
                throw ExitCode.validationFailure
            }
            
            print(noora.format("\(.success("✓")) Transaction signed successfully"))
            
            spacedPrint(
                "Signed transaction saved at: \(.path(try AbsolutePath(validating: signedFile.string))) \n\n \(tx.debugDescription)"
            )
        }
        
        public func checkTransactionSize(transaction: Transaction, protocolParameters: ProtocolParameters) throws -> Void {
            let cborHex = try transaction.toCBORHex()
            let txSize = cborHex.count / 2 // Each byte is represented by 2 hex characters
            let maxTxSize = protocolParameters.maxTxSize
            
            if txSize > maxTxSize {
                noora.error(.alert(
                    "Transaction size exceeds the maximum allowed size.",
                    takeaways: [
                        "Transaction size: \(txSize) bytes",
                        "Maximum allowed size: \(maxTxSize) bytes",
                        "Consider reducing the number of inputs or outputs."
                    ]
                ))
                throw ExitCode.failure
            } else {
                print(noora.format(
                    "Transaction size: \(.primary("\(txSize) bytes")) (within the limit of \(maxTxSize) bytes)"
                ))
            }
        }
        
        // MARK: - Transaction Submission
        
        /// Submits the signed transaction
        private func submitTransaction(
            txFile: FilePath,
            context: any ChainContext,
            config: MultitoolConfig,
        ) async throws {
            let confirm = noora.yesOrNoChoicePrompt(
                title: "Confim Submission",
                question: "Does this look good for you, continue?",
                defaultAnswer: false,
                description: "Please confirm if you would like to submit the transaction to the network."
            )
            
            if !confirm {
                noora.info("Transaction submission cancelled by user.")
                throw ExitCode.success
            }
            
            print(noora.format("\nSubmitting transaction..."))
            
            do {
                let tx = try Transaction.load(from: txFile.string)
                let txId = try await context.submitTx(tx: .transaction(tx))
                
                print(noora.format(
                    "\n\(.success("━━━ Transaction Submitted Successfully ━━━"))\n"
                ))
                
                let explorer = config.blockchainExplorer.explorer()
                let trackingURL = try explorer.viewTransaction(
                    txHash: txId,
                    network: config.cardano.network
                )
                
                spacedPrint("Tracking: \(.link(title:trackingURL.absoluteString, href: trackingURL.absoluteString))")
                
                print(noora.success(
                    "Transaction submitted with ID: \(txId)"
                ))
                
            } catch {
                noora.error(.alert(
                    "Transaction submission failed. Error: \(error.localizedDescription)",
                    takeaways: [
                        "Check the transaction file is saved at: \(txFile.string)",
                        "Ensure the transaction is valid and signed correctly.",
                        "Make sure your endpoint is synced and reachable.",
                        "You can try submitting it manually."
                    ]
                ))
                throw ExitCode.failure
            }
        }
    }
}

