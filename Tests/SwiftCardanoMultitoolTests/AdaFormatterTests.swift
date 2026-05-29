import Testing
@testable import SwiftCardanoMultitool

@Suite("AdaFormatter")
struct AdaFormatterTests {

    // MARK: - Default unit (ADA)

    @Test("plain integer treated as ADA by default")
    func plainIntegerAsAda() {
        let f = AdaFormatter()
        #expect(f.toLovelace("100") == 100_000_000)
    }

    @Test("decimal ADA value")
    func decimalAda() {
        let f = AdaFormatter()
        #expect(f.toLovelace("1.5") == 1_500_000)
    }

    @Test("zero is valid")
    func zero() {
        #expect(AdaFormatter().toLovelace("0") == 0)
    }

    // MARK: - Default unit (lovelace)

    @Test("plain integer treated as lovelace when configured")
    func plainIntegerAsLovelace() {
        let f = AdaFormatter(defaultUnit: .lovelace)
        #expect(f.toLovelace("100") == 100)
    }

    @Test("fractional lovelace is rejected")
    func fractionalLovelaceRejected() {
        let f = AdaFormatter(defaultUnit: .lovelace)
        #expect(f.toLovelace("1.5") == nil)
    }

    // MARK: - Multipliers

    @Test("K suffix multiplies by 1_000")
    func suffixK() {
        let f = AdaFormatter()
        #expect(f.toLovelace("1K") == 1_000 * 1_000_000)
        #expect(f.toLovelace("1.5k") == 1_500 * 1_000_000)
    }

    @Test("M suffix multiplies by 1_000_000")
    func suffixM() {
        let f = AdaFormatter()
        #expect(f.toLovelace("2M") == 2_000_000 * 1_000_000)
    }

    @Test("B suffix multiplies by 1_000_000_000")
    func suffixB() {
        let f = AdaFormatter()
        #expect(f.toLovelace("1b") == 1_000_000_000 * 1_000_000)
    }

    @Test("multiplier with lovelace default")
    func multiplierLovelace() {
        let f = AdaFormatter(defaultUnit: .lovelace)
        #expect(f.toLovelace("100K") == 100_000)
    }

    // MARK: - Separators

    @Test("underscores stripped")
    func underscores() {
        let f = AdaFormatter()
        #expect(f.toLovelace("1_000") == 1_000_000_000)
    }

    @Test("commas stripped")
    func commas() {
        let f = AdaFormatter()
        #expect(f.toLovelace("1,000,000") == 1_000_000_000_000)
    }

    @Test("mixed separators with multiplier")
    func mixedSeparators() {
        let f = AdaFormatter(defaultUnit: .lovelace)
        #expect(f.toLovelace("1_000K") == 1_000_000)
    }

    // MARK: - Explicit ADA marker

    @Test("ADA suffix")
    func adaSuffix() {
        let f = AdaFormatter(defaultUnit: .lovelace)
        #expect(f.toLovelace("100 ADA") == 100_000_000)
        #expect(f.toLovelace("100ada") == 100_000_000)
    }

    @Test("₳ prefix")
    func adaPrefix() {
        let f = AdaFormatter(defaultUnit: .lovelace)
        #expect(f.toLovelace("₳100") == 100_000_000)
    }

    @Test("₳ suffix")
    func adaSymbolSuffix() {
        let f = AdaFormatter(defaultUnit: .lovelace)
        #expect(f.toLovelace("100₳") == 100_000_000)
    }

    // MARK: - Explicit lovelace marker

    @Test("lovelace suffix")
    func lovelaceSuffix() {
        let f = AdaFormatter()
        #expect(f.toLovelace("1000000 lovelace") == 1_000_000)
        #expect(f.toLovelace("1000000lovelaces") == 1_000_000)
    }

    @Test("L single-letter suffix")
    func lShortSuffix() {
        let f = AdaFormatter()
        #expect(f.toLovelace("100L") == 100)
    }

    // MARK: - Combined

    @Test("ADA with multiplier and separators")
    func adaWithMultiplierAndSeparators() {
        let f = AdaFormatter()
        #expect(f.toLovelace("1.5K ADA") == 1_500 * 1_000_000)
        #expect(f.toLovelace("100K ada") == 100_000 * 1_000_000)
        #expect(f.toLovelace("₳1.5M") == 1_500_000 * 1_000_000)
    }

    @Test("lovelace with multiplier")
    func lovelaceWithMultiplier() {
        let f = AdaFormatter()
        #expect(f.toLovelace("1M lovelace") == 1_000_000)
    }

    // MARK: - Whitespace tolerance

    @Test("leading and trailing whitespace ignored")
    func whitespace() {
        let f = AdaFormatter()
        #expect(f.toLovelace("  100 ADA  ") == 100_000_000)
    }

    // MARK: - Invalid inputs

    @Test("empty string rejected")
    func empty() {
        #expect(AdaFormatter().toLovelace("") == nil)
        #expect(AdaFormatter().toLovelace("   ") == nil)
    }

    @Test("non-numeric rejected")
    func nonNumeric() {
        #expect(AdaFormatter().toLovelace("abc") == nil)
        #expect(AdaFormatter().toLovelace("ADA") == nil)
        #expect(AdaFormatter().toLovelace("₳") == nil)
    }

    @Test("conflicting unit markers rejected")
    func conflictingMarkers() {
        #expect(AdaFormatter().toLovelace("₳100 lovelace") == nil)
    }

    @Test("fractional lovelace from ADA conversion rejected")
    func fractionalLovelaceFromAda() {
        let f = AdaFormatter()
        #expect(f.toLovelace("0.0000001 ADA") == nil)
    }

    @Test("negative values rejected")
    func negative() {
        #expect(AdaFormatter().toLovelace("-100") == nil)
        #expect(AdaFormatter().toLovelace("-100 ADA") == nil)
    }

    // MARK: - toAda

    @Test("toAda from lovelace input")
    func toAdaFromLovelace() {
        let f = AdaFormatter()
        #expect(f.toAda("1_000_000 lovelace") == 1)
    }

    @Test("toAda from ADA input")
    func toAdaFromAda() {
        let f = AdaFormatter()
        #expect(f.toAda("1.5K ADA") == 1_500)
    }
}

@Suite("AdaValidationRule")
struct AdaValidationRuleTests {

    @Test("accepts valid ADA input within range")
    func accepts() {
        let rule = AdaValidationRule(
            minLovelace: 0,
            maxLovelace: 1_000_000_000,
            error: "Out of range."
        )
        #expect(rule.validate(input: "100 lovelace") == true)
        #expect(rule.validate(input: "1K") == true) // 1K ADA = 1B lovelace
    }

    @Test("rejects below minimum")
    func rejectsBelowMin() {
        let rule = AdaValidationRule(
            minLovelace: 170_000_000,
            error: "Too small."
        )
        #expect(rule.validate(input: "169 ADA") == false)
        #expect(rule.validate(input: "170 ADA") == true)
    }

    @Test("rejects above maximum")
    func rejectsAboveMax() {
        let rule = AdaValidationRule(
            maxLovelace: 1_000_000_000,
            error: "Too large."
        )
        #expect(rule.validate(input: "1001 ADA") == false)
    }

    @Test("rejects malformed input")
    func rejectsMalformed() {
        let rule = AdaValidationRule(error: "Invalid.")
        #expect(rule.validate(input: "") == false)
        #expect(rule.validate(input: "abc") == false)
    }

    @Test("defaults to ADA unit")
    func defaultUnitIsAda() {
        let rule = AdaValidationRule(
            minLovelace: 1_000_000,
            error: "Too small."
        )
        // "1" with ADA default = 1 ADA = 1M lovelace, matches min.
        #expect(rule.validate(input: "1") == true)
    }

    @Test("lovelace default unit honoured")
    func lovelaceDefault() {
        let rule = AdaValidationRule(
            defaultUnit: .lovelace,
            minLovelace: 1_000_000,
            error: "Too small."
        )
        #expect(rule.validate(input: "999999") == false)
        #expect(rule.validate(input: "1000000") == true)
    }
}
