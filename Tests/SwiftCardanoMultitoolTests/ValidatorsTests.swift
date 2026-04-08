import Testing
@testable import SwiftCardanoMultitoolLib

@Suite("IntegerValidationRule")
struct ValidatorsTests {

    // MARK: - Basic integer parsing

    @Test("accepts a valid integer within default range")
    func validIntegerDefaultRange() {
        let rule = IntegerValidationRule(error: "Invalid integer.")
        #expect(rule.validate(input: "42") == true)
    }

    @Test("accepts zero with default min of zero")
    func validZero() {
        let rule = IntegerValidationRule(error: "Invalid integer.")
        #expect(rule.validate(input: "0") == true)
    }

    @Test("rejects non-numeric input")
    func rejectsNonNumeric() {
        let rule = IntegerValidationRule(error: "Invalid integer.")
        #expect(rule.validate(input: "abc") == false)
    }

    @Test("rejects empty string")
    func rejectsEmpty() {
        let rule = IntegerValidationRule(error: "Invalid integer.")
        #expect(rule.validate(input: "") == false)
    }

    @Test("rejects decimal string")
    func rejectsDecimal() {
        let rule = IntegerValidationRule(error: "Invalid integer.")
        #expect(rule.validate(input: "3.14") == false)
    }

    // MARK: - Min bound

    @Test("accepts value equal to min")
    func acceptsExactMin() {
        let rule = IntegerValidationRule(min: 5, error: "Too small.")
        #expect(rule.validate(input: "5") == true)
    }

    @Test("rejects value below min")
    func rejectsBelowMin() {
        let rule = IntegerValidationRule(min: 5, error: "Too small.")
        #expect(rule.validate(input: "4") == false)
    }

    @Test("rejects negative value when min is zero")
    func rejectsNegativeWithDefaultMin() {
        let rule = IntegerValidationRule(error: "Invalid integer.")
        #expect(rule.validate(input: "-1") == false)
    }

    // MARK: - Max bound

    @Test("accepts value equal to max")
    func acceptsExactMax() {
        let rule = IntegerValidationRule(max: 65535, error: "Too large.")
        #expect(rule.validate(input: "65535") == true)
    }

    @Test("rejects value above max")
    func rejectsAboveMax() {
        let rule = IntegerValidationRule(max: 65535, error: "Too large.")
        #expect(rule.validate(input: "65536") == false)
    }

    // MARK: - Min and max together

    @Test("accepts value within min-max range")
    func acceptsWithinRange() {
        let rule = IntegerValidationRule(min: 1, max: 65535, error: "Out of range.")
        #expect(rule.validate(input: "8080") == true)
    }

    @Test("rejects value outside min-max range on both sides")
    func rejectsOutsideRange() {
        let rule = IntegerValidationRule(min: 1, max: 65535, error: "Out of range.")
        #expect(rule.validate(input: "0") == false)
        #expect(rule.validate(input: "65536") == false)
    }
}
