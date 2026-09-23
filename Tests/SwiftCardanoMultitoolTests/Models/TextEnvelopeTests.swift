import Foundation
import Testing
import SystemPackage
import SwiftCardanoCore
@testable import SwiftCardanoMultitool

@Suite("TextEnvelope computed properties")
struct TextEnvelopeComputedTests {

    @Test("isHardwareKey is true when description mentions ledger")
    func isHardwareKeyLedger() {
        let env = TextEnvelope(
            type: "PaymentSigningKeyShelley_ed25519",
            description: "Hardware Ledger Wallet Signing Key",
            cborHex: "abcd",
            encrHex: nil,
            path: nil,
            cborXPubKeyHex: nil
        )
        #expect(env.isHardwareKey == true)
    }

    @Test("isHardwareKey is true when description mentions trezor (case insensitive)")
    func isHardwareKeyTrezor() {
        let env = TextEnvelope(
            type: nil,
            description: "TREZOR signing key",
            cborHex: "",
            encrHex: nil,
            path: nil,
            cborXPubKeyHex: nil
        )
        #expect(env.isHardwareKey == true)
    }

    @Test("isHardwareKey is false for a plain CLI description")
    func isHardwareKeyFalseForCLI() {
        let env = TextEnvelope(
            type: "PaymentSigningKeyShelley_ed25519",
            description: "Payment Signing Key",
            cborHex: "abcd",
            encrHex: nil,
            path: nil,
            cborXPubKeyHex: nil
        )
        #expect(env.isHardwareKey == false)
    }

    @Test("isHardwareKey is false when description is nil")
    func isHardwareKeyFalseForNil() {
        let env = TextEnvelope(
            type: nil,
            description: nil,
            cborHex: nil,
            encrHex: nil,
            path: nil,
            cborXPubKeyHex: nil
        )
        #expect(env.isHardwareKey == false)
    }

    @Test("keyGenType reports .hw when hardware-flavoured")
    func keyGenHardware() {
        let env = TextEnvelope(
            type: nil,
            description: "Ledger signing key",
            cborHex: "abcd",
            encrHex: nil,
            path: nil,
            cborXPubKeyHex: nil
        )
        #expect(env.keyGenType == .hw)
    }

    @Test("keyGenType reports .enc when encrHex is set and not hardware")
    func keyGenEncrypted() {
        let env = TextEnvelope(
            type: nil,
            description: "Encrypted Payment Signing Key",
            cborHex: nil,
            encrHex: "deadbeef",
            path: nil,
            cborXPubKeyHex: nil
        )
        #expect(env.keyGenType == .enc)
    }

    @Test("keyGenType defaults to .cli")
    func keyGenCLI() {
        let env = TextEnvelope(
            type: nil,
            description: "Payment Signing Key",
            cborHex: "abcd",
            encrHex: nil,
            path: nil,
            cborXPubKeyHex: nil
        )
        #expect(env.keyGenType == .cli)
    }

    @Test("isEncrypted requires both encrHex and an Encrypted description")
    func isEncryptedRequiresBoth() {
        // Both present
        let both = TextEnvelope(
            type: nil,
            description: "Encrypted Payment Signing Key",
            cborHex: nil,
            encrHex: "deadbeef",
            path: nil,
            cborXPubKeyHex: nil
        )
        #expect(both.isEncrypted == true)

        // encrHex without Encrypted in description
        let onlyEncr = TextEnvelope(
            type: nil,
            description: "Payment Signing Key",
            cborHex: nil,
            encrHex: "deadbeef",
            path: nil,
            cborXPubKeyHex: nil
        )
        #expect(onlyEncr.isEncrypted == false)

        // Encrypted description but no encrHex
        let onlyDesc = TextEnvelope(
            type: nil,
            description: "Encrypted Payment Signing Key",
            cborHex: "abcd",
            encrHex: nil,
            path: nil,
            cborXPubKeyHex: nil
        )
        #expect(onlyDesc.isEncrypted == false)
    }
}

// MARK: - JSON round-trip

@Suite("TextEnvelope JSON round-trip (sync save/load)")
struct TextEnvelopeJSONTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-tests-te-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("save then loadJSON preserves all fields")
    func saveLoadRoundTrip() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("env.skey")

        let original = TextEnvelope(
            type: "PaymentSigningKeyShelley_ed25519",
            description: "Payment Signing Key",
            cborHex: "deadbeef",
            encrHex: nil,
            path: nil,
            cborXPubKeyHex: nil
        )
        try original.save(to: path.path)

        let loaded = try TextEnvelope.load(from: path.path)
        #expect(loaded.type == "PaymentSigningKeyShelley_ed25519")
        #expect(loaded.description == "Payment Signing Key")
        #expect(loaded.cborHex == "deadbeef")
        #expect(loaded.encrHex == nil)
    }

    @Test("save refuses to overwrite by default")
    func saveJSONRejectsOverwrite() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("env.skey")

        let env = TextEnvelope(type: "T", description: "D", cborHex: "ff", encrHex: nil, path: nil, cborXPubKeyHex: nil)
        try env.save(to: path.path)

        #expect(throws: (any Error).self) {
            try env.save(to: path.path, overwrite: false)
        }
    }

    @Test("save with overwrite: true replaces the file")
    func saveJSONOverwriteAllowed() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("env.skey")

        let first = TextEnvelope(type: "T", description: "first", cborHex: "ff", encrHex: nil, path: nil, cborXPubKeyHex: nil)
        try first.save(to: path.path)

        let second = TextEnvelope(type: "T", description: "second", cborHex: "ee", encrHex: nil, path: nil, cborXPubKeyHex: nil)
        try second.save(to: path.path, overwrite: true)

        let loaded = try TextEnvelope.load(from: path.path)
        #expect(loaded.description == "second")
        #expect(loaded.cborHex == "ee")
    }

    @Test("load throws on a missing file")
    func loadJSONThrowsOnMissingFile() {
        let bogus = "/tmp/scm-te-missing-\(UUID().uuidString).skey"
        #expect(throws: (any Error).self) {
            _ = try TextEnvelope.load(from: bogus)
        }
    }

    @Test("load throws on malformed JSON")
    func loadJSONThrowsOnMalformedJSON() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("bad.skey")
        try Data("{not json".utf8).write(to: path)

        #expect(throws: (any Error).self) {
            _ = try TextEnvelope.load(from: path.path)
        }
    }
}

// MARK: - async TextEnvelope.load(from:)

@Suite("TextEnvelope.load(from path:) (async)")
struct TextEnvelopeAsyncLoadTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-tests-teload-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("loads an unencrypted file without prompting")
    func loadsUnencrypted() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("unencrypted.skey")
        let original = TextEnvelope(
            type: "PaymentSigningKeyShelley_ed25519",
            description: "Payment Signing Key",
            cborHex: "deadbeef",
            encrHex: nil,
            path: nil,
            cborXPubKeyHex: nil
        )
        try original.save(to: url.path)

        let loaded = try await TextEnvelope.load(from: FilePath(url.path))
        #expect(loaded.cborHex == "deadbeef")
        #expect(loaded.isEncrypted == false)
    }

    @Test("throws when the file does not exist")
    func throwsOnMissingFile() async {
        let bogus = FilePath("/tmp/scm-te-async-missing-\(UUID().uuidString).skey")
        await #expect(throws: (any Error).self) {
            _ = try await TextEnvelope.load(from: bogus)
        }
    }
}

/// True when a `gpg` binary is on PATH; the encryption suite needs one.
func gpgIsAvailable() -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    process.arguments = ["gpg"]
    process.standardOutput = Pipe()
    process.standardError = Pipe()
    do {
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    } catch {
        return false
    }
}

@Suite("TextEnvelope description marker")
struct TextEnvelopeMarkerTests {

    @Test("strips the marker and its separating space")
    func stripsMarkerAndSpace() {
        #expect(
            TextEnvelope.strippingEncryptedMarker("Encrypted Payment Signing Key")
                == "Payment Signing Key"
        )
    }

    @Test("strips a bare marker to an empty description")
    func stripsBareMarker() {
        #expect(TextEnvelope.strippingEncryptedMarker("Encrypted") == "")
    }

    @Test("leaves an unmarked description untouched")
    func leavesUnmarkedAlone() {
        #expect(
            TextEnvelope.strippingEncryptedMarker("Payment Signing Key")
                == "Payment Signing Key"
        )
    }

    @Test("does not strip the word from the middle of a description")
    func ignoresNonPrefixOccurrence() {
        #expect(
            TextEnvelope.strippingEncryptedMarker("Not Encrypted Yet")
                == "Not Encrypted Yet"
        )
    }
}

@Suite("TextEnvelope encryption", .enabled(if: gpgIsAvailable()))
struct TextEnvelopeEncryptionTests {

    static let password = "Str0ng!Passw0rd#2026"
    static let plaintextCBOR = "5820d4b1a2c3e4f50617283940516273849506a7b8c9dae1f2031425364758697a0b"

    func makeSigningKey() -> TextEnvelope {
        TextEnvelope(
            type: "PaymentSigningKeyShelley_ed25519",
            description: "Payment Signing Key",
            cborHex: Self.plaintextCBOR,
            encrHex: nil,
            path: nil,
            cborXPubKeyHex: nil
        )
    }

    @Test("encrypt clears the plaintext cborHex")
    func encryptClearsPlaintext() async throws {
        var env = makeSigningKey()
        try await env.encrypt(with: Self.password)

        #expect(env.cborHex == nil)
        #expect(env.encrHex != nil)
        #expect(env.description == "Encrypted Payment Signing Key")
        #expect(env.isEncrypted == true)
    }

    @Test("the encrypted envelope serialises without the plaintext key")
    func encryptedJSONHasNoPlaintext() async throws {
        var env = makeSigningKey()
        try await env.encrypt(with: Self.password)

        let json = String(data: try JSONEncoder().encode(env), encoding: .utf8)!
        #expect(!json.contains("cborHex"))
        #expect(!json.contains(Self.plaintextCBOR))
        #expect(json.contains("encrHex"))
    }

    @Test("decrypt restores the original cborHex and clears the ciphertext")
    func decryptRoundTrips() async throws {
        var env = makeSigningKey()
        try await env.encrypt(with: Self.password)
        try await env.decrypt(with: Self.password)

        #expect(env.cborHex == Self.plaintextCBOR)
        #expect(env.encrHex == nil)
        #expect(env.description == "Payment Signing Key")
        #expect(env.isEncrypted == false)
    }

    @Test("decrypt with the wrong password throws and leaves the envelope untouched")
    func decryptWithWrongPasswordThrows() async throws {
        var env = makeSigningKey()
        try await env.encrypt(with: Self.password)
        let encrypted = env

        await #expect(throws: (any Error).self) {
            try await env.decrypt(with: "Wr0ng!Passw0rd#2026")
        }
        #expect(env.cborHex == nil)
        #expect(env.encrHex == encrypted.encrHex)
        #expect(env.isEncrypted == true)
    }

    @Test("encrypt refuses an envelope that is already encrypted")
    func encryptRefusesAlreadyEncrypted() async throws {
        var env = makeSigningKey()
        try await env.encrypt(with: Self.password)

        await #expect(throws: (any Error).self) {
            try await env.encrypt(with: Self.password)
        }
    }

    @Test("decrypt throws when there is no ciphertext")
    func decryptWithoutCiphertextThrows() async {
        var env = makeSigningKey()
        await #expect(throws: (any Error).self) {
            try await env.decrypt(with: Self.password)
        }
    }
}
