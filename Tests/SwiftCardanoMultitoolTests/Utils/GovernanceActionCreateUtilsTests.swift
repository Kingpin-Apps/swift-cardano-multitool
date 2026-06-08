import Foundation
import Testing
import SwiftCardanoCore
@testable import SwiftCardanoMultitool

@Suite("GovernanceActionCreateUtils")
struct GovernanceActionCreateUtilsTests {

    // MARK: - parseScriptHash

    @Test("parseScriptHash returns nil for nil input")
    func nilInputReturnsNil() throws {
        let result = try parseScriptHash(nil)
        #expect(result == nil)
    }

    @Test("parseScriptHash returns nil for empty input")
    func emptyInputReturnsNil() throws {
        let result = try parseScriptHash("")
        #expect(result == nil)
    }

    @Test("parseScriptHash returns nil for whitespace-only input")
    func whitespaceReturnsNil() throws {
        let result = try parseScriptHash("   ")
        #expect(result == nil)
    }

    @Test("parseScriptHash accepts a valid 56-char hex")
    func acceptsValidHex() throws {
        let hex = String(repeating: "a", count: 56)
        let result = try parseScriptHash(hex)
        #expect(result?.payload == hex.hexStringToData)
    }

    @Test("parseScriptHash lowercases mixed-case input")
    func lowercasesInput() throws {
        let hex = String(repeating: "A", count: 56)
        let result = try parseScriptHash(hex)
        let expected = String(repeating: "a", count: 56).hexStringToData
        #expect(result?.payload == expected)
    }

    @Test("parseScriptHash rejects wrong-length hex")
    func rejectsShortHex() {
        let hex = String(repeating: "a", count: 55)
        #expect(throws: (any Error).self) {
            _ = try parseScriptHash(hex)
        }
    }

    @Test("parseScriptHash rejects non-hex characters")
    func rejectsNonHex() {
        let hex = "z" + String(repeating: "a", count: 55)
        #expect(throws: (any Error).self) {
            _ = try parseScriptHash(hex)
        }
    }

    // MARK: - parseUnitInterval

    @Test("parseUnitInterval parses numerator/denominator form")
    func parsesRational() throws {
        let r = try parseUnitInterval("2/3")
        #expect(r.numerator == 2)
        #expect(r.denominator == 3)
    }

    @Test("parseUnitInterval parses a plain decimal")
    func parsesDecimal() throws {
        let r = try parseUnitInterval("0.5")
        #expect(r.denominator == 1_000_000)
        #expect(r.numerator == 500_000)
    }

    @Test("parseUnitInterval rejects denominator 0")
    func rejectsZeroDenominator() {
        #expect(throws: (any Error).self) {
            _ = try parseUnitInterval("1/0")
        }
    }

    @Test("parseUnitInterval rejects garbage")
    func rejectsGarbage() {
        #expect(throws: (any Error).self) {
            _ = try parseUnitInterval("abc")
        }
    }

    @Test("parseUnitInterval rejects decimal > 1")
    func rejectsAboveOne() {
        #expect(throws: (any Error).self) {
            _ = try parseUnitInterval("1.5")
        }
    }

    @Test("parseUnitInterval rejects negative decimal")
    func rejectsNegative() {
        #expect(throws: (any Error).self) {
            _ = try parseUnitInterval("-0.5")
        }
    }

    // MARK: - parseColdCredential

    @Test("parseColdCredential accepts a 56-char hex hash as a key credential")
    func acceptsKeyHash() throws {
        let hex = String(repeating: "a", count: 56)
        let (cred, lower) = try parseColdCredential(hex, isScript: false)
        #expect(lower == hex)
        if case .verificationKeyHash = cred.credential {
            // OK
        } else {
            Issue.record("Expected verificationKeyHash, got \(cred.credential)")
        }
    }

    @Test("parseColdCredential treats isScript as scriptHash")
    func acceptsScriptHash() throws {
        let hex = String(repeating: "b", count: 56)
        let (cred, _) = try parseColdCredential(hex, isScript: true)
        if case .scriptHash = cred.credential {
            // OK
        } else {
            Issue.record("Expected scriptHash, got \(cred.credential)")
        }
    }

    @Test("parseColdCredential rejects too-short input")
    func rejectsBadLength() {
        #expect(throws: (any Error).self) {
            _ = try parseColdCredential("aa", isScript: false)
        }
    }

    // MARK: - parseGovActionID

    @Test("parseGovActionID returns nil for nil input")
    func govActionNilInputReturnsNil() throws {
        let r = try parseGovActionID(nil)
        #expect(r == nil)
    }

    @Test("parseGovActionID returns nil for empty input")
    func govActionEmptyReturnsNil() throws {
        let r = try parseGovActionID("")
        #expect(r == nil)
    }

    @Test("parseGovActionID rejects garbage input")
    func rejectsGarbageGovActionID() {
        #expect(throws: (any Error).self) {
            _ = try parseGovActionID("not-a-gov-action-id")
        }
    }
}
