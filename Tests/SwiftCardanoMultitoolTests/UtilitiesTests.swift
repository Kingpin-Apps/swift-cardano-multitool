import Foundation
import Testing
@testable import SwiftCardanoMultitool

@Suite("Utilities")
struct UtilitiesTests {

    // MARK: - lovelaceToAda

    @Test("converts zero lovelace to zero ADA")
    func lovelaceToAdaZero() {
        #expect(lovelaceToAda(0) == 0.0)
    }

    @Test("converts 1 ADA worth of lovelace")
    func lovelaceToAdaOneAda() {
        #expect(lovelaceToAda(1_000_000) == 1.0)
    }

    @Test("converts fractional ADA correctly")
    func lovelaceToAdaFractional() {
        #expect(lovelaceToAda(1_500_000) == 1.5)
    }

    @Test("converts large lovelace values")
    func lovelaceToAdaLarge() {
        #expect(lovelaceToAda(45_000_000_000_000) == 45_000_000.0)
    }

    // MARK: - lovelaceToAdaString

    @Test("formats zero lovelace as ADA string")
    func lovelaceToAdaStringZero() {
        #expect(lovelaceToAdaString(0) == "0.000000 ₳")
    }

    @Test("formats 1 ADA as string with 6 decimals")
    func lovelaceToAdaStringOneAda() {
        #expect(lovelaceToAdaString(1_000_000) == "1.000000 ₳")
    }

    @Test("formats 1.5 ADA as string")
    func lovelaceToAdaStringFractional() {
        #expect(lovelaceToAdaString(1_500_000) == "1.500000 ₳")
    }

    // MARK: - formatNumber

    @Test("returns zero for nil input")
    func formatNumberNil() {
        #expect(formatNumber(nil) == "0 ₳")
    }

    @Test("returns zero for empty string input")
    func formatNumberEmptyString() {
        #expect(formatNumber("") == "0 ₳")
    }

    @Test("formats zero with two decimals")
    func formatNumberZero() {
        #expect(formatNumber(0) == "0.00 ₳")
    }

    @Test("formats sub-1000 value with two decimals")
    func formatNumberSmall() {
        #expect(formatNumber(500.0) == "500.00 ₳")
    }

    @Test("formats 999 with two decimals")
    func formatNumberBelowThousand() {
        #expect(formatNumber(999) == "999.00 ₳")
    }

    @Test("scales 1000 to K suffix")
    func formatNumberThousand() {
        #expect(formatNumber(1000.0) == "1K ₳")
    }

    @Test("scales 1500 to K suffix with decimal")
    func formatNumberThousandFractional() {
        #expect(formatNumber(1500.0) == "1.5K ₳")
    }

    @Test("scales 1,000,000 to M suffix")
    func formatNumberMillion() {
        #expect(formatNumber(1_000_000.0) == "1M ₳")
    }

    @Test("scales 1,500,000 to M suffix with decimal")
    func formatNumberMillionFractional() {
        #expect(formatNumber(1_500_000.0) == "1.5M ₳")
    }

    @Test("scales 1,000,000,000 to B suffix")
    func formatNumberBillion() {
        #expect(formatNumber(1_000_000_000.0) == "1B ₳")
    }

    @Test("accepts Decimal input")
    func formatNumberDecimalType() {
        let value: Decimal = 250
        #expect(formatNumber(value) == "250.00 ₳")
    }

    @Test("accepts String input")
    func formatNumberStringInput() {
        #expect(formatNumber("750") == "750.00 ₳")
    }

    @Test("returns zero for non-numeric string")
    func formatNumberInvalidString() {
        #expect(formatNumber("abc") == "0 ₳")
    }

    @Test("respects custom decimal count")
    func formatNumberCustomDecimals() {
        #expect(formatNumber(1.5, numDecimals: 4) == "1.5000 ₳")
    }

    // MARK: - convertSeconds

    @Test("converts zero seconds")
    func convertSecondsZero() {
        #expect(convertSeconds(0) == "00 days 00:00:00")
    }

    @Test("converts exactly one day")
    func convertSecondsOneDay() {
        #expect(convertSeconds(86400) == "01 days 00:00:00")
    }

    @Test("converts 1 hour 1 minute 1 second")
    func convertSecondsHourMinuteSec() {
        #expect(convertSeconds(3661) == "00 days 01:01:01")
    }

    @Test("converts 1 day 1 hour 1 minute 1 second")
    func convertSecondsDayHourMinuteSec() {
        #expect(convertSeconds(90061) == "01 days 01:01:01")
    }

    @Test("converts seconds-only duration")
    func convertSecondsOnly() {
        #expect(convertSeconds(45) == "00 days 00:00:45")
    }

    @Test("pads all components to two digits")
    func convertSecondsPadding() {
        let result = convertSeconds(9 * 3600 + 9 * 60 + 9)
        #expect(result == "00 days 09:09:09")
    }
}
