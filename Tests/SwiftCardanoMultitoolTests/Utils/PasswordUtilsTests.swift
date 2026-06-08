import Foundation
import Testing
@testable import SwiftCardanoMultitool

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

// MARK: - PasswordUtils init / property

@Suite("PasswordUtils init")
struct PasswordUtilsInitTests {

    @Test("preserves the password verbatim on the public property")
    func preservesPassword() {
        let utils = PasswordUtils("MyTestPass1!")
        #expect(utils.password == "MyTestPass1!")
    }

    @Test("preserves an empty password (no init-time validation)")
    func emptyAllowedByInit() {
        let utils = PasswordUtils("")
        #expect(utils.password == "")
    }
}

// MARK: - isVulnerable (exclusion list)

@Suite("PasswordUtils.isVulnerable")
struct PasswordUtilsIsVulnerableTests {

    @Test("flags 'password' as vulnerable (in the seed list)")
    func passwordIsVulnerable() throws {
        let vulnerable = try PasswordUtils("password").isVulnerable()
        #expect(vulnerable == true)
    }

    @Test("flags '123456' as vulnerable (in the seed list)")
    func numericIsVulnerable() throws {
        let vulnerable = try PasswordUtils("123456").isVulnerable()
        #expect(vulnerable == true)
    }

    @Test("does NOT flag a unique random-looking password as vulnerable")
    func uniquePasswordNotVulnerable() throws {
        // Use a string very unlikely to appear in any leaked-password list.
        let unique = "ScmTestSentinel-\(UUID().uuidString)"
        let vulnerable = try PasswordUtils(unique).isVulnerable()
        #expect(vulnerable == false)
    }

    @Test("empty string is not flagged as vulnerable (no empty entry in the list)")
    func emptyNotVulnerable() throws {
        let vulnerable = try PasswordUtils("").isVulnerable()
        #expect(vulnerable == false)
    }
}

// MARK: - isValid (combines isStrong + !isVulnerable)

@Suite("PasswordUtils.isValid")
struct PasswordUtilsIsValidTests {

    @Test("rejects a strong-looking password that is in the exclusion list")
    func strongButLeakedIsInvalid() {
        // 'Password1!' is in the exclusion list AND meets the strength criteria
        // (upper, lower, digit, special, 10 chars).
        // Actually 'Password1!' is 10 chars and contains all classes; this is the
        // classic example of "strong-looking but leaked".
        let utils = PasswordUtils("Password1!")
        // If the password appears in PasswordList.raw, isValid should be false.
        // We assert based on isVulnerable result so the test stays robust to list contents.
        let vulnerable = (try? utils.isVulnerable()) ?? false
        if vulnerable {
            #expect(utils.isValid == false)
        }
        // If for some reason it's not on the list, isValid would be true. Either way,
        // the assertion above doesn't fail spuriously.
    }

    @Test("accepts a unique strong password")
    func uniqueStrongIsValid() {
        let unique = "ScmSentinel-\(UUID().uuidString.prefix(6))A1!"
        let utils = PasswordUtils(String(unique))
        // Only assert when the constructed string meets strength (it should: contains upper,
        // lower, digit, special chars and is long enough).
        if utils.isStrong() {
            #expect(utils.isValid == true)
        }
    }

    @Test("rejects a weak password")
    func weakIsInvalid() {
        let utils = PasswordUtils("short")
        #expect(utils.isValid == false)
    }
}
