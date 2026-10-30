import Foundation
import Testing
import SystemPackage
import SwiftCardanoCore
@testable import SwiftCardanoMultitool

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

// MARK: - KESExpireInfo.toDictionary

@Suite("KESUtils.KESExpireInfo.toDictionary")
struct KESExpireInfoToDictionaryTests {

    @Test("dictionary uses snake_cased keys for all four documented fields")
    func dictHasFourFields() {
        let info = KESUtils.KESExpireInfo(
            latestKESFileIndex: 3,
            currentKESPeriod: 100,
            expireKESPeriod: 162,
            expireDate: Date(timeIntervalSince1970: 1_000_000)
        )
        let dict = info.toDictionary()
        #expect(dict["latest_kes_file_index"] as? Int == 3)
        #expect(dict["current_kes_period"] as? Int == 100)
        #expect(dict["expire_kes_period"] as? Int == 162)
        #expect(dict["expire_kes_date"] != nil)
    }
}

// MARK: - nextKESNumber

@Suite("KESUtils.nextKESNumber")
struct KESUtilsNextKESNumberTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-tests-kesnum-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func writeCounter(_ desc: String, in dir: URL) throws -> FilePath {
        let url = dir.appendingPathComponent("pool.node.counter")
        let json: [String: Any] = ["description": desc]
        try JSONSerialization.data(withJSONObject: json).write(to: url)
        return FilePath(url.path)
    }

    @Test("parses 'Next certificate issue number: 5' as 5")
    func parsesValidDescription() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = try writeCounter("Next certificate issue number: 5", in: dir)
        let issueNumber = try KESUtils.nextKESNumber(counterFile: path)
        #expect(issueNumber == 5)
    }

    @Test("parses zero as 0")
    func parsesZero() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = try writeCounter("Next certificate issue number: 0", in: dir)
        let issueNumber = try KESUtils.nextKESNumber(counterFile: path)
        #expect(issueNumber == 0)
    }

    @Test("throws when the file is missing")
    func throwsOnMissingFile() {
        let bogus = FilePath("/tmp/scm-kesnum-missing-\(UUID().uuidString).counter")
        #expect(throws: (any Error).self) {
            _ = try KESUtils.nextKESNumber(counterFile: bogus)
        }
    }

    @Test("throws when the description field is missing")
    func throwsWhenDescriptionMissing() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("nodesc.counter")
        try JSONSerialization.data(withJSONObject: ["other": "x"]).write(to: url)

        #expect(throws: (any Error).self) {
            _ = try KESUtils.nextKESNumber(counterFile: FilePath(url.path))
        }
    }

    @Test("throws when the description has no colon")
    func throwsWhenNoColon() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = try writeCounter("No-colon description", in: dir)
        #expect(throws: (any Error).self) {
            _ = try KESUtils.nextKESNumber(counterFile: path)
        }
    }

    @Test("throws when the value after the colon is not an integer")
    func throwsWhenValueNotInteger() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = try writeCounter("Next certificate issue number: xyz", in: dir)
        #expect(throws: (any Error).self) {
            _ = try KESUtils.nextKESNumber(counterFile: path)
        }
    }
}

// MARK: - getCurrentKESPeriod

@Suite("KESUtils.getCurrentKESPeriod")
struct KESUtilsGetCurrentKESPeriodTests {

    /// Genesis without a Byron genesis, for the given network magic.
    private func genesis(magic: UInt32, systemStart: Date) -> GenesisParameters {
        GenesisParameters(
            activeSlotsCoefficient: UnitInterval(numerator: 1, denominator: 20),
            epochLength: 432_000,
            maxKesEvolutions: 62,
            maxLovelaceSupply: 45_000_000_000_000_000,
            networkId: "Mainnet",
            networkMagic: magic,
            securityParam: 2160,
            slotLength: 1,
            slotsPerKesPeriod: 129_600,
            systemStart: systemStart,
            updateQuorum: 5
        )
    }

    @Test("Mainnet's KES period comes from its exact slot timeline, with no Byron genesis needed")
    func mainnetFromTimeline() throws {
        // Shelley began at slot 4,492,800 on 2020-07-29T21:44:51Z (1,596,059,091), one slot a
        // second: at 1,700,000,000 the slot is 108,433,709, and 108,433,709 / 129,600 = 836.
        let params = genesis(magic: 764_824_073, systemStart: Date(timeIntervalSince1970: 1_506_203_091))
        let period = try KESUtils.getCurrentKESPeriod(
            currentTimeSec: 1_700_000_000,
            genesisParameters: params,
            byronToShelleyEpochTransition: 208
        )
        #expect(period == 836)
    }

    @Test("A chain that always had one slot length counts slots from its system start")
    func uniformChainFromSystemStart() throws {
        let start = 1_700_000_000
        let params = genesis(magic: 42, systemStart: Date(timeIntervalSince1970: TimeInterval(start)))
        let period = try KESUtils.getCurrentKESPeriod(
            currentTimeSec: start + 2 * 129_600 + 5,
            genesisParameters: params,
            byronToShelleyEpochTransition: 0
        )
        #expect(period == 2)
        let info = try KESUtils.getKESExpireInfo(
            genesisParameters: params,
            latestKESFileIndex: 1,
            byronToShelleyEpochTransition: 0,
            currentTime: Date(timeIntervalSince1970: TimeInterval(start + 2 * 129_600 + 5))
        )
        #expect(info.currentKESPeriod == 2)
    }
}

// MARK: - KESError formatting (additional cases)

@Suite("KESUtils.KESError formatting")
struct KESUtilsKESErrorFormattingTests {

    @Test("invalidCounterFormat preserves the supplied message")
    func invalidCounterFormatMessage() {
        let err = KESUtils.KESError.invalidCounterFormat("bad format here")
        #expect(err.description.contains("bad format here"))
    }

    @Test("missingGenesisParameter names the missing parameter")
    func missingGenesisParameterMessage() {
        let err = KESUtils.KESError.missingGenesisParameter("byronGenesis")
        #expect(err.description.contains("byronGenesis"))
    }
}
