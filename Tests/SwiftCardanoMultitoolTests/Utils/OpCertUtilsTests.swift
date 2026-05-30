import Testing
@testable import SwiftCardanoMultitool

@Suite("OpCertCheckResult")
struct OpCertCheckResultTests {

    @Test("isValid is true only when both flags are true")
    func isValidWhenBothTrue() {
        let result = OpCertCheckResult(
            kesIntervalValid: true,
            counterValid: true,
            nextChainOpCertCount: 42
        )
        #expect(result.isValid == true)
    }

    @Test("isValid is false when only the KES interval flag is true")
    func isValidFalseWhenCounterInvalid() {
        let result = OpCertCheckResult(
            kesIntervalValid: true,
            counterValid: false,
            nextChainOpCertCount: 0
        )
        #expect(result.isValid == false)
    }

    @Test("isValid is false when only the counter flag is true")
    func isValidFalseWhenKesIntervalInvalid() {
        let result = OpCertCheckResult(
            kesIntervalValid: false,
            counterValid: true,
            nextChainOpCertCount: 0
        )
        #expect(result.isValid == false)
    }

    @Test("isValid is false when both flags are false")
    func isValidFalseWhenBothFalse() {
        let result = OpCertCheckResult(
            kesIntervalValid: false,
            counterValid: false,
            nextChainOpCertCount: 0
        )
        #expect(result.isValid == false)
    }

    @Test("nextChainOpCertCount preserves its init value")
    func preservesNextChainCount() {
        let result = OpCertCheckResult(
            kesIntervalValid: true,
            counterValid: true,
            nextChainOpCertCount: 7
        )
        #expect(result.nextChainOpCertCount == 7)
    }
}

@Suite("OpCertUtils.formatDuration")
struct OpCertUtilsFormatDurationTests {

    @Test("returns 'less than a minute' for zero")
    func zeroSeconds() {
        #expect(OpCertUtils.formatDuration(seconds: 0) == "less than a minute")
    }

    @Test("returns 'less than a minute' for fewer than 60 seconds")
    func subMinute() {
        #expect(OpCertUtils.formatDuration(seconds: 59) == "less than a minute")
    }

    @Test("renders exact minutes when under an hour")
    func exactMinutes() {
        #expect(OpCertUtils.formatDuration(seconds: 60) == "1 minute")
        #expect(OpCertUtils.formatDuration(seconds: 120) == "2 minutes")
    }

    @Test("renders hours plus minutes when under a day")
    func hoursAndMinutes() {
        // 1 hour 1 minute
        #expect(OpCertUtils.formatDuration(seconds: 3600 + 60) == "1 hour, 1 minute")
        // 2 hours 30 minutes
        #expect(OpCertUtils.formatDuration(seconds: 2 * 3600 + 30 * 60) == "2 hours, 30 minutes")
    }

    @Test("when days are present, minutes are omitted")
    func daysSuppressMinutes() {
        // 1 day, 2 hours, 30 minutes — minutes are dropped per the source impl.
        let secs = 86400 + 2 * 3600 + 30 * 60
        #expect(OpCertUtils.formatDuration(seconds: secs) == "1 day, 2 hours")
    }

    @Test("pluralises days correctly")
    func daysPluralisation() {
        #expect(OpCertUtils.formatDuration(seconds: 86400).hasPrefix("1 day"))
        #expect(OpCertUtils.formatDuration(seconds: 2 * 86400).hasPrefix("2 days"))
    }

    @Test("absolute value is used for negative durations")
    func negativeDurations() {
        #expect(OpCertUtils.formatDuration(seconds: -3600) == "1 hour")
    }
}

@Suite("OpCertUtils.checkOpCertCounterForNext")
struct OpCertUtilsCheckCounterForNextTests {

    @Test("returns true when on-disk counter equals next chain counter")
    func validMatch() {
        let ok = OpCertUtils.checkOpCertCounterForNext(
            nextChainOpCertCount: 5,
            onChainOpCertCount: 4,
            onDiskOpCertCount: 5,
            kesError: false
        )
        #expect(ok == true)
    }

    @Test("returns false when on-disk counter is too low")
    func tooLow() {
        let ok = OpCertUtils.checkOpCertCounterForNext(
            nextChainOpCertCount: 5,
            onChainOpCertCount: 4,
            onDiskOpCertCount: 4,
            kesError: false
        )
        #expect(ok == false)
    }

    @Test("returns false when on-disk counter is too high")
    func tooHigh() {
        let ok = OpCertUtils.checkOpCertCounterForNext(
            nextChainOpCertCount: 5,
            onChainOpCertCount: 4,
            onDiskOpCertCount: 6,
            kesError: false
        )
        #expect(ok == false)
    }

    @Test("on-chain counter of -1 (not used yet) is still allowed when on-disk matches next")
    func unusedOnChain() {
        let ok = OpCertUtils.checkOpCertCounterForNext(
            nextChainOpCertCount: 0,
            onChainOpCertCount: -1,
            onDiskOpCertCount: 0,
            kesError: false
        )
        #expect(ok == true)
    }
}

@Suite("OpCertUtils.checkOpCertCounterForCurrent")
struct OpCertUtilsCheckCounterForCurrentTests {

    @Test("accepts the 'no block generated yet' state: onChain=-1, onDisk=0")
    func noBlockGeneratedYet() {
        let ok = OpCertUtils.checkOpCertCounterForCurrent(
            nextChainOpCertCount: 1,
            onChainOpCertCount: -1,
            onDiskOpCertCount: 0,
            kesError: false
        )
        #expect(ok == true)
    }

    @Test("accepts matching counters")
    func matchingCounters() {
        let ok = OpCertUtils.checkOpCertCounterForCurrent(
            nextChainOpCertCount: 5,
            onChainOpCertCount: 4,
            onDiskOpCertCount: 4,
            kesError: false
        )
        #expect(ok == true)
    }

    @Test("rejects mismatched counters")
    func mismatchedCounters() {
        let ok = OpCertUtils.checkOpCertCounterForCurrent(
            nextChainOpCertCount: 5,
            onChainOpCertCount: 4,
            onDiskOpCertCount: 3,
            kesError: false
        )
        #expect(ok == false)
    }

    @Test("rejects when on-chain has activity but disk is at zero (only 'no block generated' uses zero)")
    func diskZeroWithOnChainActivity() {
        let ok = OpCertUtils.checkOpCertCounterForCurrent(
            nextChainOpCertCount: 5,
            onChainOpCertCount: 4,
            onDiskOpCertCount: 0,
            kesError: false
        )
        #expect(ok == false)
    }
}

@Suite("OpCertUtils.checkKESInterval")
struct OpCertUtilsCheckKESIntervalTests {

    @Test("returns true when current KES is within [onDiskKESStart, onDiskKESStart+maxKESEvolutions)")
    func withinRange() {
        let ok = OpCertUtils.checkKESInterval(
            onDiskKESStart: 100,
            currentKESPeriod: 130,
            maxKESEvolutions: 62,
            slotsPerKESPeriod: 129600,
            slotLength: 1,
            currentSlot: 130 * 129600
        )
        #expect(ok == true)
    }

    @Test("returns true at the lower bound (current == start)")
    func atLowerBound() {
        let ok = OpCertUtils.checkKESInterval(
            onDiskKESStart: 100,
            currentKESPeriod: 100,
            maxKESEvolutions: 62,
            slotsPerKESPeriod: 129600,
            slotLength: 1,
            currentSlot: 100 * 129600
        )
        #expect(ok == true)
    }

    @Test("returns false at the upper bound (current == start + maxEvolutions)")
    func atUpperBoundIsExpired() {
        // expireKESPeriod = 100 + 62 = 162. currentKESPeriod == 162 → NOT < expire → false.
        let ok = OpCertUtils.checkKESInterval(
            onDiskKESStart: 100,
            currentKESPeriod: 162,
            maxKESEvolutions: 62,
            slotsPerKESPeriod: 129600,
            slotLength: 1,
            currentSlot: 162 * 129600
        )
        #expect(ok == false)
    }

    @Test("returns false when current KES is below the start period")
    func belowStart() {
        let ok = OpCertUtils.checkKESInterval(
            onDiskKESStart: 100,
            currentKESPeriod: 50,
            maxKESEvolutions: 62,
            slotsPerKESPeriod: 129600,
            slotLength: 1,
            currentSlot: 50 * 129600
        )
        #expect(ok == false)
    }
}
