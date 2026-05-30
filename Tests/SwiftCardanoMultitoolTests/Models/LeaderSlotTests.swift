import Foundation
import Testing
@testable import SwiftCardanoMultitool

@Suite("LeaderSlot.parse")
struct LeaderSlotParseTests {

    private let sampleOutput = """
     SlotNo                          UTC Time
    --------------------------------------------------------
     12345678                2024-01-15 03:45:12 UTC
     12345999                2024-01-15 07:22:45 UTC
    """

    @Test("parses a multi-line CLI output into LeaderSlot values")
    func parsesValidOutput() {
        let slots = LeaderSlot.parse(from: sampleOutput)
        #expect(slots.count == 2)
        #expect(slots[0].slot == 12_345_678)
        #expect(slots[1].slot == 12_345_999)
    }

    @Test("interprets the UTC suffix as the UTC time zone")
    func parsesUTCTimeZone() {
        let slots = LeaderSlot.parse(from: sampleOutput)
        let expected = makeUTCDate(year: 2024, month: 1, day: 15, hour: 3, minute: 45, second: 12)
        #expect(slots.first?.time == expected)
    }

    @Test("returns an empty array for empty input")
    func emptyInput() {
        #expect(LeaderSlot.parse(from: "").isEmpty)
    }

    @Test("returns an empty array when only headers are present")
    func headersOnly() {
        let onlyHeaders = """
        SlotNo                          UTC Time
        --------------------------------------------------------
        """
        #expect(LeaderSlot.parse(from: onlyHeaders).isEmpty)
    }

    @Test("skips lines with too few whitespace-separated fields")
    func skipsTooShortLines() {
        let output = """
         SlotNo                          UTC Time
        --------------------------------------------------------
         garbage
         12345678                2024-01-15 03:45:12 UTC
        """
        let slots = LeaderSlot.parse(from: output)
        #expect(slots.count == 1)
        #expect(slots[0].slot == 12_345_678)
    }

    @Test("skips lines with an unparseable slot number")
    func skipsBadSlotNumber() {
        let output = """
         SlotNo                          UTC Time
        --------------------------------------------------------
         notanumber                2024-01-15 03:45:12 UTC
         12345678                2024-01-15 03:45:12 UTC
        """
        let slots = LeaderSlot.parse(from: output)
        #expect(slots.count == 1)
        #expect(slots[0].slot == 12_345_678)
    }

    @Test("skips lines with an unparseable timestamp")
    func skipsBadTimestamp() {
        let output = """
         SlotNo                          UTC Time
        --------------------------------------------------------
         12345678                NOT a date string AT ALL
         12345999                2024-01-15 07:22:45 UTC
        """
        let slots = LeaderSlot.parse(from: output)
        #expect(slots.count == 1)
        #expect(slots[0].slot == 12_345_999)
    }

    // MARK: - Helpers

    private func makeUTCDate(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components)!
    }
}
