import ArgumentParser
import Foundation
import Testing
@testable import SwiftCardanoMultitool

@Suite("GenerateMainCommand.Ed25519Key")
struct Ed25519KeyTests {

    @Test("parses --name")
    func parsesName() throws {
        let cmd = try GenerateMainCommand.Ed25519Key.parse(["--name", "mykey"])
        #expect(cmd.name == "mykey")
    }

    @Test("absolute --name writes the keypair at that path, not under cwd")
    func absoluteNameWritesInPlace() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-ed25519-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let prefix = dir.appendingPathComponent("k").path
        var cmd = try GenerateMainCommand.Ed25519Key.parse(["--name", prefix])
        try await cmd.run()

        #expect(FileManager.default.fileExists(atPath: "\(prefix).skey"))
        #expect(FileManager.default.fileExists(atPath: "\(prefix).vkey"))
    }

    @Test("relative --name writes the keypair under the current directory")
    func relativeNameWritesUnderCwd() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("scm-ed25519-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try await WorkingDirectory.withCurrent(dir.path) {
            let cwd = FileManager.default.currentDirectoryPath
            var cmd = try GenerateMainCommand.Ed25519Key.parse(["--name", "k"])
            try await cmd.run()

            #expect(FileManager.default.fileExists(atPath: "\(cwd)/k.skey"))
            #expect(FileManager.default.fileExists(atPath: "\(cwd)/k.vkey"))
        }
    }
}
