import Foundation
import SystemPackage
import Testing
@testable import SwiftCardanoMultitool

@Suite("FileUtils")
struct FileUtilsTests {

    // MARK: - Helpers

    /// Make a fresh empty temp directory for the test. Caller must clean up.
    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func writeText(_ text: String, in dir: URL, name: String = "file.txt") throws -> FilePath {
        let url = dir.appendingPathComponent(name)
        try Data(text.utf8).write(to: url)
        return FilePath(url.path)
    }

    // MARK: - checkFileExists / checkFileNotExists

    @Test("checkFileExists passes for an existing regular file")
    func checkFileExistsPasses() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = try writeText("hi", in: dir)
        try FileUtils.checkFileExists(path)
    }

    @Test("checkFileExists throws fileNotFound for a missing path")
    func checkFileExistsThrowsMissing() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let missing = FilePath(dir.appendingPathComponent("missing.txt").path)
        #expect(throws: SwiftCardanoMultitoolError.self) {
            try FileUtils.checkFileExists(missing)
        }
    }

    @Test("checkFileExists throws fileNotFound when path is a directory")
    func checkFileExistsRejectsDirectory() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let dirPath = FilePath(dir.path)
        #expect(throws: SwiftCardanoMultitoolError.self) {
            try FileUtils.checkFileExists(dirPath)
        }
    }

    @Test("checkFileNotExists passes for a missing path")
    func checkFileNotExistsPasses() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let missing = FilePath(dir.appendingPathComponent("absent.txt").path)
        try FileUtils.checkFileNotExists(missing)
    }

    @Test("checkFileNotExists throws fileAlreadyExists for an existing file")
    func checkFileNotExistsThrowsForExisting() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = try writeText("hi", in: dir)
        #expect(throws: SwiftCardanoMultitoolError.self) {
            try FileUtils.checkFileNotExists(path)
        }
    }

    // MARK: - loadFile / dumpFile

    @Test("loadFile returns trimmed UTF-8 contents")
    func loadFileTrims() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = try writeText("\n  hello world  \n\n", in: dir)
        #expect(try FileUtils.loadFile(path) == "hello world")
    }

    @Test("loadFile throws fileNotFound for missing path")
    func loadFileMissing() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let missing = FilePath(dir.appendingPathComponent("nope.txt").path)
        #expect(throws: SwiftCardanoMultitoolError.self) {
            _ = try FileUtils.loadFile(missing)
        }
    }

    @Test("dumpFile writes UTF-8 string atomically")
    func dumpFileRoundTrip() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = FilePath(dir.appendingPathComponent("out.txt").path)
        try FileUtils.dumpFile(path, data: "round trip text\n")
        let read = try String(contentsOfFile: path.string, encoding: .utf8)
        #expect(read == "round trip text\n")
    }

    // MARK: - loadJSONFile / dumpJSONFile

    @Test("dumpJSONFile then loadJSONFile round-trip preserves keys")
    func jsonRoundTrip() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = FilePath(dir.appendingPathComponent("data.json").path)
        let payload: [String: Any] = [
            "name": "scm",
            "count": 42,
            "enabled": true
        ]
        try FileUtils.dumpJSONFile(path, data: payload)
        let loaded = try FileUtils.loadJSONFile(path)
        #expect(loaded["name"] as? String == "scm")
        #expect(loaded["count"] as? Int == 42)
        #expect(loaded["enabled"] as? Bool == true)
    }

    @Test("loadJSONFile throws when top-level JSON is not a dictionary")
    func loadJSONRejectsArrayTopLevel() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = try writeText("[1, 2, 3]", in: dir, name: "array.json")
        #expect(throws: SwiftCardanoMultitoolError.self) {
            _ = try FileUtils.loadJSONFile(path)
        }
    }

    @Test("loadJSONFile throws for malformed JSON")
    func loadJSONRejectsMalformed() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = try writeText("{ not json", in: dir, name: "bad.json")
        #expect(throws: (any Error).self) {
            _ = try FileUtils.loadJSONFile(path)
        }
    }

    // MARK: - chmodFile

    @Test("chmodFile applies the given octal permissions")
    func chmodAppliesPerms() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = try writeText("x", in: dir)
        try FileUtils.chmodFile(path, perms: "600")
        let attrs = try FileManager.default.attributesOfItem(atPath: path.string)
        let perms = (attrs[.posixPermissions] as? NSNumber)?.intValue ?? -1
        #expect(perms == 0o600)
    }

    @Test("chmodFile throws for a non-octal string")
    func chmodRejectsBadOctal() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = try writeText("x", in: dir)
        #expect(throws: SwiftCardanoMultitoolError.self) {
            try FileUtils.chmodFile(path, perms: "abc")
        }
    }

    @Test("chmodFile throws when 9 appears in the octal string")
    func chmodRejectsNineDigit() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = try writeText("x", in: dir)
        #expect(throws: SwiftCardanoMultitoolError.self) {
            try FileUtils.chmodFile(path, perms: "999")
        }
    }

    @Test("chmodFile throws if the file does not exist")
    func chmodRejectsMissingFile() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let missing = FilePath(dir.appendingPathComponent("ghost.txt").path)
        #expect(throws: SwiftCardanoMultitoolError.self) {
            try FileUtils.chmodFile(missing, perms: "600")
        }
    }

    // MARK: - base64EncodedFile

    @Test("base64EncodedFile produces the canonical base64 of file contents")
    func base64Roundtrip() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = try writeText("hello", in: dir)
        let encoded = try FileUtils.base64EncodedFile(path)
        #expect(String(data: encoded, encoding: .utf8) == "aGVsbG8=")
    }

    // MARK: - fileSize

    @Test("fileSize returns the byte count for a written file")
    func fileSizeForKnownFile() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = try writeText("12345", in: dir)
        #expect(FileUtils.fileSize(path) == 5)
    }

    @Test("fileSize returns zero for an empty file")
    func fileSizeEmpty() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = try writeText("", in: dir)
        #expect(FileUtils.fileSize(path) == 0)
    }

    @Test("fileSize returns nil for a missing file")
    func fileSizeMissing() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let missing = FilePath(dir.appendingPathComponent("missing.bin").path)
        #expect(FileUtils.fileSize(missing) == nil)
    }
}

// MARK: - Lock / unlock and locked variants

@Suite("FileUtils locking")
struct FileUtilsLockingTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-tests-locking-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func posixPerms(_ path: String) throws -> Int? {
        let attrs = try FileManager.default.attributesOfItem(atPath: path)
        return (attrs[.posixPermissions] as? NSNumber)?.intValue
    }

    @Test("fileLock then fileUnlock round-trip flips perms 0600 ↔ 0400")
    func lockUnlockRoundTrip() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("locked.txt")
        try Data("hello".utf8).write(to: url)
        let path = FilePath(url.path)

        try await FileUtils.fileLock(path)
        #expect(try posixPerms(path.string) == 0o400)

        try await FileUtils.fileUnlock(path)
        #expect(try posixPerms(path.string) == 0o600)
    }

    @Test("fileUnlock is a no-op for a missing file (does not throw)")
    func unlockMissingFileNoThrow() async throws {
        let bogus = FilePath("/tmp/scm-lock-noop-\(UUID().uuidString).bin")
        try await FileUtils.fileUnlock(bogus)
    }

    @Test("unlockIfExists unlocks an existing locked file")
    func unlockIfExistsUnlocks() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("conditional.txt")
        try Data("x".utf8).write(to: url)
        let path = FilePath(url.path)

        try await FileUtils.fileLock(path)
        #expect(try posixPerms(path.string) == 0o400)

        try await FileUtils.unlockIfExists(path)
        #expect(try posixPerms(path.string) == 0o600)
    }

    @Test("unlockIfExists is a no-op for a missing file")
    func unlockIfExistsMissingIsNoop() async throws {
        let bogus = FilePath("/tmp/scm-uife-noop-\(UUID().uuidString).bin")
        try await FileUtils.unlockIfExists(bogus)
    }

    @Test("dumpLockedFile then loadLockedFile round-trip a UTF-8 string")
    func lockedFileRoundTrip() async throws {
        let dir = try makeTempDir()
        defer {
            // Need to unlock before delete (chmod restores write perm to the user).
            try? FileManager.default.removeItem(at: dir)
        }
        let url = dir.appendingPathComponent("locked-content.txt")
        let path = FilePath(url.path)

        try await FileUtils.dumpLockedFile(path, data: "hello round-trip")
        // The dumpLockedFile leaves the file locked (0400) at rest.
        #expect(try posixPerms(path.string) == 0o400)

        let loaded = try await FileUtils.loadLockedFile(path)
        #expect(loaded == "hello round-trip")
        // After load, the file is re-locked.
        #expect(try posixPerms(path.string) == 0o400)
    }

    @Test("dumpLockedJSONFile then loadLockedJSONFile preserves keys")
    func lockedJSONRoundTrip() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("locked.json")
        let path = FilePath(url.path)
        let payload: [String: Any] = ["alpha": 1, "beta": "two"]

        try await FileUtils.dumpLockedJSONFile(path, data: payload)
        let loaded = try await FileUtils.loadLockedJSONFile(path)
        #expect(loaded["alpha"] as? Int == 1)
        #expect(loaded["beta"] as? String == "two")
    }
}

// MARK: - cleanupFile

@Suite("FileUtils.cleanupFile")
struct FileUtilsCleanupTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-tests-cleanup-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("cleanupFile removes an existing file")
    func removesExistingFile() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("to-clean.txt")
        try Data("x".utf8).write(to: url)
        let path = FilePath(url.path)

        try FileUtils.cleanupFile(path)
        #expect(!FileManager.default.fileExists(atPath: path.string))
    }

    @Test("cleanupFile throws for a missing file (Foundation error surfaces)")
    func throwsForMissingFile() {
        let bogus = FilePath("/tmp/scm-cleanup-missing-\(UUID().uuidString).bin")
        #expect(throws: (any Error).self) {
            try FileUtils.cleanupFile(bogus)
        }
    }
}

// MARK: - searchLatestFile

@Suite("FileUtils.searchLatestFile")
struct FileUtilsSearchLatestFileTests {

    /// `searchLatestFile` scans the *current working directory*. Tests must chdir
    /// into a temp dir to exercise it deterministically.
    private final class Chdir {
        let original: String
        init(_ target: String) {
            self.original = FileManager.default.currentDirectoryPath
            _ = FileManager.default.changeCurrentDirectoryPath(target)
        }
        deinit {
            _ = FileManager.default.changeCurrentDirectoryPath(original)
        }
    }

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-tests-latest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("returns the lexicographically latest match")
    func returnsLatestMatch() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        for name in ["pool.a-2026.tx", "pool.b-2025.tx", "pool.c-2027.tx", "other.txt"] {
            try Data("x".utf8).write(to: dir.appendingPathComponent(name))
        }
        let chdir = Chdir(dir.path)
        defer { _ = chdir.self }

        let latest = try FileUtils.searchLatestFile(
            startswith: "pool", contains: "-", endswith: "tx"
        )
        #expect(latest?.lastComponent?.string == "pool.c-2027.tx")
    }

    @Test("returns nil and warns when no file matches the pattern")
    func returnsNilWhenNoMatch() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data("x".utf8).write(to: dir.appendingPathComponent("other.txt"))
        let chdir = Chdir(dir.path)
        defer { _ = chdir.self }

        let latest = try FileUtils.searchLatestFile(
            startswith: "pool", contains: "-", endswith: "tx"
        )
        #expect(latest == nil)
    }
}
