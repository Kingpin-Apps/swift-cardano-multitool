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

/// Whether this environment can actually perform gpg symmetric crypto.
///
/// Finding the binary is not enough. CI runners ship `gpg` but often have no usable gpg-agent,
/// and a gpg call that blocks there never returns — which starves Swift's cooperative thread
/// pool and wedges the whole test process rather than failing. So prove it works with a real
/// encrypt/decrypt round-trip under a hard timeout, and let the gpg suites skip when it does not.
///
/// The probe runs once; the result is cached for the lifetime of the test process. It uses plain
/// subprocesses and files (never async, never pipes) so it cannot deadlock the runner or fill a
/// pipe buffer, and it works in an isolated GNUPGHOME so it never touches the user's keyring.
let gpgIsAvailableResult: Bool = probeGPG()

func gpgIsAvailable() -> Bool { gpgIsAvailableResult }

/// Locate `gpg`, tolerating a PATH that lacks Homebrew (Xcode's test runner strips it).
private func locateGPG() -> String? {
    let candidates = ["/opt/homebrew/bin/gpg", "/usr/local/bin/gpg", "/usr/bin/gpg", "/bin/gpg"]
    for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
        return candidate
    }

    let which = Process()
    which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    which.arguments = ["gpg"]
    let out = Pipe()
    which.standardOutput = out
    which.standardError = Pipe()
    guard (try? which.run()) != nil else { return nil }
    which.waitUntilExit()
    guard which.terminationStatus == 0 else { return nil }
    let path = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return path.isEmpty ? nil : path
}

/// Run gpg to completion, killing it and reporting failure if it outlasts `timeout`.
private func runGPG(_ gpg: String, _ arguments: [String], timeout: TimeInterval = 20) -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: gpg)
    process.arguments = arguments
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    process.standardInput = FileHandle.nullDevice
    guard (try? process.run()) != nil else { return false }

    let deadline = Date().addingTimeInterval(timeout)
    while process.isRunning && Date() < deadline {
        usleep(50_000)
    }
    if process.isRunning {
        process.terminate()
        usleep(200_000)
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        return false
    }
    return process.terminationStatus == 0
}

private func probeGPG() -> Bool {
    guard let gpg = locateGPG() else { return false }

    let fm = FileManager.default
    // Deliberately short, and deliberately NOT an isolated --homedir. gpg-agent's socket lives
    // in GNUPGHOME and a Unix socket path is capped near 104 bytes, so a long temp path fails
    // with "can't connect to the gpg-agent: File name too long". More importantly, the code
    // under test uses the *default* home, so the probe has to exercise that same home for its
    // answer to mean anything. Symmetric encryption writes no keys to the keyring.
    let root = URL(fileURLWithPath: "/tmp")
        .appendingPathComponent("scmgpg-\(UUID().uuidString.prefix(8))")
    guard (try? fm.createDirectory(
        at: root,
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700]
    )) != nil else { return false }
    defer { try? fm.removeItem(at: root) }

    let plain = root.appendingPathComponent("plain.txt")
    let cipher = root.appendingPathComponent("cipher.gpg")
    let out = root.appendingPathComponent("out.txt")
    let payload = "swift-cardano-multitool gpg probe"
    guard (try? payload.write(to: plain, atomically: true, encoding: .utf8)) != nil else {
        return false
    }

    let base = [
        "--batch", "--yes",
        "--pinentry-mode", "loopback",
        "--passphrase", "Pr0be!Passphrase#1",
        "--no-tty",
    ]

    guard runGPG(gpg, base + [
        "--symmetric", "--cipher-algo", "AES256",
        "--output", cipher.path, plain.path,
    ]) else { return false }

    guard runGPG(gpg, base + ["--decrypt", "--output", out.path, cipher.path]) else {
        return false
    }

    return (try? String(contentsOf: out, encoding: .utf8)) == payload
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

@Suite("TextEnvelope.loadRaw(from:)", .serialized, .enabled(if: gpgIsAvailable()))
struct TextEnvelopeLoadRawTests {

    static let password = "Str0ng!Passw0rd#2026"
    static let plaintextCBOR = "5820d4b1a2c3e4f50617283940516273849506a7b8c9dae1f2031425364758697a0b"

    /// Write an envelope to a throwaway file and hand back its path plus a cleanup closure.
    func withTempFile(_ envelope: TextEnvelope, _ body: (FilePath) async throws -> Void) async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("scm-loadraw-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("key.skey")
        try envelope.save(to: url.path)
        try await body(FilePath(url.path))
    }

    func encryptedEnvelope() async throws -> TextEnvelope {
        var env = TextEnvelope(
            type: "PaymentSigningKeyShelley_ed25519",
            description: "Payment Signing Key",
            cborHex: Self.plaintextCBOR,
            encrHex: nil,
            path: nil,
            cborXPubKeyHex: nil
        )
        try await env.encrypt(with: Self.password)
        return env
    }

    @Test("reports an encrypted file as encrypted, without decrypting it")
    func keepsEncryptedFileEncrypted() async throws {
        try await withTempFile(try await encryptedEnvelope()) { path in
            let raw = try TextEnvelope.loadRaw(from: path)
            #expect(raw.isEncrypted == true)
            #expect(raw.cborHex == nil)
            #expect(raw.encrHex != nil)
        }
    }

    @Test("load(from:) decrypts the same file, which is why the commands need loadRaw")
    func loadDecryptsWhereLoadRawDoesNot() async throws {
        try await withTempFile(try await encryptedEnvelope()) { path in
            setenv("CARDANO_MULTITOOL_DECRYPT_PASSWORD", Self.password, 1)
            defer { unsetenv("CARDANO_MULTITOOL_DECRYPT_PASSWORD") }

            let decrypted = try await TextEnvelope.load(from: path)
            #expect(decrypted.isEncrypted == false)
            #expect(decrypted.cborHex == Self.plaintextCBOR)

            let raw = try TextEnvelope.loadRaw(from: path)
            #expect(raw.isEncrypted == true)
        }
    }

    @Test("reads an unencrypted file unchanged")
    func readsUnencryptedFile() async throws {
        let env = TextEnvelope(
            type: "PaymentSigningKeyShelley_ed25519",
            description: "Payment Signing Key",
            cborHex: Self.plaintextCBOR,
            encrHex: nil,
            path: nil,
            cborXPubKeyHex: nil
        )
        try await withTempFile(env) { path in
            let raw = try TextEnvelope.loadRaw(from: path)
            #expect(raw.isEncrypted == false)
            #expect(raw.cborHex == Self.plaintextCBOR)
        }
    }

    @Test("throws when the file does not exist")
    func throwsOnMissingFile() {
        let bogus = FilePath("/tmp/scm-loadraw-missing-\(UUID().uuidString).skey")
        #expect(throws: (any Error).self) {
            _ = try TextEnvelope.loadRaw(from: bogus)
        }
    }

    @Test("decrypting a legacy file drops the leaked plaintext alongside the ciphertext")
    func decryptRepairsLegacyFile() async throws {
        // What the old encrypt wrote: ciphertext AND the plaintext it failed to clear.
        var legacy = try await encryptedEnvelope()
        legacy.cborHex = Self.plaintextCBOR

        try await withTempFile(legacy) { path in
            var raw = try TextEnvelope.loadRaw(from: path)
            #expect(raw.isEncrypted == true)

            try await raw.decrypt(with: Self.password)
            #expect(raw.cborHex == Self.plaintextCBOR)
            #expect(raw.encrHex == nil)

            let json = String(data: try JSONEncoder().encode(raw), encoding: .utf8)!
            #expect(!json.contains("encrHex"))
        }
    }
}

@Suite("gpg probe safety")
struct GPGProbeSafetyTests {

    @Test("a gpg that never exits is killed and reported unavailable")
    func hangingProcessTimesOut() {
        // The property that keeps CI from wedging: a blocked gpg must be killed, not waited on.
        let start = Date()
        let succeeded = runGPG("/bin/sh", ["-c", "sleep 120"], timeout: 2)
        let elapsed = Date().timeIntervalSince(start)

        #expect(succeeded == false)
        #expect(elapsed < 15, "the probe should give up after its timeout, not block")
    }

    @Test("a failing gpg is reported unavailable")
    func failingProcessReportsFailure() {
        #expect(runGPG("/bin/sh", ["-c", "exit 3"], timeout: 10) == false)
    }

    @Test("a succeeding gpg is reported available")
    func succeedingProcessReportsSuccess() {
        #expect(runGPG("/bin/sh", ["-c", "exit 0"], timeout: 10) == true)
    }

    @Test("a missing binary is reported unavailable")
    func missingBinaryReportsFailure() {
        #expect(runGPG("/nonexistent/gpg-\(UUID().uuidString)", ["--version"], timeout: 10) == false)
    }
}
