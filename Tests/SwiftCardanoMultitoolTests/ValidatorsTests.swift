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

@Suite("PortOrEmptyValidationRule")
struct PortOrEmptyValidationRuleTests {

    @Test("accepts empty string")
    func acceptsEmpty() {
        let rule = PortOrEmptyValidationRule(error: "Invalid port.")
        #expect(rule.validate(input: "") == true)
        #expect(rule.validate(input: "   ") == true)
    }

    @Test("accepts valid port")
    func acceptsValidPort() {
        let rule = PortOrEmptyValidationRule(error: "Invalid port.")
        #expect(rule.validate(input: "1") == true)
        #expect(rule.validate(input: "3001") == true)
        #expect(rule.validate(input: "65535") == true)
    }

    @Test("rejects out-of-range port")
    func rejectsOutOfRange() {
        let rule = PortOrEmptyValidationRule(error: "Invalid port.")
        #expect(rule.validate(input: "0") == false)
        #expect(rule.validate(input: "65536") == false)
    }

    @Test("rejects non-numeric input")
    func rejectsNonNumeric() {
        let rule = PortOrEmptyValidationRule(error: "Invalid port.")
        #expect(rule.validate(input: "abc") == false)
        #expect(rule.validate(input: "30a1") == false)
    }
}

@Suite("PoolIdValidationRule")
struct PoolIdValidationRuleTests {

    @Test("accepts valid bech32 pool ID")
    func acceptsBech32() {
        let rule = PoolIdValidationRule(error: "Invalid pool ID.")
        // Real bech32 pool ID
        #expect(rule.validate(input: "pool1z5uqdk7dzdxaae5633fqfcu2eqzy3a3rgtuvy087fdld7yws0xt") == true)
    }

    @Test("accepts 56-character hex")
    func acceptsHex() {
        let rule = PoolIdValidationRule(error: "Invalid pool ID.")
        // 28 bytes → 56 hex chars
        #expect(rule.validate(input: String(repeating: "ab", count: 28)) == true)
    }

    @Test("accepts hex with 0x prefix")
    func acceptsHexWithPrefix() {
        let rule = PoolIdValidationRule(error: "Invalid pool ID.")
        #expect(rule.validate(input: "0x" + String(repeating: "ab", count: 28)) == true)
    }

    @Test("rejects empty")
    func rejectsEmpty() {
        let rule = PoolIdValidationRule(error: "Invalid pool ID.")
        #expect(rule.validate(input: "") == false)
        #expect(rule.validate(input: "   ") == false)
    }

    @Test("rejects wrong-length hex")
    func rejectsWrongHexLength() {
        let rule = PoolIdValidationRule(error: "Invalid pool ID.")
        #expect(rule.validate(input: "deadbeef") == false)
        #expect(rule.validate(input: String(repeating: "a", count: 57)) == false)
    }

    @Test("rejects bech32 with wrong HRP")
    func rejectsWrongHrp() {
        let rule = PoolIdValidationRule(error: "Invalid pool ID.")
        // valid bech32 shape but not a "pool" HRP
        #expect(rule.validate(input: "addr1qxabc") == false)
    }

    @Test("rejects non-hex chars in hex-length string")
    func rejectsNonHex() {
        let rule = PoolIdValidationRule(error: "Invalid pool ID.")
        // 56 chars but contains non-hex
        let bad = String(repeating: "z", count: 56)
        #expect(rule.validate(input: bad) == false)
    }
}
