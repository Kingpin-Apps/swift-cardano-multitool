import Foundation
import SwiftCardanoChain
import SwiftCardanoUtils
import Logging

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
            spacedPrint(
                "Using \(.primary("Blockfrost"))."
            )
            
            return try await BlockFrostChainContext(
                projectId: blockfrostProjectId,
                network: config.cardano.network
            )
        } else if let koiosApiKey = config.koiosApiKey {
            spacedPrint(
                "Using \(.primary("Koios")) with API Key."
            )
            
            return try await KoiosChainContext(
                apiKey: koiosApiKey,
                network: config.cardano.network
            )
        } else {
            spacedPrint(
                "Using \(.primary("Koios")) with no API Key."
            )
            
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
                
                spacedPrint(
                    "Using \(.primary("Cardano-CLI"))."
                )
                
                return cliContext
            }
            catch {
                noora.warning(
                    .alert("\(.danger("The node is not synced."))")
                )
                
                spacedPrint(
                    "\nFalling back to \(.primary("Lite")) mode."
                )
                
                return try await getLiteContext(config: config)
            }
        case .online:
            spacedPrint(
                "Using \(.primary("Cardano-CLI"))."
            )
            return try await getOnlineContext(config: config)
        case .lite:
            return try await getLiteContext(config: config)
        case .offline:
            throw SwiftCardanoMultitoolError.notImplemented
            
    }
}
