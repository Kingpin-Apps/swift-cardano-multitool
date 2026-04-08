import Foundation
import Testing
@testable import SwiftCardanoMultitoolLib

@Suite("KESUtils")
struct KESUtilsTests {

    // MARK: - KESExpireInfo.remainingKESPeriods

    @Test("calculates remaining KES periods correctly")
    func remainingKESPeriods() {
        let info = makeInfo(current: 100, expire: 162)
        #expect(info.remainingKESPeriods == 62)
    }

    @Test("remaining periods is zero when current equals expire")
    func remainingKESPeriodsAtExpiry() {
        let info = makeInfo(current: 162, expire: 162)
        #expect(info.remainingKESPeriods == 0)
    }

    @Test("remaining periods is negative when past expiry")
    func remainingKESPeriodsPastExpiry() {
        let info = makeInfo(current: 170, expire: 162)
        #expect(info.remainingKESPeriods == -8)
    }

    // MARK: - KESExpireInfo.isExpired

    @Test("reports not expired when expiry is in the future")
    func notExpired() {
        let futureDate = Date().addingTimeInterval(86400) // 1 day from now
        let info = makeInfo(expireDate: futureDate)
        #expect(info.isExpired == false)
    }

    @Test("reports expired when expiry is in the past")
    func isExpired() {
        let pastDate = Date().addingTimeInterval(-86400) // 1 day ago
        let info = makeInfo(expireDate: pastDate)
        #expect(info.isExpired == true)
    }

    // MARK: - KESExpireInfo.timeRemaining

    @Test("returns Expired for a past expiry date")
    func timeRemainingExpired() {
        let pastDate = Date().addingTimeInterval(-3600)
        let info = makeInfo(expireDate: pastDate)
        #expect(info.timeRemaining == "Expired")
    }

    @Test("includes days in time remaining when more than one day left")
    func timeRemainingIncludesDays() {
        let future = Date().addingTimeInterval(3 * 86400) // 3 days
        let info = makeInfo(expireDate: future)
        #expect(info.timeRemaining.contains("day"))
    }

    @Test("includes hours in time remaining for sub-day durations")
    func timeRemainingIncludesHours() {
        let future = Date().addingTimeInterval(5 * 3600) // 5 hours
        let info = makeInfo(expireDate: future)
        #expect(info.timeRemaining.contains("hour"))
    }

    @Test("returns less than a minute for very short durations")
    func timeRemainingLessThanMinute() {
        let future = Date().addingTimeInterval(30) // 30 seconds
        let info = makeInfo(expireDate: future)
        #expect(info.timeRemaining == "Less than a minute")
    }

    @Test("pluralises days correctly")
    func timeRemainingDayPlurality() {
        let oneDayFuture = Date().addingTimeInterval(86400 + 60) // just over 1 day
        let info = makeInfo(expireDate: oneDayFuture)
        // Should contain "1 day" not "1 days"
        #expect(info.timeRemaining.contains("1 day"))
        #expect(!info.timeRemaining.contains("1 days"))
    }

    // MARK: - KESError.description

    @Test("formats invalidCounterFormat error description")
    func kesErrorInvalidCounterFormat() {
        let error = KESUtils.KESError.invalidCounterFormat("missing field")
        #expect(error.description == "Invalid counter format: missing field")
    }

    @Test("formats missingGenesisParameter error description")
    func kesErrorMissingGenesisParameter() {
        let error = KESUtils.KESError.missingGenesisParameter("slotLength")
        #expect(error.description == "Missing genesis parameter: slotLength")
    }

    // MARK: - Helpers

    private func makeInfo(
        current: Int = 100,
        expire: Int = 162,
        expireDate: Date = Date().addingTimeInterval(86400)
    ) -> KESUtils.KESExpireInfo {
        KESUtils.KESExpireInfo(
            latestKESFileIndex: 1,
            currentKESPeriod: current,
            expireKESPeriod: expire,
            expireDate: expireDate
        )
    }
}
