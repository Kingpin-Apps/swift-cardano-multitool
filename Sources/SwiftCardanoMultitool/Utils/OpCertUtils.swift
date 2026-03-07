import Foundation
import ArgumentParser
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoChain

/// Result of an operational certificate check.
public struct OpCertCheckResult {
    /// Whether the KES interval is valid (within range).
    public let kesIntervalValid: Bool
    
    /// Whether the opcert counter is valid for the specified usage (current or next).
    public let counterValid: Bool
    
    /// The next chain opcert counter that should be used.
    public let nextChainOpCertCount: Int
    
    /// Combined validity - true only if both KES interval and counter are valid.
    public var isValid: Bool {
        kesIntervalValid && counterValid
    }
}

/// Utilities for checking and validating operational certificates.
public struct OpCertUtils {
    
    // MARK: - Check Local OpCert
    
    /// Checks a local operational certificate file for correct OpCertCounter and KES-Interval.
    ///
    /// This function queries the chain to validate that:
    /// 1. The KES period in the certificate is within the valid range
    /// 2. The opcert counter matches expectations for current or next usage
    ///
    /// - Parameters:
    ///   - config: The multitool configuration.
    ///   - opCertFile: Path to the operational certificate file.
    ///   - which: Whether to check for current or next usage.
    /// - Returns: A tuple containing (isValid, nextChainOpCertCount).
    /// - Throws: `ExitCode.failure` if in offline mode or if required parameters are missing.
    public static func checkLocalOpCert(
        config: MultitoolConfig,
        opCertFile: FilePath,
        which: WhichPeriod
    ) async throws -> OpCertCheckResult {
        guard config.mode != .offline else {
            noora.error(.alert(
                "Cannot check local operational certificate in offline mode.",
                takeaways: [
                    "Switch to online or lite mode to check the operational certificate.",
                    "Use 'config select' to change the mode."
                ]
            ))
            throw ExitCode.failure
        }
        
        spacedPrint("\nChecking OpCertFile \(.primary(opCertFile.lastComponent?.string ?? opCertFile.string)) for the correct OpCertCounter and KES-Interval:\n")
        
        let context = try await getContext(config: config)
        
        let cardanoConfig = try getCardanoConfig(config: config)
        
        guard let cardanoConfigPath = cardanoConfig.config else {
            noora.error(.alert(
                "Cardano configuration file path not found in multitool config.",
                takeaways: [
                    "Make sure the cardano configuration file path is set in the multitool config.",
                    "You can set it using the 'config select' command."
                ]
            ))
            throw ExitCode.validationFailure
        }
        
        let genesisParameters = try GenesisParameters(
            nodeConfigFilePath: cardanoConfigPath.string
        )
        
        guard let shelleyGenesis = genesisParameters.shelleyGenesis else {
            noora.error(.alert(
                "Shelley genesis parameters not found in cardano configuration file.",
                takeaways: [
                    "Make sure the cardano configuration file contains the shelley genesis parameters."
                ]
            ))
            throw ExitCode.validationFailure
        }
        
        // Get chain state
        let currentSlot = try await context.lastBlockSlot()
        let currentEpoch = try await context.epoch()
        
        // Genesis parameters
        let maxKESEvolutions = Int(shelleyGenesis.maxKESEvolutions)
        let slotLength = Int(shelleyGenesis.slotLength)
        let slotsPerKESPeriod = Int(shelleyGenesis.slotsPerKESPeriod)
        
        // Calculate current KES period
        let currentKESPeriod = max(currentSlot / (slotsPerKESPeriod * slotLength), 0)
        
        spacedPrint("Current EPOCH: \(.success("\(currentEpoch)"))\n")
        
        // Load the operational certificate
        let opCert = try OperationalCertificate.load(from: opCertFile.string)
        
        // Query KES period info from chain
        let kesPeriodInfo = try await context.kesPeriodInfo(pool: nil, opCert: opCert)
        
        guard let nextChainOpCertCount = kesPeriodInfo.nextChainOpCertCount,
              let onChainOpCertCount = kesPeriodInfo.onChainOpCertCount,
              let onDiskOpCertCount = kesPeriodInfo.onDiskOpCertCount,
              let onDiskKESStart = kesPeriodInfo.onDiskKESStart else {
            noora.error(.alert(
                "Failed to retrieve KES period information from chain.",
                takeaways: [
                    "Make sure the node is fully synced.",
                    "Check that the operational certificate file is valid."
                ]
            ))
            throw ExitCode.failure
        }
        
        // Check KES interval
        let kesIntervalValid = checkKESInterval(
            onDiskKESStart: onDiskKESStart,
            currentKESPeriod: currentKESPeriod,
            maxKESEvolutions: maxKESEvolutions,
            slotsPerKESPeriod: slotsPerKESPeriod,
            slotLength: slotLength,
            currentSlot: currentSlot
        )
        
        // Check opcert counter based on which period we're checking
        let counterValid: Bool
        switch which {
            case .next:
                counterValid = checkOpCertCounterForNext(
                    nextChainOpCertCount: nextChainOpCertCount,
                    onChainOpCertCount: onChainOpCertCount,
                    onDiskOpCertCount: onDiskOpCertCount,
                    kesError: !kesIntervalValid
                )
            case .current:
                counterValid = checkOpCertCounterForCurrent(
                    nextChainOpCertCount: nextChainOpCertCount,
                    onChainOpCertCount: onChainOpCertCount,
                    onDiskOpCertCount: onDiskOpCertCount,
                    kesError: !kesIntervalValid
                )
        }
        
        return OpCertCheckResult(
            kesIntervalValid: kesIntervalValid,
            counterValid: counterValid,
            nextChainOpCertCount: nextChainOpCertCount
        )
    }
    
    // MARK: - Check Pool ID
    
    /// Checks the opcert counter for a pool via its pool ID.
    ///
    /// This function queries pool information from the chain (via Koios or similar)
    /// to retrieve the current opcert counter and advise on the next counter to use.
    ///
    /// - Parameters:
    ///   - config: The multitool configuration.
    ///   - poolOperator: The pool operator object
    /// - Throws: `ExitCode.failure` if in offline mode or if the pool cannot be found.
    public static func checkPoolID(
        config: MultitoolConfig,
        poolOperator: PoolOperator
    ) async throws {
        guard config.mode != .offline else {
            noora.error(.alert(
                "Cannot check pool ID in offline mode.",
                takeaways: [
                    "Switch to online or lite mode to query pool information.",
                    "Use 'config select' to change the mode."
                ]
            ))
            throw ExitCode.failure
        }
        
        spacedPrint(
            "\nChecking the OpCertCounter for Pool-ID \(.primary(poolOperator.description)):\n"
        )
        
        let context = try await getContext(config: config)
        
        // Query pool info
        let poolInfo = try await noora.progressStep(
            message: "Querying Pool-Info...",
            successMessage: "Successfully retrieved pool information.",
            errorMessage: "Failed to retrieve pool information.",
            showSpinner: true
        ) { _ in
            try await context.stakePoolInfo(poolId: poolOperator.id(.bech32))
        }
        
        // Query KES period info from chain
        let kesPeiodinfo = try await noora.progressStep(
            message: "Querying KES-Period-Info...",
            successMessage: "Successfully retrieved info.",
            errorMessage: "Failed to retrieve info.",
            showSpinner: true
        ) { _ in
            return try await context.kesPeriodInfo(pool: poolOperator, opCert: nil)
        }
        
        let poolName = poolInfo.poolParams.poolMetadata?.name ?? "Unknown"
        let poolTicker = poolInfo.poolParams.poolMetadata?.ticker ?? "???"
        
        spacedPrint("Got the information back for the Pool: \(.success("\(poolName) (\(poolTicker))"))\n")
        
        if let opCertCounter = kesPeiodinfo.onChainOpCertCount {
            let counterValue = Int(opCertCounter)
            
            spacedPrint("The last known OpCertCounter on the chain is: \(.success("\(counterValue)"))\n")
            
            let nextChainOpCertCount = counterValue + 1
            
            noora.info(.alert(
                "Next OpCert Counter Recommendation",
                takeaways: [
                    "If you want to create a new OpCert on an offline machine,",
                    "you should use the counter \(nextChainOpCertCount) for your next one:",
                    "",
                    "  scm generate kes-keys --pool-name <poolName>",
                    "  scm generate node-operational-certificate --pool-name <poolName> --use-opcert-counter \(nextChainOpCertCount)"
                ]
            ))
        } else {
            noora.info(.alert(
                "No OpCertCounter Information Available",
                takeaways: [
                    "There is no information available from the chain about the OpCertCounter.",
                    "Looks like the pool has not made a block yet.",
                    "Your current OpCertCounter should be set to 0."
                ]
            ))
        }
    }
    
    // MARK: - Private Helpers
    
    /// Checks if the KES interval is valid and prints status.
    private static func checkKESInterval(
        onDiskKESStart: Int,
        currentKESPeriod: Int,
        maxKESEvolutions: Int,
        slotsPerKESPeriod: Int,
        slotLength: Int,
        currentSlot: Int
    ) -> Bool {
        let expireKESPeriod = onDiskKESStart + maxKESEvolutions
        
        print(noora.format("KES-Interval Check: "), terminator: "")
        
        if onDiskKESStart <= currentKESPeriod && currentKESPeriod < expireKESPeriod {
            // Valid - within range
            print(noora.format("\(.success("OK, within range"))\n"))
            
            spacedPrint("    Current KES Period: \(.success("\(currentKESPeriod)"))")
            spacedPrint(" File KES start Period: \(.success("\(onDiskKESStart)"))")
            spacedPrint("File KES expiry Period: \(.success("\(expireKESPeriod)"))")
            
            // Calculate time until expiry
            let expireInSecs = (expireKESPeriod * slotsPerKESPeriod * slotLength) - currentSlot
            let expireFormatted = formatDuration(seconds: expireInSecs)
            
            let style: TerminalStyleCode
            if expireInSecs < 604800 { // less than a week
                style = .danger
            } else if expireInSecs < 1814400 { // less than 3 weeks
                style = .warningStyle
            } else {
                style = .success
            }
            
            spacedPrint("   File KES expires in: \(style.style(expireFormatted))\n")
            return true
        } else {
            // Invalid - out of range
            print(noora.format("\(.danger("FALSE, out of range!"))\n"))
            
            formatPrint("    Current KES Period: \(.success("\(currentKESPeriod)"))")
            formatPrint(" File KES start Period: \(.danger("\(onDiskKESStart)"))")
            formatPrint("File KES expiry Period: \(.danger("\(expireKESPeriod)"))")
            
            // Calculate how long ago it expired
            let expiredBeforeSecs = currentSlot - (expireKESPeriod * slotsPerKESPeriod * slotLength)
            let expiredFormatted = formatDuration(seconds: expiredBeforeSecs)
            
            formatPrint("File KES expired before: \(.danger(expiredFormatted))\n")
            return false
        }
    }
    
    /// Checks the opcert counter for NEXT usage.
    private static func checkOpCertCounterForNext(
        nextChainOpCertCount: Int,
        onChainOpCertCount: Int,
        onDiskOpCertCount: Int,
        kesError: Bool
    ) -> Bool {
        print(noora.format("OpCertCounter Check - For NEXT usage: "), terminator: "")
        
        let onChainDisplay = onChainOpCertCount == -1 ? "not used yet" : "\(onChainOpCertCount)"
        
        if nextChainOpCertCount == onDiskOpCertCount {
            formatPrint("\(.success("OK, is latest+1"))\n")
            formatPrint("Latest OnChain Counter: \(.success(onChainDisplay))")
            formatPrint("Next Counter should be: \(.success("\(nextChainOpCertCount)"))")
            formatPrint("       File Counter is: \(.success("\(onDiskOpCertCount)"))\n")
            
            if kesError {
                noora.warning(.alert(
                    "Please generate a new OpCertFile with the same CounterNumber \(nextChainOpCertCount) because of the KES-Error.",
                    takeaway: "Run: scm generate kes-keys --pool-name <poolName> && scm generate node-operational-certificate --pool-name <poolName> --use-opcert-counter \(nextChainOpCertCount)"
                ))
            }
            return true
        } else {
            formatPrint("\(.danger("FALSE, is not latest+1!"))\n")
            formatPrint("Latest OnChain Counter: \(.success(onChainDisplay))")
            formatPrint("Next Counter should be: \(.danger("\(nextChainOpCertCount)"))")
            formatPrint("       File Counter is: \(.danger("\(onDiskOpCertCount)"))\n")
            
            noora.warning(.alert(
                "Please use the CounterNumber \(nextChainOpCertCount) to generate a correct new OpCertFile.",
                takeaway: "Run: scm generate kes-keys --pool-name <poolName> && scm generate node-operational-certificate --pool-name <poolName> --use-opcert-counter \(nextChainOpCertCount)"
            ))
            return false
        }
    }
    
    /// Checks the opcert counter for CURRENT usage.
    private static func checkOpCertCounterForCurrent(
        nextChainOpCertCount: Int,
        onChainOpCertCount: Int,
        onDiskOpCertCount: Int,
        kesError: Bool
    ) -> Bool {
        print(noora.format("OpCertCounter Check - CURRENTLY used: "), terminator: "")
        
        let onChainDisplay = onChainOpCertCount == -1 ? "not used yet" : "\(onChainOpCertCount)"
        
        if onChainOpCertCount == -1 && onDiskOpCertCount == 0 {
            // No block generated yet
            formatPrint("\(.success("OK, no block generated yet. File Counter 0 is the right current one."))\n")
            formatPrint("  Latest OnChain Counter: \(.success(onChainDisplay))")
            formatPrint("         File Counter is: \(.success("\(onDiskOpCertCount)"))")
            formatPrint("  Next Counter should be: \(.success("\(nextChainOpCertCount)"))\n")
            
            if kesError {
                noora.warning(.alert(
                    "Please generate a new OpCertFile with the next CounterNumber \(nextChainOpCertCount) because of the KES-Error.",
                    takeaway: "Run: scm generate kes-keys --pool-name <poolName> && scm generate node-operational-certificate --pool-name <poolName> --use-opcert-counter \(nextChainOpCertCount)"
                ))
            }
            return true
        } else if onChainOpCertCount == onDiskOpCertCount {
            // Counters are equal
            formatPrint("\(.success("OK, current File Counter matches the onChain one."))\n")
            formatPrint("Latest OnChain Counter: \(.success(onChainDisplay))")
            formatPrint("       File Counter is: \(.success("\(onDiskOpCertCount)"))")
            formatPrint("Next Counter should be: \(.success("\(nextChainOpCertCount)"))\n")
            
            if kesError {
                noora.warning(.alert(
                    "Please generate a new OpCertFile with the next CounterNumber \(nextChainOpCertCount) because of the KES-Error.",
                    takeaway: "Run: scm generate kes-keys --pool-name <poolName> && scm generate node-operational-certificate --pool-name <poolName> --use-opcert-counter \(nextChainOpCertCount)"
                ))
            }
            return true
        } else {
            // Counters are not equal
            print(noora.format("\(.danger("FALSE, OnChain Counter NOT equal to File Counter"))\n"))
            spacedPrint("Latest OnChain Counter: \(.success(onChainDisplay))")
            spacedPrint("       File Counter is: \(.danger("\(onDiskOpCertCount)"))\n")
            return false
        }
    }
    
    /// Formats a duration in seconds to a human-readable string.
    private static func formatDuration(seconds: Int) -> String {
        let absSeconds = abs(seconds)
        let days = absSeconds / 86400
        let hours = (absSeconds % 86400) / 3600
        let minutes = (absSeconds % 3600) / 60
        
        var parts: [String] = []
        
        if days > 0 {
            parts.append("\(days) day\(days == 1 ? "" : "s")")
        }
        if hours > 0 {
            parts.append("\(hours) hour\(hours == 1 ? "" : "s")")
        }
        if minutes > 0 && days == 0 {
            parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")")
        }
        
        if parts.isEmpty {
            return "less than a minute"
        }
        
        return parts.joined(separator: ", ")
    }
}

// MARK: - Terminal Style Helper

/// Helper enum for consistent terminal styling.
private enum TerminalStyleCode {
    case success
    case warningStyle
    case danger
    
    func style(_ text: String) -> String {
        switch self {
            case .success:
                return noora.format("\(.success(text))")
            case .warningStyle:
                return noora.format("\(.accent(text))")
            case .danger:
                return noora.format("\(.danger(text))")
        }
    }
}
