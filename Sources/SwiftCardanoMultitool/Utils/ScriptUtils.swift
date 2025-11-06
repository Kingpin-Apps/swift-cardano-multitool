import Foundation
import SwiftCardanoChain
import SwiftCardanoUtils
import SwiftCardanoCore
import Logging
import Noora

/// Get the appropriate chain context based on the multitool configuration
/// - Parameter config: The multitool configuration
/// - Returns: An instance of `ChainContext`
public func getContext(config: MultitoolConfig) async throws -> any ChainContext {
    
    func getOnlineContext(config: MultitoolConfig) async throws -> CardanoCliChainContext {
        var logger = Logger(
            label: CardanoCLI.binaryName,
            factory: { label in
                OSLogHandler(subsystem: "com.swift-cardano-multitool", category: label)
            }
        )
        logger.logLevel = config.logLevel ?? .error
        
        let cli = try await CardanoCLI(
            configuration: Config(cardano: config.cardano),
            logger: logger
        )
        
        return try await CardanoCliChainContext(cli: cli)
    }
    
    func getLiteContext(config: MultitoolConfig) async throws -> any ChainContext {
        if let blockfrostProjectId = config.blockfrostProjectId {
//            spacedPrint(
//                "Using \(.primary("Blockfrost"))."
//            )
            
            return try await BlockFrostChainContext(
                projectId: blockfrostProjectId,
                network: config.cardano.network
            )
        } else if let koiosApiKey = config.koiosApiKey {
//            spacedPrint(
//                "Using \(.primary("Koios")) with API Key."
//            )
            
            return try await KoiosChainContext(
                apiKey: koiosApiKey,
                network: config.cardano.network
            )
        } else {
//            spacedPrint(
//                "Using \(.primary("Koios")) with no API Key."
//            )
            
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
                
//                spacedPrint(
//                    "Using \(.primary("Cardano-CLI"))."
//                )
                
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
//            spacedPrint(
//                "Using \(.primary("Cardano-CLI"))."
//            )
            return try await getOnlineContext(config: config)
        case .lite:
            return try await getLiteContext(config: config)
        case .offline:
            throw SwiftCardanoMultitoolError.notImplemented
            
    }
}

public func stakeAddressInfoSummary(
    stakeAddressInfo: [StakeAddressInfo],
    config: MultitoolConfig,
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
        rows.append([
            .plain("\(idx + 1)"),
            .primary("\(lovelaceToAdaString(UInt64(info.rewardAccountBalance))) (\(info.rewardAccountBalance) lovelaces)"),
            .primary(try info.stakeDelegation!.id())
        ])
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
    
    noora.info(
        .alert(
            "SwiftCardanoMultitool v\(version)",
            takeaways: [
                "Chain Context: \(.primary("\(context.name)"))",
                "Scripts-Mode: \(.accent("\(config.mode.rawValue.capitalized)"))",
                infoString
            ]
        )
    )
    spacedPrint("")
}
