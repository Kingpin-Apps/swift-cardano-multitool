import Foundation
import Noora

/// The unit a value is expressed in.
public enum AdaUnit: Sendable {
    case ada
    case lovelace
}

/// Parses human-friendly Cardano value strings into a lovelace amount.
///
/// Accepted input forms:
/// - Plain numbers: `1000`, `1_000`, `1,000` (uses `defaultUnit`)
/// - K/M/B multipliers (1e3, 1e6, 1e9, case-insensitive): `1.5K`, `2M`, `1B`
/// - Explicit ADA: `100 ADA`, `100ada`, `100₳`, `₳100`
/// - Explicit lovelace: `1_000_000 lovelace`, `1000lovelaces`, `1000L`
/// - Combined: `100K ADA` (= 100,000 ADA), `₳1.5M` (= 1.5M ADA)
public struct AdaFormatter: Sendable {
    /// Lovelace per ADA.
    public static let lovelacePerAda: Decimal = 1_000_000

    /// The unit assumed when the input has no explicit unit marker.
    public let defaultUnit: AdaUnit

    public init(defaultUnit: AdaUnit = .ada) {
        self.defaultUnit = defaultUnit
    }

    /// Parse `input` into lovelace. Returns `nil` if the input is malformed,
    /// negative, or would resolve to a fractional lovelace.
    public func toLovelace(_ input: String) -> UInt64? {
        guard let parsed = parse(input) else { return nil }
        let lovelace: Decimal
        switch parsed.unit {
        case .ada: lovelace = parsed.value * Self.lovelacePerAda
        case .lovelace: lovelace = parsed.value
        }
        guard lovelace >= 0 else { return nil }
        var rounded = Decimal()
        var copy = lovelace
        NSDecimalRound(&rounded, &copy, 0, .plain)
        guard rounded == lovelace else { return nil }
        return NSDecimalNumber(decimal: rounded).uint64Value
    }

    /// Parse `input` into ADA. Returns `nil` if the input is malformed or negative.
    public func toAda(_ input: String) -> Decimal? {
        guard let parsed = parse(input) else { return nil }
        let ada: Decimal
        switch parsed.unit {
        case .ada: ada = parsed.value
        case .lovelace: ada = parsed.value / Self.lovelacePerAda
        }
        return ada >= 0 ? ada : nil
    }

    // MARK: - Internal parsing

    private struct Parsed {
        let value: Decimal
        let unit: AdaUnit
    }

    private func parse(_ input: String) -> Parsed? {
        var working = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !working.isEmpty else { return nil }

        var detectedUnit: AdaUnit?

        // ₳ prefix
        if working.hasPrefix("₳") {
            detectedUnit = .ada
            working.removeFirst()
            working = working.trimmingCharacters(in: .whitespaces)
        }

        // Suffix detection (longest match first, case-insensitive).
        // ada/lovelace markers — must match before single-letter "l" multiplier.
        let suffixes: [(String, AdaUnit)] = [
            ("lovelaces", .lovelace),
            ("lovelace", .lovelace),
            ("ada", .ada),
            ("₳", .ada),
            ("l", .lovelace),
        ]
        for (suffix, candidate) in suffixes {
            if working.lowercased().hasSuffix(suffix) {
                if let detected = detectedUnit, detected != candidate { return nil }
                detectedUnit = candidate
                working.removeLast(suffix.count)
                working = working.trimmingCharacters(in: .whitespaces)
                break
            }
        }

        // Strip thousand separators.
        working = working.replacingOccurrences(of: "_", with: "")
        working = working.replacingOccurrences(of: ",", with: "")

        // Multiplier suffix (K / M / B).
        var multiplier: Decimal = 1
        if let last = working.last {
            switch String(last).lowercased() {
            case "k": multiplier = 1_000; working.removeLast()
            case "m": multiplier = 1_000_000; working.removeLast()
            case "b": multiplier = 1_000_000_000; working.removeLast()
            default: break
            }
            working = working.trimmingCharacters(in: .whitespaces)
        }

        guard !working.isEmpty,
              let value = Decimal(string: working)
        else { return nil }

        return Parsed(value: value * multiplier, unit: detectedUnit ?? defaultUnit)
    }
}

/// A validation rule that accepts the same input forms as `AdaFormatter` and
/// checks that the resolved lovelace amount falls within `[min, max]`.
public struct AdaValidationRule: ValidatableRule {
    public let error: ValidatableError
    private let formatter: AdaFormatter
    private let minLovelace: UInt64
    private let maxLovelace: UInt64

    /// - Parameters:
    ///   - defaultUnit: Unit assumed when the input has no explicit marker.
    ///   - minLovelace: Lower bound in lovelace (default 0).
    ///   - maxLovelace: Upper bound in lovelace (default `UInt64.max`).
    public init(
        defaultUnit: AdaUnit = .ada,
        minLovelace: UInt64 = 0,
        maxLovelace: UInt64 = .max,
        error: ValidatableError
    ) {
        self.formatter = AdaFormatter(defaultUnit: defaultUnit)
        self.minLovelace = minLovelace
        self.maxLovelace = maxLovelace
        self.error = error
    }

    public func validate(input: String) -> Bool {
        guard let lovelace = formatter.toLovelace(input) else { return false }
        return lovelace >= minLovelace && lovelace <= maxLovelace
    }
}
