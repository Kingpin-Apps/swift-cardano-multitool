import Foundation
import Testing
import SystemPackage
import SwiftCardanoCore
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

    // MARK: - parseAssetName edge cases

    @Test("parseAssetName rejects odd-length hex inside braces")
    func rejectsOddLengthHexInBraces() {
        #expect(throws: (any Error).self) {
            _ = try parseAssetName("{abc}")
        }
    }

    @Test("parseAssetName rejects non-hex characters inside braces")
    func rejectsNonHexInBraces() {
        #expect(throws: (any Error).self) {
            _ = try parseAssetName("{zzgg}")
        }
    }

    @Test("parseAssetName rejects names longer than 32 bytes")
    func rejectsTooLongName() {
        let name = String(repeating: "a", count: 33)
        #expect(throws: (any Error).self) {
            _ = try parseAssetName(name)
        }
    }

    @Test("parseAssetName rejects {hex} longer than 64 chars (32 bytes)")
    func rejectsTooLongHexInBraces() {
        let hex = "{" + String(repeating: "ab", count: 33) + "}"
        #expect(throws: (any Error).self) {
            _ = try parseAssetName(hex)
        }
    }

    @Test("parseAssetName rejects invalid characters in plain name (e.g. spaces)")
    func rejectsSpaces() {
        #expect(throws: (any Error).self) {
            _ = try parseAssetName("my token")
        }
    }

    @Test("parseAssetName lowercases hex in braced form")
    func bracedHexLowercased() throws {
        // Input: {4D79546F6B}  Expected hex: 4d79546f6b
        let r = try parseAssetName("{4D79546F6B}")
        #expect(r.hex == "4d79546f6b")
        #expect(r.display == "MyTok")
    }

    @Test("parseAssetName uses raw hex string as display when hex bytes are not valid UTF-8")
    func nonUtf8HexUsesRawDisplay() throws {
        // ff is invalid as a leading UTF-8 byte; expect display to fall back to raw {…} form.
        let r = try parseAssetName("{ff}")
        #expect(r.hex == "ff")
        #expect(r.display == "{ff}")
    }

    @Test("parseAssetName accepts a name of exactly 32 bytes")
    func accepts32ByteName() throws {
        let name = String(repeating: "a", count: 32)
        let r = try parseAssetName(name)
        #expect(r.display == name)
    }

    // MARK: - resolveAssetSubject

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-tests-amu-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("resolveAssetSubject accepts a valid hex subject directly")
    func resolveValidHexSubject() throws {
        let hex = String(repeating: "ab", count: 32) // 64 hex chars
        let result = try resolveAssetSubject(input: hex)
        #expect(result == hex)
    }

    @Test("resolveAssetSubject lowercases an uppercase hex subject")
    func resolveUppercaseHex() throws {
        let upper = String(repeating: "AB", count: 32)
        let lower = String(repeating: "ab", count: 32)
        let result = try resolveAssetSubject(input: upper)
        #expect(result == lower)
    }

    @Test("resolveAssetSubject trims whitespace before validating")
    func resolveTrimsWhitespace() throws {
        let hex = String(repeating: "ab", count: 32)
        let result = try resolveAssetSubject(input: "  \(hex)  ")
        #expect(result == hex)
    }

    @Test("resolveAssetSubject reads a JSON file with a top-level subject field")
    func resolveFromAssetFile() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("token.asset")
        let subject = String(repeating: "cd", count: 32)
        let json: [String: Any] = ["subject": subject]
        let data = try JSONSerialization.data(withJSONObject: json)
        try data.write(to: url)

        let result = try resolveAssetSubject(input: url.path)
        #expect(result == subject)
    }

    @Test("resolveAssetSubject throws when input is neither a file nor a valid hex subject")
    func resolveRejectsGarbage() {
        #expect(throws: (any Error).self) {
            _ = try resolveAssetSubject(input: "not-a-subject")
        }
    }

    @Test("resolveAssetSubject throws for a .asset file missing the subject field")
    func resolveRejectsFileWithoutSubject() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("nosubj.asset")
        let json: [String: Any] = ["other_field": "x"]
        let data = try JSONSerialization.data(withJSONObject: json)
        try data.write(to: url)

        #expect(throws: (any Error).self) {
            _ = try resolveAssetSubject(input: url.path)
        }
    }

    @Test("resolveAssetSubject throws for a .asset file with malformed JSON")
    func resolveRejectsMalformedJSON() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("bad.asset")
        try Data("{ not valid".utf8).write(to: url)

        #expect(throws: (any Error).self) {
            _ = try resolveAssetSubject(input: url.path)
        }
    }
}

// MARK: - loadPolicyForAssetMeta

@Suite("loadPolicyForAssetMeta")
struct LoadPolicyForAssetMetaTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-tests-lpfam-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func writeSigOnlyPolicy(name: String, in dir: URL) throws {
        let dirPath = FilePath(dir.path)
        let policyIdFile = dirPath.appending("\(name).policy.id")
        let scriptFile = dirPath.appending("\(name).policy.script")
        let skeyFile = dirPath.appending("\(name).policy.skey")

        // Minimal sig-only NativeScript with a fake 28-byte key hash.
        let keyHashHex = String(repeating: "a", count: 56)
        let script = NativeScript.scriptPubkey(
            ScriptPubkey(keyHash: VerificationKeyHash(payload: keyHashHex.hexStringToData))
        )
        try script.saveJSON(to: scriptFile.string)

        // Write placeholder policy id and skey (just need files to exist for the loader).
        try Data(keyHashHex.utf8).write(to: URL(fileURLWithPath: policyIdFile.string))
        try Data("placeholder".utf8).write(to: URL(fileURLWithPath: skeyFile.string))
    }

    @Test("loads a sig-only policy with all three files present")
    func loadsSigOnlyPolicy() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try writeSigOnlyPolicy(name: "mypolicy", in: dir)

        let loaded = try loadPolicyForAssetMeta(name: "mypolicy", in: FilePath(dir.path))
        #expect(loaded.policyId == String(repeating: "a", count: 56))
        #expect(loaded.validBeforeSlot == nil)
        #expect(loaded.skeyPath.string.hasSuffix("mypolicy.policy.skey"))
    }

    @Test("throws when policy.id is missing")
    func throwsOnMissingPolicyId() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        // Don't write any files.
        #expect(throws: (any Error).self) {
            _ = try loadPolicyForAssetMeta(name: "missing", in: FilePath(dir.path))
        }
    }

    @Test("throws when only hwsfile is present (no software skey)")
    func throwsOnHardwareOnlyPolicy() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let dirPath = FilePath(dir.path)
        let name = "hwpol"

        // Write id + script + hwsfile but no skey.
        let keyHashHex = String(repeating: "a", count: 56)
        let script = NativeScript.scriptPubkey(
            ScriptPubkey(keyHash: VerificationKeyHash(payload: keyHashHex.hexStringToData))
        )
        try script.saveJSON(to: dirPath.appending("\(name).policy.script").string)
        try Data(keyHashHex.utf8).write(to: URL(fileURLWithPath: dirPath.appending("\(name).policy.id").string))
        try Data("hw-placeholder".utf8).write(to: URL(fileURLWithPath: dirPath.appending("\(name).policy.hwsfile").string))

        #expect(throws: (any Error).self) {
            _ = try loadPolicyForAssetMeta(name: name, in: dirPath)
        }
    }
}
