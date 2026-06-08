import Foundation
import Testing
import SystemPackage
@testable import SwiftCardanoMultitool

@Suite("AssetMetaUtils")
struct AssetMetaUtilsTests {

    // MARK: - isValidAssetSubject

    @Test("isValidAssetSubject accepts a 56-char hex subject (policy ID only)")
    func acceptsPolicyOnly() {
        let subject = String(repeating: "a", count: 56)
        #expect(isValidAssetSubject(subject) == true)
    }

    @Test("isValidAssetSubject accepts a 64-char hex subject")
    func accepts64() {
        let subject = String(repeating: "a", count: 64)
        #expect(isValidAssetSubject(subject) == true)
    }

    @Test("isValidAssetSubject accepts a 120-char hex subject (policy + 32-byte asset)")
    func accepts120() {
        let subject = String(repeating: "0", count: 120)
        #expect(isValidAssetSubject(subject) == true)
    }

    @Test("isValidAssetSubject rejects strings shorter than 56 chars")
    func rejectsTooShort() {
        let subject = String(repeating: "a", count: 55)
        #expect(isValidAssetSubject(subject) == false)
    }

    @Test("isValidAssetSubject rejects strings longer than 120 chars")
    func rejectsTooLong() {
        let subject = String(repeating: "a", count: 121)
        #expect(isValidAssetSubject(subject) == false)
    }

    @Test("isValidAssetSubject rejects non-hex characters")
    func rejectsNonHex() {
        let badChar = "z" + String(repeating: "a", count: 55)
        #expect(isValidAssetSubject(badChar) == false)
    }

    // MARK: - parseAssetName

    @Test("parseAssetName('') returns empty display + hex")
    func emptyParse() throws {
        let r = try parseAssetName("")
        #expect(r.display == "")
        #expect(r.hex == "")
    }

    @Test("parseAssetName('MYTOK') hex-encodes the UTF-8 bytes")
    func plainName() throws {
        let r = try parseAssetName("MYTOK")
        #expect(r.display == "MYTOK")
        #expect(r.hex == "4d59544f4b")
    }

    @Test("parseAssetName('{hex}') unwraps the hex form")
    func braceHexForm() throws {
        // 4d79546f6b = "MyTok"
        let r = try parseAssetName("{4d79546f6b}")
        #expect(r.hex == "4d79546f6b")
        #expect(r.display == "MyTok")
    }

    @Test("parseAssetName trims whitespace")
    func trimsWhitespace() throws {
        let r = try parseAssetName("  ABC  ")
        #expect(r.display == "ABC")
        #expect(r.hex == "414243")
    }

    @Test("parseAssetName accepts dot/dash/underscore")
    func acceptsAllowedChars() throws {
        let r = try parseAssetName("my_token-1.0")
        #expect(r.display == "my_token-1.0")
    }

    // MARK: - rfc2822Timestamp

    @Test("rfc2822Timestamp formats a known date in UTC")
    func timestampFormat() {
        let fixed = Date(timeIntervalSince1970: 0) // 1970-01-01 UTC
        let s = rfc2822Timestamp(fixed)
        // RFC 2822 baseline: "Thu, 01 Jan 1970 00:00:00 +0000"
        #expect(s == "Thu, 01 Jan 1970 00:00:00 +0000")
    }
}
