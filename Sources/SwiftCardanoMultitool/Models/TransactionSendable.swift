import ArgumentParser
import Foundation
import SystemPackage
import Noora
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftCardanoChain
import SwiftCardanoTxBuilder
import Path

protocol TransactionSendable: AsyncParsableCommand {
    var transactionOptions: SharedTransactionOptions { get set }
}

extension TransactionSendable {
    var isSame: Bool {
        return transactionOptions.feePaymentAddress?.info.address == transactionOptions.toAddress?.info.address
    }
    
    // MARK: - Validation
    
    mutating func validateForTransaction() throws {
        // Validate messages length (64 bytes max)
        for msg in transactionOptions.messages {
            guard msg.utf8.count <= 64 else {
                throw ValidationError("Message exceeds 64 bytes: '\(msg)' is \(msg.utf8.count) bytes")
            }
        }
        
        // Validate metadata files exist
        for jsonPath in transactionOptions.metadataJson {
            guard FileManager.default.fileExists(atPath: jsonPath.string) else {
                throw ValidationError("Metadata JSON file not found: \(jsonPath)")
            }
        }
        
        for cborPath in transactionOptions.metadataCbor {
            guard FileManager.default.fileExists(atPath: cborPath.string) else {
                throw ValidationError("Metadata CBOR file not found: \(cborPath)")
            }
        }
        
        // Validate UTXO filter format: 64 hex chars + # + digits
        for utxo in transactionOptions.utxoFilter {
            let pattern = "^[0-9a-fA-F]{64}#[0-9]+$"
            guard utxo.range(of: pattern, options: .regularExpression) != nil else {
                throw ValidationError("Invalid UTXO filter format '\(utxo)'. Expected: txHash#index")
            }
        }
        
        // Validate UTXO limit
        if let limit = transactionOptions.utxoLimit {
            guard limit > 0 else {
                throw ValidationError("UTXO limit must be a positive integer, got: \(limit)")
            }
        }
        
        // Validate asset filter format: 56 hex chars (policyId) + assetNameHex
        for asset in transactionOptions.skipUtxoWithAsset + transactionOptions.onlyUtxoWithAsset {
            let pattern = "^[0-9a-fA-F]{56}\\+[0-9a-fA-F]+$"
            guard asset.range(of: pattern, options: .regularExpression) != nil else {
                throw ValidationError("Invalid asset filter format '\(asset)'. Expected: policyId+assetNameHex (hex format)")
            }
        }
    }
    
    // MARK: - Wizard
    
    mutating func wizardForTransaction() async throws {
        if transactionOptions.feePaymentAddress == nil {
            transactionOptions.feePaymentAddress = try await getFeePaymentAddress(
                title: "Fee Payment Address"
            )
        }
        
        // Messages (optional)
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
                    title: "Message \(transactionOptions.messages.count + 1)",
                    prompt: "Enter message:",
                    description: "Max 64 bytes. Leave empty to skip.",
                    collapseOnAnswer: true
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !msg.isEmpty {
                    if msg.utf8.count > 64 {
                        noora.warning(.alert("Message too long (\(msg.utf8.count) bytes). Skipped."))
                    } else {
                        transactionOptions.messages.append(msg)
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
            
            // Encryption (if messages present)
            if !transactionOptions.messages.isEmpty {
                let encryptMessages = noora.yesOrNoChoicePrompt(
                    title: "Message Encryption",
                    question: "Encrypt messages?",
                    defaultAnswer: false,
                    description: "Uses basic encryption with a passphrase"
                )
                
                if encryptMessages {
                    transactionOptions.encryption = TransactionMessage.EncryptionMode.basic
                    
                    let customPassphrase = noora.yesOrNoChoicePrompt(
                        title: "Custom Passphrase",
                        question: "Use a custom passphrase?",
                        defaultAnswer: false,
                        description: "Default passphrase is 'cardano'"
                    )
                    
                    if customPassphrase {
                        let promptText: TerminalText = "Enter passphrase for message encryption"
                        transactionOptions.passphrase = try await PasswordUtils.getConfirmedPassword(
                            prompt: promptText
                        )
                    }
                } else {
                    transactionOptions.encryption = TransactionMessage.EncryptionMode.none
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
                    title: "JSON Metadata File \(transactionOptions.metadataJson.count + 1)",
                    prompt: "Enter path to JSON metadata file:",
                    description: "Relative or absolute path. Leave empty to skip.",
                    collapseOnAnswer: true
                ).trimmingCharacters(in: .whitespacesAndNewlines))
                
                if !path.isEmpty {
                    if FileManager.default.fileExists(atPath: path.string) {
                        transactionOptions.metadataJson.append(path)
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
                    title: "CBOR Metadata File \(transactionOptions.metadataCbor.count + 1)",
                    prompt: "Enter path to CBOR metadata file:",
                    description: "Relative or absolute path. Leave empty to skip.",
                    collapseOnAnswer: true
                ).trimmingCharacters(in: .whitespacesAndNewlines))
                
                if !path.isEmpty {
                    if FileManager.default.fileExists(atPath: path.string) {
                        transactionOptions.metadataCbor.append(path)
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
                        title: "UTXO \(transactionOptions.utxoFilter.count + 1)",
                        prompt: "Enter UTXO (format: txHash#index):",
                        description: "Example: a1b2c3...#0. Leave empty to finish.",
                        collapseOnAnswer: true
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !utxo.isEmpty {
                        // Validate format
                        let pattern = "^[0-9a-fA-F]{64}#[0-9]+$"
                        if utxo.range(of: pattern, options: .regularExpression) != nil {
                            transactionOptions.utxoFilter.append(utxo)
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
                    transactionOptions.utxoLimit = limit
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
                            title: "Skip Asset \(transactionOptions.skipUtxoWithAsset.count + 1)",
                            prompt: "Enter asset to skip (format: policyId+assetNameHex):",
                            description: "Example: abc123...+48656c6c6f. Leave empty to finish.",
                            collapseOnAnswer: true
                        ).trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if !asset.isEmpty {
                            let pattern = "^[0-9a-fA-F]{56}\\+[0-9a-fA-F]+$"
                            if asset.range(of: pattern, options: .regularExpression) != nil {
                                transactionOptions.skipUtxoWithAsset.append(asset)
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
                            title: "Required Asset \(transactionOptions.onlyUtxoWithAsset.count + 1)",
                            prompt: "Enter asset to require (format: policyId+assetNameHex):",
                            description: "Example: abc123...+48656c6c6f. Leave empty to finish.",
                            collapseOnAnswer: true
                        ).trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if !asset.isEmpty {
                            let pattern = "^[0-9a-fA-F]{56}\\+[0-9a-fA-F]+$"
                            if asset.range(of: pattern, options: .regularExpression) != nil {
                                transactionOptions.onlyUtxoWithAsset.append(asset)
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
        
        transactionOptions.useCardanoCLI = noora.yesOrNoChoicePrompt(
            title: "Build Method",
            question: "Use cardano-cli to build transaction?",
            defaultAnswer: false,
            description: "Default: SwiftCardano. Alternative: cardano-cli"
        )
        
        transactionOptions.save = noora.yesOrNoChoicePrompt(
            title: "Save Transaction",
            question: "Save built transaction to file?",
            defaultAnswer: true,
            description: "You can submit it later if desired."
        )
        
        transactionOptions.submit = noora.yesOrNoChoicePrompt(
            title: "Submit Transaction",
            question: "Submit the transaction to the blockchain?",
            defaultAnswer: false,
            description: "Requires network connectivity and sufficient funds."
        )
        
//        try self.validateForTransaction()
    }
    
    // MARK: - Query Stake Address
    
    /// Query and display stake address info
    public mutating func queryStakeAddressInfo(
        stakeAddress: inout StakeAddressInfo,
        context: any ChainContext,
        config: MultitoolConfig,
        protocolParams: ProtocolParameters
    ) async throws -> Void {
        
        spacedPrint(
            "\n\(.primary("━━━ Stake Address Info ━━━"))\n"
        )
        
        try await stakeAddress.info.updateStakeAddressInfo(context: context)
        
        stakeAddress.info.addressTypeEra()
        
        guard stakeAddress.info.stakeAddressInfo.count > 0 else {
            noora.error(.alert(
                "No stake address information found.",
                takeaways: [
                    "Unable to retrieve stake address details from chain.",
                    "Ensure the stake address is registered."
                ]
            ))
            throw CleanExit.message("No stake address info. Exiting.")
        }
        
        try await stakeAddressInfoSummary(
            stakeAddressInfo: stakeAddress.info.stakeAddressInfo,
            config: config,
            protocolParams: protocolParams
        )
    }
    
    // MARK: - UTXO Query and Filtering
    
    /// Queries UTXOs from an address and applies filtering
    /// - Parameters:
    ///  - feePaymentAddress: The address to query UTXOs from
    ///  - context: The chain context for querying
    ///  - config: The multitool configuration
    /// - Returns: Filtered list of UTXOs
    public func queryAndFilterUtxos(
        feePaymentAddress: AddressInfo,
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
            return try await context
                .utxos(address: feePaymentAddress.address!)
        }
        
        print(noora.format("Found \(.primary("\(allUtxos.count)")) UTXOs"))
        
        // Apply filters
        var filteredUtxos = allUtxos
        
        // Filter 1: Specific UTXOs
        if !transactionOptions.utxoFilter.isEmpty {
            filteredUtxos = filteredUtxos.filter { utxo in
                transactionOptions.utxoFilter.contains(utxo.input.description)
            }
            print(noora.format("After specific UTXO filter: \(.primary("\(filteredUtxos.count)")) UTXOs"))
        }
        
        // Filter 2: Skip UTXOs with specific assets
        if !transactionOptions.skipUtxoWithAsset.isEmpty {
            filteredUtxos = filteredUtxos.filter { utxo in
                !utxo.output.amount.multiAsset.data.keys.contains(where: { (scriptHash: ScriptHash) in
                    // For each policy (script hash), see if any asset under it matches a skip filter
                    guard let assetsUnderPolicy = utxo.output.amount.multiAsset.data[scriptHash] else { return false }
                    // Iterate all skip filters and check if any matches this policy+asset name
                    return transactionOptions.skipUtxoWithAsset.contains(where: { filter in
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
        if !transactionOptions.onlyUtxoWithAsset.isEmpty {
            filteredUtxos = try filteredUtxos.filter { utxo in
                // All required assets must be present in the UTXO
                return try transactionOptions.onlyUtxoWithAsset.allSatisfy { filter in
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
        if let limit = transactionOptions.utxoLimit, filteredUtxos.count > limit {
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
    
    public func buildTransaction(
        txBuilder: TxBuilder,
        config: MultitoolConfig,
        utxos: [UTxO] = [],
        witnessOverride: Int? = nil,
        buildArgs: [String] = [],
        protocolParamsFile: FilePath,
        txRawFile: FilePath,
        txFile: FilePath,
        txSignedFile: FilePath,
        changeAddressOverride: Address? = nil
    ) async throws {
        
        guard let feePaymentAddress = transactionOptions.feePaymentAddress else {
            throw ValidationError("Fee payment address is not set.")
        }
        
        if let witnessOverride {
            txBuilder.witnessOverride = witnessOverride
        }
        
        let metadataFile = FilePath(
            FileManager
                .default
                .temporaryDirectory
                .appendingPathComponent("\(feePaymentAddress.info.name!).transactionMessage")
                .appendingPathExtension("json" )
                .path
        )
        
        let auxilliaryData = try TransactionMessage
            .buildAuxiliaryData(
                messages: transactionOptions.messages,
                encryption: transactionOptions.encryption ?? .none,
                metadataJson: transactionOptions.metadataJson,
                metadataCbor: transactionOptions.metadataCbor
            )
        if auxilliaryData != nil {
            try auxilliaryData?.saveJSON(to: metadataFile.string, overwrite: true)
        }
        
        let (tip, ttl) = try await queryChainState(
            context: txBuilder.context,
            config: config
        )
        
        try await displayChainInfo(
            context: txBuilder.context,
            tip: tip,
            ttl: ttl
        )
        
        let utxosToUse: [UTxO]
        if utxos.isEmpty {
            let filteredUtxos = try await queryAndFilterUtxos(
                feePaymentAddress: feePaymentAddress.info,
                context: txBuilder.context,
                config: config
            )
            utxosToUse = filteredUtxos
        } else {
            utxosToUse = utxos
        }
        
        try await utxoSummary(utxos: utxosToUse, config: config)
        
        if !transactionOptions.metadataJson.isEmpty {
            spacedPrint(
                "Include Metadata-File(s): "
            )
            for file in transactionOptions.metadataJson {
                print(noora.format("• \(.primary("\(file)"))"))
            }
        }
        
        if !transactionOptions.messages.isEmpty {
            if transactionOptions.encryption == .basic {
                spacedPrint(
                    "Original Transaction-Message(s): "
                )
                for message in transactionOptions.messages {
                    print(noora.format("• \(.primary("\(message)"))"))
                }
                spacedPrint(
                    "Encrypted Transaction-Message mode \(.primary("\(transactionOptions.encryption!.rawValue)")) with Passphrase \(.accent("\(transactionOptions.passphrase)"))"
                )
            }
            if auxilliaryData != nil {
                spacedPrint(
                    "Include Transaction-Message-Metadata-File: \(.path(try AbsolutePath(validating: metadataFile.string)))"
                )
            }
        }
        
        var assetsOutString = ""
        var assetsOut: MultiAsset = MultiAsset([:])
        
        for utxo in utxosToUse {
            assetsOutString += utxo.output.amount.multiAsset.toAssetsOutString()
            assetsOut.data.merge(
                utxo.output.amount.multiAsset.data
            ) { (current, _) in current }
        }
        
        let minOutUtxo = try await Utils.minLovelacePostAlonzo(
            utxosToUse[0].output,
            txBuilder.context
        )
        
        
        txBuilder.ttl = ttl
        txBuilder.auxiliaryData = auxilliaryData
        
        if transactionOptions.useCardanoCLI {
            if changeAddressOverride != nil {
                throw ValidationError("cardano-cli mode does not support sending all funds to a destination address. Remove --use-cardano-cli to use SwiftCardano instead.")
            }
            try await buildTransactionWithCardanoCLI(
                toAddress: transactionOptions.toAddress,
                feePaymentAddress: feePaymentAddress,
                config: config,
                utxos: utxosToUse,
                transactionOutputs: txBuilder.outputs,
                ttl: ttl,
                protocolParamsFile: protocolParamsFile,
                assetsOutString: assetsOutString,
                txRawFile: txRawFile,
                txFile: txFile,
                minOutUtxo: minOutUtxo,
                buildArgs: buildArgs,
                witnessCount: witnessOverride ?? 1,
                certificates: txBuilder.certificates,
                withdrawals: txBuilder.withdrawals,
                messages: transactionOptions.messages,
                metadataFile: metadataFile,
                metadataJson: transactionOptions.metadataJson,
                metadataCbor: transactionOptions.metadataCbor
            )
        } else {
            try await buildTransactionWithSwiftCardano(
                toAddress: transactionOptions.toAddress,
                feePaymentAddress: feePaymentAddress,
                txBuilder: txBuilder,
                utxos: utxosToUse,
                txFile: txFile,
                minOutUtxo: minOutUtxo,
                changeAddressOverride: changeAddressOverride
            )
        }
        
        noora.success(.alert(
            "Transaction build completed.",
            takeaways: [
                "Saved to: \(.path(try AbsolutePath(validating: txFile.string))) \n"
            ]
        ))
    }
    
    /// Builds transaction using cardano-cli
    private func buildTransactionWithCardanoCLI(
        toAddress: PaymentAddressInfo?,
        feePaymentAddress: PaymentAddressInfo,
        config: MultitoolConfig,
        utxos: [UTxO],
        transactionOutputs: [TransactionOutput],
        ttl: Int,
        protocolParamsFile: FilePath,
        assetsOutString: String,
        txRawFile: FilePath,
        txFile: FilePath,
        minOutUtxo: UInt64,
        buildArgs: [String] = [],
        witnessCount: Int = 2,
        certificates: [Certificate]? = nil,
        withdrawals: Withdrawals? = nil,
        messages: [String]? = nil,
        metadataFile: FilePath? = nil,
        metadataJson: [FilePath]? = nil,
        metadataCbor: [FilePath]? = nil
    ) async throws {
        
        spacedPrint("Using \(.primary("cardano-cli")) to build transaction...")
        
        let cli = try await CardanoCLI(
            configuration: Config(cardano: config.cardano),
            logger: getLogger(config: config)
        )
        
        // Build transaction command arguments
        var buildArgs: [String] = buildArgs
        
        // Add inputs
        for utxo in utxos {
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
        
        var rewardAccountBalance: UInt64 = 0
        if let withdrawals = withdrawals {
            for withdrawal in withdrawals.data {
                let address = try Address(from: .bytes(withdrawal.key))
                buildArgs.append("--withdrawal")
                buildArgs.append("\(address)+\(withdrawal.value)")
                rewardAccountBalance += withdrawal.value
            }
        }
        
        if let certificates = certificates {
            for certificate in certificates {
                let certFile = FilePath(
                    FileManager
                        .default
                        .temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("cert")
                        .path
                )
                try certificate.save(to: certFile.string)
                
                buildArgs.append("--certificate")
                buildArgs.append(certFile.string)
            }
        }
        
        for output in transactionOutputs {
            buildArgs.append("--tx-out")
            buildArgs.append("\(output.address)+\(output.lovelace)\(output.amount.multiAsset.toAssetsOutString())")
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
            "--witness-count", "\(witnessCount)",
            "--reference-script-size", "0"
        ])
        
        let txInCount = utxos.count
        let txOutCount = isSame ? 1 : 2
        
        spacedPrint(
            "Minimum transfer Fee for \(.primary("\(txInCount)"))x TxIn & \(.primary("\(txOutCount)"))x TxOut & Withdrawal: \(.primary("\(lovelaceToAdaString(UInt64(fee)))")) / \(.primary("\(fee)")) lovelaces "
        )
        
        let lovelacesToReturn: UInt64
        if isSame {
            lovelacesToReturn = UInt64(
                transactionOutputs.reduce(0) {
                    if $1.address == feePaymentAddress.info.address! {
                        return $0 + $1.lovelace
                    } else {
                        return $0
                    }
                }
            )
            
            spacedPrint(
                "Lovelaces that will be returned to destination Address: \(.primary("\(lovelaceToAdaFormatString(lovelacesToReturn))")) / \(.primary("\(lovelacesToReturn)")) lovelaces "
            )
        } else {
            lovelacesToReturn = UInt64(
                transactionOutputs.reduce(0) {
                    if $1.address == feePaymentAddress.info.address! {
                        return $0 + $1.lovelace
                    } else {
                        return $0
                    }
                }
            )
            
            if let toAddress = toAddress {
                let lovelacesToDestination = UInt64(
                    transactionOutputs.reduce(0) {
                        if $1.address == toAddress.info.address! {
                            return $0 + $1.lovelace
                        } else {
                            return $0
                        }
                    }
                )
                spacedPrint(
                    "Lovelaces that will be sent to the destination Address: \(.primary("\(lovelaceToAdaFormatString(UInt64(lovelacesToDestination)))")) / \(.primary("\(lovelacesToDestination)")) lovelaces "
                )
            }
            
            spacedPrint(
                "Lovelaces that will be returned to fee payment Address: \(.primary("\(lovelaceToAdaString(lovelacesToReturn))")) / \(.primary("\(lovelacesToReturn)")) lovelaces "
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
            "--out-file", txFile.string
        ])
    }
    
    /// Builds transaction using SwiftCardano
    private func buildTransactionWithSwiftCardano(
        toAddress: PaymentAddressInfo?,
        feePaymentAddress: PaymentAddressInfo,
        txBuilder: TxBuilder,
        utxos: [UTxO],
        txFile: FilePath,
        minOutUtxo: UInt64,
        changeAddressOverride: Address? = nil
    ) async throws {

        spacedPrint("Using \(.primary("swift-cardano")) to build transaction...")

        for utxo in utxos {
            txBuilder.addInput(utxo)
        }

        let txBody = try await txBuilder.build(
            changeAddress: changeAddressOverride ?? feePaymentAddress.info.address
        )
        
        let txInCount = txBody.inputs.count
        let txOutCount = txBody.outputs.count
        let fee = txBody.fee
        
        var takeaways: [TerminalText] = [
            "• Transaction Inputs: \(.primary("\(txInCount)"))",
            "• Transaction Outputs: \(.primary("\(txOutCount)"))",
        ]
        
        if let withdrawals = txBuilder.withdrawals {
            let amount = withdrawals.data.values.reduce(0, +)
            takeaways.append("• Withdrawal Amount: \(.primary("\(lovelaceToAdaFormatString(amount))")) / \(.primary("\(amount)")) lovelaces")
        }
        
        if let certificates = txBuilder.certificates {
            for certificate in certificates {
                takeaways
                    .append(
                        "• Certificates: \(.primary("\(certificate.description)"))"
                    )
            }
        }
        
        noora.info(.alert(
            "Minimum transfer Fee is \(.primary("\(lovelaceToAdaString(UInt64(fee)))")) / \(.primary("\(fee)")) lovelaces for: ",
            takeaways: takeaways
        ))
                
        let lovelacesToReturn: UInt64
        if isSame {
            lovelacesToReturn = UInt64(
                txBody.outputs.reduce(0) {
                    if $1.address == feePaymentAddress.info.address! {
                        return $0 + $1.lovelace
                    } else {
                        return $0
                    }
                }
            )
            
            spacedPrint(
                "\nLovelaces that will be returned to destination Address: \(.primary("\(lovelaceToAdaFormatString(lovelacesToReturn))")) / \(.primary("\(lovelacesToReturn)")) lovelaces "
            )
        } else {
            lovelacesToReturn = UInt64(
                txBody.outputs.reduce(0) {
                    if $1.address == feePaymentAddress.info.address! {
                        return $0 + $1.lovelace
                    } else {
                        return $0
                    }
                }
            )
            
            spacedPrint(
                "\nLovelaces that will be returned to fee payment Address: \(.primary("\(lovelaceToAdaString(lovelacesToReturn))")) / \(.primary("\(lovelacesToReturn)")) lovelaces "
            )
            
            if let toAddress = toAddress {
                let lovelacesToDestination = UInt64(
                    txBody.outputs.reduce(0) {
                        if $1.address == toAddress.info.address! {
                            return $0 + $1.lovelace
                        } else {
                            return $0
                        }
                    }
                )
                
                spacedPrint(
                    "Lovelaces that will be sent to the destination Address: \(.primary("\(lovelaceToAdaFormatString(UInt64(lovelacesToDestination)))")) / \(.primary("\(lovelacesToDestination)")) lovelaces "
                )
            }
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
        
        try tx.save(to: txFile.string, overwrite: true)
    }
}
    
