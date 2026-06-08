import Testing
@testable import SwiftCardanoMultitool

@Suite("PasswordList")
struct PasswordListTests {

    @Test("raw is non-empty")
    func rawIsPopulated() {
        #expect(!PasswordList.raw.isEmpty)
    }

    @Test("contains the canonical seed entries from the original list")
    func canonicalSeedEntries() {
        let lines = Set(PasswordList.raw.split(separator: "\n").map { String($0) })
        #expect(lines.contains("123456"))
        #expect(lines.contains("password"))
        #expect(lines.contains("qwerty"))
    }

    @Test("contains well over 1k entries (sanity check on the dump)")
    func entryCount() {
        let lines = PasswordList.raw.split(separator: "\n")
        #expect(lines.count > 1_000, "expected the password list to ship with > 1000 entries")
    }
}
