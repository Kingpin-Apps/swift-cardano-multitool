import Foundation
import SystemPackage
import SwiftCardanoCore

/// Namespace for KES (Key Evolving Signature) related utilities.
///
/// Provides functions to:
/// - Extract the next certificate issue number from a counter file
/// - Calculate the current KES period based on genesis parameters
/// - Generate KES expiration information for operational certificates
public struct KESUtils {
    
    // MARK: - Types
    
    /// Information about KES key expiration.
    ///
    /// This struct contains all the relevant information about when KES keys
    /// will expire and need to be rotated.
    public struct KESExpireInfo: Codable, Sendable {
        /// The index of the latest KES key file (e.g., 001 for `pool.kes-001.skey`).
        public let latestKESFileIndex: Int
        
        /// The current KES period at the time of calculation.
        public let currentKESPeriod: Int
        
        /// The KES period at which the keys will expire.
        public let expireKESPeriod: Int
        
        /// The date and time when the KES keys will expire.
        public let expireDate: Date
        
        /// The number of KES periods remaining before expiration.
        public var remainingKESPeriods: Int {
            expireKESPeriod - currentKESPeriod
        }
        
        /// Whether the KES keys have expired.
        public var isExpired: Bool {
            Date() >= expireDate
        }
        
        /// A human-readable description of the time remaining until expiration.
        public var timeRemaining: String {
            let now = Date()
            if now >= expireDate {
                return "Expired"
            }
            
            let components = Calendar.current.dateComponents(
                [.day, .hour, .minute],
                from: now,
                to: expireDate
            )
            
            var parts: [String] = []
            if let days = components.day, days > 0 {
                parts.append("\(days) day\(days == 1 ? "" : "s")")
            }
            if let hours = components.hour, hours > 0 {
                parts.append("\(hours) hour\(hours == 1 ? "" : "s")")
            }
            if let minutes = components.minute, minutes > 0, parts.isEmpty {
                parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")")
            }
            
            return parts.isEmpty ? "Less than a minute" : parts.joined(separator: ", ")
        }
        
        enum CodingKeys: String, CodingKey {
            case latestKESFileIndex = "latest_kes_file_index"
            case currentKESPeriod = "current_kes_period"
            case expireKESPeriod = "expire_kes_period"
            case expireDate = "expire_kes_date"
        }
        
        public func toDictionary() -> [String: Any] {
            [
                CodingKeys.latestKESFileIndex.rawValue: latestKESFileIndex,
                CodingKeys.currentKESPeriod.rawValue: currentKESPeriod,
                CodingKeys.expireKESPeriod.rawValue: expireKESPeriod,
                CodingKeys.expireDate.rawValue: expireDate
            ]
        }
    }
    
    // MARK: - Errors
    
    /// Errors that can occur during KES operations.
    public enum KESError: Error, CustomStringConvertible {
        case invalidCounterFormat(String)
        case missingGenesisParameter(String)
        
        public var description: String {
            switch self {
            case .invalidCounterFormat(let message):
                return "Invalid counter format: \(message)"
            case .missingGenesisParameter(let param):
                return "Missing genesis parameter: \(param)"
            }
        }
    }
    
    // MARK: - Next KES Number
    
    /// Extracts the next certificate issue number from a counter file.
    ///
    /// The counter file is expected to be a JSON file with a "description" field
    /// containing the format: "Next certificate issue number: X" where X is the issue number.
    ///
    /// - Parameter counterFile: The path to the counter file.
    /// - Returns: The next certificate issue number.
    /// - Throws: `SwiftCardanoMultitoolError.fileNotFound` if the file doesn't exist,
    ///           `KESError.invalidCounterFormat` if the file format is invalid.
    public static func nextKESNumber(counterFile: FilePath) throws -> Int {
        // Check file exists (throws SwiftCardanoMultitoolError.fileNotFound if missing)
        try FileUtils.checkFileExists(counterFile)
        
        // Load and parse the JSON file
        let counter = try FileUtils.loadJSONFile(counterFile)
        
        // Extract the description field
        guard let description = counter["description"] as? String else {
            throw KESError.invalidCounterFormat("Missing 'description' field in counter file")
        }
        
        // Parse the issue number from the description
        // Expected format: "Next certificate issue number: X"
        let components = description.split(separator: ":")
        guard components.count >= 2 else {
            throw KESError.invalidCounterFormat("Description field does not contain a colon-separated value")
        }
        
        let numberString = components[1].trimmingCharacters(in: .whitespaces)
        guard let issueNumber = Int(numberString) else {
            throw KESError.invalidCounterFormat("Could not parse issue number from: '\(numberString)'")
        }
        
        return issueNumber
    }
    
    // MARK: - Current KES Period
    
    /// Calculates the current KES period from genesis parameters.
    ///
    /// This function computes the KES period based on the `GenesisParameters`,
    /// which contains both Shelley and Byron genesis data, accounting for the
    /// transition period between eras.
    ///
    /// - Parameters:
    ///   - currentTimeSec: The current time in seconds since Unix epoch.
    ///   - genesisParameters: The `GenesisParameters` from SwiftCardanoCore containing:
    ///     - `slotLength`: Duration of a slot in seconds
    ///     - `epochLength`: Number of slots per epoch
    ///     - `slotsPerKesPeriod`: Number of slots per KES period
    ///     - `systemStart`: The Shelley genesis start time
    ///     - `byronGenesis.startTime`: The Byron genesis start time in seconds
    ///   - byronToShelleyEpochTransition: The epoch number at which Byron transitioned to Shelley.
    /// - Returns: The current KES period as an integer.
    /// - Throws: `KESError.missingGenesisParameter` if required parameters are missing.
    public static func getCurrentKESPeriod(
        currentTimeSec: Int,
        genesisParameters: GenesisParameters,
        byronToShelleyEpochTransition: Int
    ) throws -> Int {
        // Extract required parameters from GenesisParameters
        guard let slotLength = genesisParameters.slotLength else {
            throw KESError.missingGenesisParameter("slotLength")
        }
        
        guard let epochLength = genesisParameters.epochLength else {
            throw KESError.missingGenesisParameter("epochLength")
        }
        
        guard let slotsPerKesPeriod = genesisParameters.slotsPerKesPeriod else {
            throw KESError.missingGenesisParameter("slotsPerKesPeriod")
        }
        
        guard let systemStart = genesisParameters.systemStart else {
            throw KESError.missingGenesisParameter("systemStart")
        }
        
        // Extract Byron genesis start time
        guard let byronGenesis = genesisParameters.byronGenesis else {
            throw KESError.missingGenesisParameter("byronGenesis")
        }
        let startTimeByron = byronGenesis.startTime
        
        // Convert systemStart Date to Unix timestamp
        let startTimeSec = Int(systemStart.timeIntervalSince1970)
        
        // Calculate transition time end
        let transTimeEnd = startTimeSec + (byronToShelleyEpochTransition * epochLength)
        
        // Byron slot calculations (Byron used 20-second slots)
        let byronSlotDuration = 20.0
        let byronSlots = Double(startTimeSec - startTimeByron) / byronSlotDuration
        let transSlots = Double(byronToShelleyEpochTransition * epochLength) / byronSlotDuration
        
        // Calculate current slot based on whether we're in or past the transition phase
        let currentSlot: Double
        if currentTimeSec < transTimeEnd {
            // In Transition Phase between ShelleyGenesisStart and TransitionEnd
            currentSlot = byronSlots + Double(currentTimeSec - startTimeSec) / byronSlotDuration
        } else {
            // After Transition Phase
            currentSlot = byronSlots + transSlots + (Double(currentTimeSec - transTimeEnd) / Double(slotLength))
        }
        
        // Calculate KES period
        let currentKESPeriod = (currentSlot - byronSlots) / (Double(slotsPerKesPeriod) * Double(slotLength))
        
        // Ensure non-negative
        return max(Int(currentKESPeriod), 0)
    }
    
    /// Convenience method that uses the current system time.
    ///
    /// - Parameters:
    ///   - genesisParameters: The `GenesisParameters` from SwiftCardanoCore.
    ///   - byronToShelleyEpochTransition: The epoch number at which Byron transitioned to Shelley.
    /// - Returns: The current KES period as an integer.
    /// - Throws: `KESError.missingGenesisParameter` if required parameters are missing.
    public static func getCurrentKESPeriod(
        genesisParameters: GenesisParameters,
        byronToShelleyEpochTransition: Int
    ) throws -> Int {
        let currentTimeSec = Int(Date().timeIntervalSince1970)
        return try getCurrentKESPeriod(
            currentTimeSec: currentTimeSec,
            genesisParameters: genesisParameters,
            byronToShelleyEpochTransition: byronToShelleyEpochTransition
        )
    }
    
    // MARK: - KES Expiration Info
    
    /// Generates KES expiration information for operational certificate management.
    ///
    /// This function calculates when the KES keys will expire based on the current
    /// KES period and the maximum KES evolutions allowed by the protocol. This is
    /// essential for stake pool operators to know when they need to rotate their
    /// KES keys and generate new operational certificates.
    ///
    /// - Parameters:
    ///   - genesisParameters: The `GenesisParameters` from SwiftCardanoCore.
    ///   - latestKESFileIndex: The index of the current KES key file (e.g., 1 for `pool.kes-001.skey`).
    ///   - byronToShelleyEpochTransition: The epoch number at which Byron transitioned to Shelley.
    ///   - currentTime: Optional current time for testing. Defaults to `Date()`.
    /// - Returns: A `KESExpireInfo` containing expiration details.
    /// - Throws: `KESError.missingGenesisParameter` if required parameters are missing.
    public static func getKESExpireInfo(
        genesisParameters: GenesisParameters,
        latestKESFileIndex: Int,
        byronToShelleyEpochTransition: Int,
        currentTime: Date = Date()
    ) throws -> KESExpireInfo {
        // Extract required parameters
        guard let slotLength = genesisParameters.slotLength else {
            throw KESError.missingGenesisParameter("slotLength")
        }
        
        guard let slotsPerKesPeriod = genesisParameters.slotsPerKesPeriod else {
            throw KESError.missingGenesisParameter("slotsPerKesPeriod")
        }
        
        guard let maxKesEvolutions = genesisParameters.maxKesEvolutions else {
            throw KESError.missingGenesisParameter("maxKesEvolutions")
        }
        
        let currentTimeSec = Int(currentTime.timeIntervalSince1970)
        
        // Calculate current KES period
        let currentKESPeriod = try getCurrentKESPeriod(
            currentTimeSec: currentTimeSec,
            genesisParameters: genesisParameters,
            byronToShelleyEpochTransition: byronToShelleyEpochTransition
        )
        
        spacedPrint("Current KES Period: \(.primary("\(currentKESPeriod)"))")
        
        // Calculate expiration
        let expireKESPeriod = currentKESPeriod + maxKesEvolutions
        
        // Calculate expire time:
        // expire_time_sec = current_time_sec + (slotLength * maxKesEvolutions * slotsPerKESPeriod)
        let secondsUntilExpire = slotLength * maxKesEvolutions * slotsPerKesPeriod
        let expireTimeSec = currentTimeSec + secondsUntilExpire
        let expireDate = Date(timeIntervalSince1970: TimeInterval(expireTimeSec))
        
        return KESExpireInfo(
            latestKESFileIndex: latestKESFileIndex,
            currentKESPeriod: currentKESPeriod,
            expireKESPeriod: expireKESPeriod,
            expireDate: expireDate
        )
    }
    
    /// Generates KES expiration info by reading the KES counter file.
    ///
    /// This convenience method reads the latest KES file index from a counter file
    /// and then calculates the expiration information.
    ///
    /// - Parameters:
    ///   - genesisParameters: The `GenesisParameters` from SwiftCardanoCore.
    ///   - kesCounterFile: Path to the KES counter file (e.g., `pool.kes.counter`).
    ///   - byronToShelleyEpochTransition: The epoch number at which Byron transitioned to Shelley.
    ///   - currentTime: Optional current time for testing. Defaults to `Date()`.
    /// - Returns: A `KESExpireInfo` containing expiration details.
    /// - Throws: `SwiftCardanoMultitoolError.fileNotFound` if the counter file doesn't exist,
    ///           `KESError.missingGenesisParameter` if required parameters are missing.
    public static func getKESExpireInfo(
        genesisParameters: GenesisParameters,
        kesCounterFile: FilePath,
        byronToShelleyEpochTransition: Int,
        currentTime: Date = Date()
    ) throws -> KESExpireInfo {
        // Read the latest KES file index from the counter file
        let counter = try FileUtils.loadFile(kesCounterFile)
        guard let counterInt = Int(counter) else {
            noora.error(.alert("Invalid KES counter file format. Expected an integer value."))
            throw KESError.invalidCounterFormat("Counter file does not contain a valid integer: '\(counter)'")
        }
        
        return try getKESExpireInfo(
            genesisParameters: genesisParameters,
            latestKESFileIndex: counterInt,
            byronToShelleyEpochTransition: byronToShelleyEpochTransition,
            currentTime: currentTime
        )
    }
}
