import Foundation

/// A single slot in the leadership schedule
public struct LeaderSlot: Sendable {
    /// The slot number
    public let slot: Int
    
    /// The UTC time for this slot
    public let time: Date
    
    /// Parse the raw output from `cardano-cli query leadership-schedule` into an array of `LeaderSlot`.
    ///
    /// The CLI output format is:
    /// ```
    ///      SlotNo                          UTC Time
    /// --------------------------------------------------------
    ///      12345678                2024-01-15 03:45:12 UTC
    ///      12345999                2024-01-15 07:22:45 UTC
    /// ```
    ///
    /// - Parameter output: The raw string output from the CLI command.
    /// - Returns: An array of `LeaderSlot` objects.
    public static func parse(from output: String) -> [LeaderSlot] {
        // Collapse multiple spaces into single space and trim
        let normalized = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // Date formatter for "YYYY-MM-DD HH:MM:SS UTC"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss 'UTC'"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        var schedule: [LeaderSlot] = []
        
        // Skip header lines (first 2 lines: header + separator)
        for line in normalized.dropFirst(2) {
            // Collapse whitespace and partition on first space
            let collapsed = line.components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            
            guard collapsed.count >= 4,
                  let slotNumber = Int(collapsed[0]) else {
                continue
            }
            
            // Reconstruct the datetime string from remaining parts
            let timeString = collapsed.dropFirst().joined(separator: " ")
            
            guard let date = dateFormatter.date(from: timeString) else {
                continue
            }
            
            schedule.append(LeaderSlot(slot: slotNumber, time: date))
        }
        
        return schedule
    }
}
