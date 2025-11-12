import Foundation
import SwiftCardanoChain
import SwiftCardanoUtils
import SwiftCardanoCore
import Logging
import Noora
import ArgumentParser
import SystemPackage


/// Get the appropriate chain context based on the multitool configuration
/// - Parameter config: The multitool configuration
/// - Returns: An instance of `ChainContext`
public func getContext(config: MultitoolConfig) async throws -> any ChainContext {
    
    func getOnlineContext(config: MultitoolConfig) async throws -> CardanoCliChainContext {
        let logger = getLogger(config: config)
        
        let cli = try await CardanoCLI(
            configuration: Config(cardano: config.cardano),
            logger: logger
        )
        
        return try await CardanoCliChainContext(cli: cli)
    }
    
    func getLiteContext(config: MultitoolConfig) async throws -> any ChainContext {
        if let blockfrostProjectId = config.blockfrostProjectId {
            return try await BlockFrostChainContext(
                projectId: blockfrostProjectId,
                network: config.cardano.network
            )
        } else if let koiosApiKey = config.koiosApiKey {
            return try await KoiosChainContext(
                apiKey: koiosApiKey,
                network: config.cardano.network
            )
        } else {
            return try await KoiosChainContext(
                network: config.cardano.network
            )
        }
    }
    
    switch config.mode {
        case .auto:
            do {
                let cliContext = try await getOnlineContext(config: config)
                try await cliContext.cli.checkOnline()
                
                return cliContext
            }
            catch {
                noora.warning(
                    .alert(
                        "\(.danger("The node is not synced."))",
                        takeaway: "Falling back to \(.primary("Lite")) mode."
                    )
                )
                
                return try await getLiteContext(config: config)
            }
        case .online:
            return try await getOnlineContext(config: config)
        case .lite:
            return try await getLiteContext(config: config)
        case .offline:
            throw SwiftCardanoMultitoolError.notImplemented
            
    }
}

public func stakeAddressInfoSummary(
    stakeAddressInfo: [SwiftCardanoCore.StakeAddressInfo],
    config: MultitoolConfig,
    protocolParams: ProtocolParameters
) async throws {
    let entries = stakeAddressInfo.count
    let entryStr = entries == 1 ? "entry" : "entries"
    spacedPrint(
        "\(.success("\(entries) \(entryStr)")) found for the Stake Address!"
    )
    
    // Build StakeAddressInfo table data
    let headers: [TableCellStyle] = [
        .plain("Index"),
        .primary("Rewards"),
        .primary("Delegated to Pool")
    ]
    
    var rows: [StyledTableRow] = []
    
    for (idx, info) in stakeAddressInfo.enumerated() {
        let stakeDelegation: TableCellStyle
        
        if info.stakeDelegation == nil {
            stakeDelegation = .danger("✗ Not Delegated")
        } else {
            stakeDelegation = .primary(try info.stakeDelegation!.id())
        }
            
        rows.append([
            .plain("\(idx + 1)"),
            .primary("\(lovelaceToAdaString(UInt64(info.rewardAccountBalance))) (\(info.rewardAccountBalance) lovelaces)"),
            stakeDelegation
        ])
    }
    
    noora.table(headers: headers, rows: rows)
    
    guard !stakeAddressInfo.isEmpty,
          let stakeAddressInfo = stakeAddressInfo.first else {
        noora.error(.alert(
            "Stake Registration: \(.danger("✗ Not Registered"))",
            takeaways: [
                "Register the stake address before withdrawing rewards.",
                "Use 'generate stake-address-registration' command to register."
            ]
        ))
        throw ExitCode.failure
    }
    
    spacedPrint(
        "\nStaking Address is \(.success("✓ Registered")) on the chain with a deposit of \(.primary("\(stakeAddressInfo.stakeRegistrationDeposit ?? 0)")) lovelaces"
    )
    
    if stakeAddressInfo.rewardAccountBalance == 0 {
        noora.warning(.alert(
            "Rewards Balance: \(.danger("0 lovelaces"))",
            takeaway: "No rewards available to withdraw. Wait for rewards to accumulate before claiming."
            
        ))
    } else {
        spacedPrint(
            "Rewards Balance: \(.primary(lovelaceToAdaString(UInt64(stakeAddressInfo.rewardAccountBalance)))) \(.muted("(\(stakeAddressInfo.rewardAccountBalance) lovelaces)"))"
        )
    }
    
    
    // If delegated to a pool, show the current pool ID
    if let poolOperator = stakeAddressInfo.stakeDelegation {
        spacedPrint(
            "\nAccount is delegated to a Pool with ID: \(.primary(try poolOperator.id()))"
        )
        
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
                    "Status: \(poolDetails.poolStatus!)",
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
        spacedPrint(
            "\(.danger("Account is not delegated to a Pool."))"
        )
    }
    
    
    // Show the current status of the voteDelegation
    if let voteDelegation = stakeAddressInfo.voteDelegation {
        
        spacedPrint(
            "\nDRep Delegation: \(.success("✓ Delegated"))"
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
            case .scriptHash(_):
                noora.info(.alert(
                    "Voting-Power of Staking Address is delegated to the following DRep-Script:",
                    takeaways: [
                        "CIP129 DRep-ID: \(.primary(try voteDelegation.id((.bech32, .cip129))))",
                        "Legacy DRep-ID: \(.primary(try voteDelegation.id((.bech32, .cip105))))",
                        "DRep-HASH: \(.primary(try voteDelegation.id((.hex, .cip105))))",
                    ]
                ))
            case .verificationKeyHash(_):
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
        
        spacedPrint(
            "\(.danger("Voting-Power of Staking Address is not delegated to a DRep."))"
        )
        
        if protocolParams.protocolVersion.major >= 10 {
            noora.warning(.alert(
                "\(.danger("⚠️  You need to delegate your stake account to a DRep in order to claim your rewards!"))",
                takeaway: "Run the appropriate generate and register command to delegate your stake account to a DRep."
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
    
}

/// Display a summary of UTXOs
/// - Parameters:
///   - utxos: Array of UTXOs to summarize
///   - config: The multitool configuration
///   - queryTokenRegistry: Whether to query the token registry for asset metadata (not yet implemented)
public func utxoSummary(
    utxos: [UTxO],
    config: MultitoolConfig,
    queryTokenRegistry: Bool = false
) async throws {
    let utxoStr = utxos.count == 1 ? "UTxO" : "UTxOs"
    spacedPrint(
        "\(.success("\(utxos.count) \(utxoStr)")) found on the Source Address!"
    )
    
    // Calculate total lovelaces
    let totalLovelaces = utxos.reduce(0) { $0 + UInt64($1.output.amount.coin) }
    
    // Collect all assets
    struct AssetInfo {
        let policyId: String
        let assetName: String
        let amount: Int
        let assetType: AssetType
        
        enum AssetType {
            case adaHandleCIP68(String)      // $adahandle cip-68 (Own)
            case adaHandleVirtual(String)    // $adahandle virtual
            case adaHandleReference(String)  // $adahandle reference
            case adaHandleCIP25(String)      // $adahandle cip-25
            case standard                     // regular asset
            
            var displayName: String {
                switch self {
                case .adaHandleCIP68(let handle):
                    return "ADA Handle(Own): $\(handle)"
                case .adaHandleVirtual(let handle):
                    return "ADA Handle(Vir): $\(handle)"
                case .adaHandleReference(let handle):
                    return "ADA Handle(Ref): $\(handle)"
                case .adaHandleCIP25(let handle):
                    return "ADA Handle: $\(handle)"
                case .standard:
                    return ""
                }
            }
        }
        
        var fingerprint: String {
            // Simple representation - full implementation would need bech32 encoding
            return "\(policyId).\(assetName)"
        }
    }
    
    var allAssets: [AssetInfo] = []
    var allPolicyIds: Set<String> = []
    
    // Build UTxO table data
    let utxoHeaders: [TableCellStyle] = [
        .primary("Idx"),
        .primary("Hash"),
        .primary("Amount"),
        .primary("URL"),
    ]
    
    var utxoRows: [StyledTableRow] = []
    
    for utxo in utxos {
        let output = utxo.output
        let txHash = utxo.input.transactionId.description
        let index = utxo.input.index
        
        var amountDisplay = lovelaceToAdaFormatString(UInt64(output.amount.coin))
        
        // Add datum hash info if present
        if let datumHash = output.datumHash {
            amountDisplay += "\nDatumHash: \(datumHash.description)"
        }
        
        let amount = output.amount
        
        // Process multi-assets
        if !amount.multiAsset.isEmpty {
            for (policyId, assets) in amount.multiAsset.data {
                let policyIdHex = policyId.description
                allPolicyIds.insert(policyIdHex)
                
                for (assetName, assetAmount) in assets.data.elements {
                    let assetNameHex = assetName.description
                    let assetNameBytes = assetName.payload
                    let assetNameStr: String
                    
                    // Try to decode as UTF-8, otherwise use hex
                    if let decoded = String(data: assetNameBytes, encoding: .utf8) {
                        assetNameStr = decoded
                    } else {
                        assetNameStr = assetNameHex
                    }
                    
                    // Detect asset type and handle ADA Handle variants
                    let assetType: AssetInfo.AssetType
                    var displayText = ""
                    
                    if let adaHandlePolicyId = config.adaHandlePolicy.forNetwork(
                        config.cardano.network
                    ),
                       policyIdHex == adaHandlePolicyId {
                        
                        // Check for ADA Handle variants based on prefix (first 8 hex chars)
                        let prefix = assetNameHex.prefix(8)
                        
                        switch prefix {
                        case "000de140":  // CIP-68 (Own)
                            let handleName = String(assetNameHex.dropFirst(8))
                            let handleBytes = Data(hex: handleName)
                            if let handleStr = String(data: handleBytes, encoding: .utf8) {
                                assetType = .adaHandleCIP68(handleStr)
                                displayText = "\nAsset: \(policyIdHex).\(assetNameHex)  \(assetType.displayName)"
                            } else {
                                assetType = .standard
                                displayText = "\nAsset: \(policyIdHex).\(assetNameHex)  Amount: \(assetAmount) \(assetNameStr)"
                            }
                            
                        case "00000000":  // Virtual
                            let handleName = String(assetNameHex.dropFirst(8))
                            let handleBytes = Data(hex: handleName)
                            if let handleStr = String(data: handleBytes, encoding: .utf8) {
                                assetType = .adaHandleVirtual(handleStr)
                                displayText = "\nAsset: \(policyIdHex).\(assetNameHex)  \(assetType.displayName)"
                            } else {
                                assetType = .standard
                                displayText = "\nAsset: \(policyIdHex).\(assetNameHex)  Amount: \(assetAmount) \(assetNameStr)"
                            }
                            
                        case "000643b0":  // Reference
                            let handleName = String(assetNameHex.dropFirst(8))
                            let handleBytes = Data(hex: handleName)
                            if let handleStr = String(data: handleBytes, encoding: .utf8) {
                                assetType = .adaHandleReference(handleStr)
                                displayText = "\nAsset: \(policyIdHex).\(assetNameHex)  \(assetType.displayName)"
                            } else {
                                assetType = .standard
                                displayText = "\nAsset: \(policyIdHex).\(assetNameHex)  Amount: \(assetAmount) \(assetNameStr)"
                            }
                            
                        default:  // CIP-25 (standard ADA Handle)
                            let handleBytes = Data(hex: assetNameHex)
                            if let handleStr = String(data: handleBytes, encoding: .utf8) {
                                assetType = .adaHandleCIP25(handleStr)
                                displayText = "\nAsset: \(policyIdHex).\(assetNameHex)  \(assetType.displayName)"
                            } else {
                                assetType = .standard
                                displayText = "\nAsset: \(policyIdHex).\(assetNameHex)  Amount: \(assetAmount) \(assetNameStr)"
                            }
                        }
                    } else {
                        // Regular asset
                        assetType = .standard
                        displayText = "\nAsset: \(policyIdHex).\(assetNameHex)  Amount: \(assetAmount) \(assetNameStr)"
                    }
                    
                    allAssets.append(AssetInfo(
                        policyId: policyIdHex,
                        assetName: assetNameHex,
                        amount: Int(assetAmount),
                        assetType: assetType
                    ))
                    
                    amountDisplay += displayText
                }
            }
        }
        
        // Build transaction explorer URL
        let explorerUrl: String
        let explorer = config.blockchainExplorer.explorer()
        do {
            let url = try explorer.viewTransaction(
                txHash: txHash,
                network: config.cardano.network
            )
            explorerUrl = url.absoluteString
        } catch {
            explorerUrl = txHash
        }
        
        utxoRows.append([
            .plain("\(index)"),
            .primary(txHash),
            .success(amountDisplay),
            .muted(explorerUrl)
        ])
    }
    
    // Display UTxO table
    noora.table(headers: utxoHeaders, rows: utxoRows)
    
    spacedPrint(
        "Total ADA on the Address: \(.success("\(lovelaceToAdaString(totalLovelaces)) / \(totalLovelaces) lovelaces"))"
    )
    
    // Display asset summary if any assets found
    if !allAssets.isEmpty {
        spacedPrint(
            "\(.success("\(allAssets.count) Asset-Type(s) / \(allPolicyIds.count) different PolicyIDs")) found on the Address!"
        )
        
        // Build asset table data
        let assetHeaders: [TableCellStyle] = [
            .primary("PolicyID"),
            .primary("Asset-Name"),
            .primary("Total-Amount"),
            .primary("Fingerprint")
        ]
        
        var assetRows: [StyledTableRow] = []
        
        for asset in allAssets {
            let assetNameDisplay: String
            let cellStyle: TableCellStyle
            
            // Display asset name based on type
            switch asset.assetType {
            case .adaHandleCIP68(let handle):
                assetNameDisplay = "$\(handle)"
                cellStyle = .accent("\(assetNameDisplay) - \(asset.assetType.displayName)")
                
            case .adaHandleVirtual(let handle):
                assetNameDisplay = "$\(handle)"
                cellStyle = .accent("\(assetNameDisplay) - \(asset.assetType.displayName)")
                
            case .adaHandleReference(let handle):
                assetNameDisplay = "$\(handle)"
                cellStyle = .accent("\(assetNameDisplay) - \(asset.assetType.displayName)")
                
            case .adaHandleCIP25(let handle):
                assetNameDisplay = "$\(handle)"
                cellStyle = .accent("\(assetNameDisplay) - \(asset.assetType.displayName)")
                
            case .standard:
                let assetNameBytes = asset.assetName.hexStringToData
                if let decoded = String(data: assetNameBytes, encoding: .utf8) {
                    assetNameDisplay = decoded
                } else {
                    assetNameDisplay = asset.assetName
                }
                cellStyle = .plain(assetNameDisplay)
            }
            
            assetRows.append([
                .muted(asset.policyId),
                cellStyle,
                .success("\(asset.amount)"),
                .muted(asset.fingerprint)
            ])
        }
        
        // Display asset table
        print()
        noora.table(headers: assetHeaders, rows: assetRows)
        print()
    }
}

/// Display version and network info
/// - Parameter config: The multitool configuration
public func printInfo(
    config: MultitoolConfig,
    context: any ChainContext
) async throws -> Void {
    let infoString: TerminalText
    if config.cardano.network == .mainnet {
        infoString = "\(.success("\(config.cardano.network.description.capitalized)"))"
    } else {
        guard let testnetMagic = config.cardano.network.testnetMagic else {
            throw SwiftCardanoMultitoolError.invalidConfiguration(
                "Testnet magic number is required for testnet networks."
            )
        }
        infoString = "\(.danger("Testnet: \(config.cardano.network.description.capitalized)")) \(.danger("(magic \(testnetMagic))"))"
    }
    
    guard let version = SwiftCardanoMultitool.version else {
        throw SwiftCardanoMultitoolError.invalidConfiguration(
            "Unable to retrieve SwiftCardanoMultitool version."
        )
    }
    
    var takeaways: [TerminalText] = [
        "Chain Context: \(.primary("\(context.name)"))",
        "Scripts-Mode: \(.accent("\(config.mode.rawValue.capitalized)"))",
        "Platform: \(.info(ProcessInfo.processInfo.operatingSystemVersionString))",
        infoString
    ]
    
    if let _ = context as? CardanoCliChainContext {
        
        let cli = try await CardanoCLI(
            configuration: config.toSwiftCardanoUtilsConfig()
        )
        
        let node = try await CardanoNode(
            configuration: config.toSwiftCardanoUtilsConfig()
        )
        
        let cliVersion = try await cli.version()
        let nodeVersion = try await node.version()
        
        takeaways.append("Cardano-CLI: \(.primary(cliVersion))")
        takeaways.append("Cardano-Node: \(.primary(nodeVersion))")
    }
        
    
    noora.info(
        .alert(
            "SwiftCardanoMultitool v\(version)",
            takeaways: takeaways
        )
    )
    spacedPrint("")
}

// MARK: - Get Current Protocol Parameters

/// Retrieves the current protocol parameters from the chain context and saves them to a file
/// - Parameters:
///   - context: The chain context to use for querying protocol parameters
///   - protocolParamsFile: The file path to save protocol parameters
/// - Returns: The retrieved protocol parameters
public func getProtocolParameters(
    context: any ChainContext,
    protocolParamsFile: FilePath? = nil
) async throws -> ProtocolParameters {
    let protocolParams = try await noora.progressStep(
        message: "Querying protocol parameters...",
        successMessage: "Successfully retrieved protocol parameters.",
        errorMessage: "Failed to retrieve protocol parameters.",
        showSpinner: true
    ) { updateMessage in
        return try await context.protocolParameters()
    }
    
    if let protocolParamsFile = protocolParamsFile {
        try protocolParams.save(to: protocolParamsFile.string, overwrite: true)
    }
    
    return protocolParams
}

// MARK: - Chain State Querying

/// Queries chain state for stake address info
/// - Parameters:
///   - context: The chain context to use for querying
///   - config: The multitool configuration
///   - protocolParamsFile: The file path to save protocol parameters
/// - Returns: A tuple containing the current tip, calculated TTL, and protocol parameters
public func queryChainState(
    context: any ChainContext,
    config: MultitoolConfig,
) async throws -> (tip: Int, ttl: Int) {
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
    
    return (tip, ttl)
}

/// Displays chain info to the user
/// - Parameters:
///   - context: The chain context to use for querying
///   - tip: The current tip of the blockchain
///   - ttl: The calculated TTL value
public func displayChainInfo(
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
        "Current Epoch: ~\(try await context.epoch())"
    )
}

/// Checks the size of the transaction against protocol limits
/// - Parameters:
///  - transaction: The transaction to check
///  - protocolParameters: The protocol parameters containing size limits
/// - Throws: ExitCode.failure if the transaction exceeds size limits
public func checkTransactionSize(
    transaction: Transaction,
    protocolParameters: ProtocolParameters
) throws -> Void {
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
        spacedPrint(
            "\nTransaction size: \(.primary("\(txSize) bytes")) (within the limit of \(maxTxSize) bytes)"
        )
    }
}
