import Foundation
import Testing
@testable import SwiftCardanoMultitool

@Suite("stemsOfFiles")
struct CompletionsTests {

    /// A temporary directory holding `names`, passed to `body`.
    func withFiles(_ names: [String], _ body: (String) throws -> Void) throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("scm-stems-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }
        for name in names {
            let url = dir.appendingPathComponent(name)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            fm.createFile(atPath: url.path, contents: Data())
        }
        try body(dir.path)
    }

    @Test("offers each stem once, skipping hidden files and names without a dot")
    func stemsInWorkingDirectory() throws {
        try withFiles(["alice.payment.vkey", "alice.stake.vkey", "bob.skey", ".hidden.vkey", "README"]) { dir in
            #expect(stemsOfFiles(matching: "", workingDirectory: dir) == ["alice", "bob"])
            #expect(stemsOfFiles(matching: "a", workingDirectory: dir) == ["alice"])
        }
    }

    @Test("keeps the typed directory in front of the stem")
    func stemsInSubdirectory() throws {
        try withFiles(["keys/carol.drep.vkey", "keys/nested/dave.vkey"]) { dir in
            #expect(stemsOfFiles(matching: "keys/", workingDirectory: dir) == ["keys/carol"])
            #expect(stemsOfFiles(matching: "keys/c", workingDirectory: dir) == ["keys/carol"])
            #expect(stemsOfFiles(matching: dir + "/keys/", workingDirectory: "/") == [dir + "/keys/carol"])
        }
    }

    @Test("returns nothing for a directory that does not exist")
    func missingDirectory() {
        #expect(stemsOfFiles(matching: "/no/such/dir/x").isEmpty)
    }
}
