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
            // `expireDate` must be a JSON-serialisable type — a raw `Date` makes
            // `JSONSerialization` throw "Invalid type in JSON write (__NSTaggedDate)".
            // Emit a human-readable ISO-8601 string.
            [
                CodingKeys.latestKESFileIndex.rawValue: latestKESFileIndex,
                CodingKeys.currentKESPeriod.rawValue: currentKESPeriod,
                CodingKeys.expireKESPeriod.rawValue: expireKESPeriod,
                CodingKeys.expireDate.rawValue: ISO8601DateFormatter().string(from: expireDate)
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
        
        let currentMilliseconds = Int64(currentTimeSec) * 1000

        // The ledger's KES period is the slot divided by slotsPerKESPeriod. Where core
        // knows the chain's exact timeline (the public networks, or any chain that has
        // always used one slot length), the slot comes from it.
        if let timeline = SlotTimeline.forChain(genesis: genesisParameters) {
            let slot = timeline.slot(atMilliseconds: currentMilliseconds)
            return Int(slot / slotsPerKesPeriod)
        }

        // A chain with a Byron era of another slot length: genesis does not say when
        // it forked to Shelley, so the configured transition epoch places it, as the
        // SPO scripts do. Worked in whole milliseconds.
        guard let byronGenesis = genesisParameters.byronGenesis else {
            throw KESError.missingGenesisParameter("byronGenesis")
        }
        guard let slotMilliseconds = Self.milliseconds(slotLength), slotMilliseconds > 0,
              let byronSlotMilliseconds = Int64(exactly: byronGenesis.blockVersionData.slotDuration),
              byronSlotMilliseconds > 0,
              let epochSlots = Int64(exactly: epochLength),
              let kesSlots = Int64(exactly: slotsPerKesPeriod), kesSlots > 0
        else {
            throw KESError.missingGenesisParameter("slotLength")
        }
        let startMilliseconds = Int64(systemStart.timeIntervalSince1970 * 1000)
        let byronStartMilliseconds = Int64(byronGenesis.startTime) * 1000
        // The transition is `byronToShelleyEpochTransition` Shelley-length epochs of time.
        let transitionMilliseconds = Int64(byronToShelleyEpochTransition) * epochSlots * 1000
        let transitionEnd = startMilliseconds + transitionMilliseconds

        let byronSlots = (startMilliseconds - byronStartMilliseconds) / byronSlotMilliseconds
        let currentSlot: Int64
        if currentMilliseconds < transitionEnd {
            currentSlot = byronSlots + (currentMilliseconds - startMilliseconds) / byronSlotMilliseconds
        } else {
            currentSlot = byronSlots + transitionMilliseconds / byronSlotMilliseconds
                + (currentMilliseconds - transitionEnd) / slotMilliseconds
        }
        return max(Int((currentSlot - byronSlots) / kesSlots), 0)
    }

    /// A slot length in whole milliseconds, or `nil` when it is not one.
    static func milliseconds(_ seconds: Decimal) -> Int64? {
        var exact = seconds * 1000
        var whole = Decimal()
        NSDecimalRound(&whole, &exact, 0, .plain)
        guard whole == exact else { return nil }
        return Int64(whole.description)
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
        guard let evolutions = Int(exactly: maxKesEvolutions),
              let slotMilliseconds = Self.milliseconds(slotLength),
              let kesSlots = Int64(exactly: slotsPerKesPeriod) else {
            throw KESError.missingGenesisParameter("maxKesEvolutions")
        }
        let expireKESPeriod = currentKESPeriod + evolutions
        
        // Calculate expire time:
        // expire_time_sec = current_time_sec + (slotLength * maxKesEvolutions * slotsPerKESPeriod)
        let secondsUntilExpire = Int(slotMilliseconds * Int64(evolutions) * kesSlots / 1000)
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
