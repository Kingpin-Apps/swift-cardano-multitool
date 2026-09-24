import Foundation
import SystemPackage
import Testing
@testable import SwiftCardanoMultitool

@Suite("GenerateMainCommand.KeyRotation")
struct KeyRotationTests {

    @Test("upload directory sits next to an absolute pool name")
    func uploadDirectoryForAbsoluteName() {
        let dir = GenerateMainCommand.KeyRotation.uploadDirectory(for: "/keys/mypool")
        #expect(dir == FilePath("/keys/upload_mypool"))
    }

    @Test("upload directory is under cwd for a bare pool name")
    func uploadDirectoryForBareName() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-keyrotation-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        WorkingDirectory.withCurrent(tmp.path) {
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let dir = GenerateMainCommand.KeyRotation.uploadDirectory(for: "mypool")
            #expect(dir == cwd.appending("upload_mypool"))
        }
    }
}
