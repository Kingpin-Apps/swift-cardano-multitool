import BigInt
import Foundation
import SwiftCardanoCore
import Testing

@testable import SwiftCardanoMultitool

/// Values the ledger holds as exact rationals stay exact in the multitool.
@Suite("Ledger exactness")
struct LedgerExactnessTests {

    @Test("A pool margin is the exact fraction its decimal spells", arguments: [
        (0.015, UInt64(3), UInt64(200)),
        (0.07, 7, 100),
        (0.1, 1, 10),
        (0.0, 0, 1),
        (1.0, 1, 1),
    ])
    func marginFraction(_ margin: Double, numerator: UInt64, denominator: UInt64) throws {
        let fraction = try Pool.marginFraction(margin)
        #expect(fraction.0 == numerator && fraction.1 == denominator)
    }

    @Test("A margin outside 0…1 throws instead of being clamped", arguments: [1.5, -0.1, Double.nan])
    func marginOutOfRange(_ margin: Double) {
        #expect(throws: SwiftCardanoMultitoolError.self) { try Pool.marginFraction(margin) }
    }

    @Test("A vote meets its threshold exactly at the boundary, as the ledger compares rationals")
    func thresholdBoundary() {
        let twoThirds = UnitInterval(numerator: 2, denominator: 3)
        // 2/3 of the stake, which a Double division need not land on.
        #expect(meets(BigInt(6_000_000_000_000_002), BigInt(9_000_000_000_000_003), twoThirds))
        #expect(!meets(BigInt(6_000_000_000_000_001), BigInt(9_000_000_000_000_003), twoThirds))
        // No denominator is a ratio of 0: it meets only a zero threshold.
        #expect(!meets(0, 0, twoThirds))
        #expect(meets(0, 0, UnitInterval(numerator: 0, denominator: 1)))
    }

    @Test("The higher of two thresholds is chosen exactly")
    func higherThreshold() {
        let a = UnitInterval(numerator: 67, denominator: 100)
        let b = UnitInterval(numerator: 2, denominator: 3)
        #expect(higher(a, b) == a)
        #expect(higher(b, a) == a)
    }
}
