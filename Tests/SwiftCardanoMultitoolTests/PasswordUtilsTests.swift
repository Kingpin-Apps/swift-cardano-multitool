import Testing
@testable import SwiftCardanoMultitoolLib

@Suite("PasswordUtils.isStrong")
struct PasswordUtilsTests {

    // MARK: - Valid passwords

    @Test("accepts a strong password with all required character types")
    func strongPassword() {
        #expect(PasswordUtils("SecurePass1!").isStrong() == true)
    }

    @Test("accepts password using all special character types")
    func strongPasswordSpecialChars() {
        #expect(PasswordUtils("MyP@ssw0rd#").isStrong() == true)
    }

    @Test("accepts a long strong password")
    func longStrongPassword() {
        #expect(PasswordUtils("Th!s1sAV3ryL0ngPassword!").isStrong() == true)
    }

    // MARK: - Length

    @Test("rejects password shorter than 10 characters")
    func tooShort() {
        // 9 chars: has upper, lower, digit, special — but too short
        #expect(PasswordUtils("Short1!aB").isStrong() == false)
    }

    @Test("accepts password of exactly 10 characters")
    func exactlyTenChars() {
        #expect(PasswordUtils("Passw0rd1!").isStrong() == true)
    }

    // MARK: - Required character categories

    @Test("rejects password without uppercase letter")
    func missingUppercase() {
        #expect(PasswordUtils("nouppercase1!").isStrong() == false)
    }

    @Test("rejects password without lowercase letter")
    func missingLowercase() {
        #expect(PasswordUtils("NOLOWERCASE1!").isStrong() == false)
    }

    @Test("rejects password without digit")
    func missingDigit() {
        #expect(PasswordUtils("NoDigitHere!").isStrong() == false)
    }

    @Test("rejects password without special character")
    func missingSpecialChar() {
        #expect(PasswordUtils("NoSpecialChar1").isStrong() == false)
    }

    // MARK: - Spaces

    @Test("rejects password containing a space")
    func containsSpace() {
        #expect(PasswordUtils("Secure Pass1!").isStrong() == false)
    }

    @Test("rejects password that is only spaces")
    func onlySpaces() {
        #expect(PasswordUtils("          ").isStrong() == false)
    }

    // MARK: - Edge cases

    @Test("rejects empty password")
    func emptyPassword() {
        #expect(PasswordUtils("").isStrong() == false)
    }
}
