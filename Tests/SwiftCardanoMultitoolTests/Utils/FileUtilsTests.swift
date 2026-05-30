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
