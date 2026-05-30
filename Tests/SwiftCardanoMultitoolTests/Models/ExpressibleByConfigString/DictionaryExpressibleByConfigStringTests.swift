import Configuration
import SystemPackage
import Testing
@testable import SwiftCardanoMultitool

@Suite("Dictionary<String, FilePath>+ExpressibleByConfigString")
struct DictionaryExpressibleByConfigStringTests {

    private func parse(_ s: String) -> [String: FilePath]? {
        return [String: FilePath](configString: s)
    }

    @Test("empty string produces an empty dictionary")
    func emptyIsEmpty() {
        let result = parse("")
        #expect(result == [:])
    }

    @Test("whitespace-only string produces an empty dictionary")
    func whitespaceIsEmpty() {
        let result = parse("   ")
        #expect(result == [:])
    }

    @Test("parses a single key=value pair")
    func singlePair() {
        let result = parse("alice=/etc/alice.conf")
        #expect(result == ["alice": FilePath("/etc/alice.conf")])
    }

    @Test("parses multiple comma-separated pairs")
    func multiplePairs() {
        let result = parse("a=/tmp/a.txt,b=/tmp/b.txt")
        #expect(result?.count == 2)
        #expect(result?["a"] == FilePath("/tmp/a.txt"))
        #expect(result?["b"] == FilePath("/tmp/b.txt"))
    }

    @Test("tolerates whitespace around keys and values")
    func tolerantWhitespace() {
        let result = parse("  a = /tmp/a.txt , b = /tmp/b.txt  ")
        #expect(result?["a"] == FilePath("/tmp/a.txt"))
        #expect(result?["b"] == FilePath("/tmp/b.txt"))
    }

    @Test("returns nil for a pair missing an equals sign")
    func malformedNoEquals() {
        #expect(parse("alice/etc/alice.conf") == nil)
    }

    @Test("returns nil when a key is empty")
    func malformedEmptyKey() {
        #expect(parse("=/tmp/foo") == nil)
    }

    @Test("accepts an empty value")
    func emptyValueAllowed() {
        let result = parse("alice=")
        #expect(result == ["alice": FilePath("")])
    }
}
