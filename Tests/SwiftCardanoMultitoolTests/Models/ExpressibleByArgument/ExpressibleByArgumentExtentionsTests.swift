import Foundation
import SwiftCardanoCore
import SwiftMnemonic
import SystemPackage
import Testing
@testable import SwiftCardanoMultitool

@Suite("URL+ExpressibleByArgument")
struct URLExpressibleByArgumentTests {

    @Test("accepts a valid HTTP URL")
    func acceptsHttpURL() {
        let url = URL(argument: "https://example.com/path")
        #expect(url?.absoluteString == "https://example.com/path")
    }

    @Test("accepts a file URL string")
    func acceptsFileURL() {
        let url = URL(argument: "file:///tmp/foo.txt")
        #expect(url?.scheme == "file")
    }
}

@Suite("FilePath+ExpressibleByArgument")
struct FilePathExpressibleByArgumentTests {

    @Test("constructs a FilePath from a relative path")
    func relativePath() {
        let fp = FilePath(argument: "some/dir/file.txt")
        #expect(fp?.string == "some/dir/file.txt")
    }

    @Test("constructs a FilePath from an absolute path")
    func absolutePath() {
        let fp = FilePath(argument: "/tmp/foo.bin")
        #expect(fp?.string == "/tmp/foo.bin")
    }
}

@Suite("Language+ExpressibleByArgument")
struct LanguageExpressibleByArgumentTests {

    @Test("accepts a lowercase language name")
    func acceptsLowercase() {
        #expect(Language(argument: "english") != nil)
    }

    @Test("lowercases the argument before parsing")
    func acceptsMixedCase() {
        #expect(Language(argument: "ENGLISH") != nil)
        #expect(Language(argument: "English") != nil)
    }

    @Test("returns nil for an unknown language")
    func rejectsUnknown() {
        #expect(Language(argument: "klingon") == nil)
    }

    @Test("description matches the raw value")
    func descriptionMatchesRawValue() {
        let lang = Language(argument: "english")
        #expect(lang?.description == "english")
    }
}

@Suite("WordCount+ExpressibleByArgument")
struct WordCountExpressibleByArgumentTests {

    @Test("accepts a numeric BIP-39 word count")
    func acceptsValidCount() {
        #expect(WordCount(argument: "12") != nil)
        #expect(WordCount(argument: "24") != nil)
    }

    @Test("falls back to 24 for a non-numeric argument")
    func nonNumericFallsBackTo24() {
        let wc = WordCount(argument: "abc")
        #expect(wc != nil)
        #expect(wc?.description == "24")
    }

    @Test("description renders the integer raw value")
    func descriptionMatchesRawValue() {
        let wc = WordCount(argument: "12")
        #expect(wc?.description == "12")
    }
}

@Suite("Network+ExpressibleByArgument")
struct NetworkExpressibleByArgumentTests {

    @Test("accepts mainnet (case insensitive)")
    func mainnet() {
        #expect(Network(argument: "mainnet") == .mainnet)
        #expect(Network(argument: "MAINNET") == .mainnet)
        #expect(Network(argument: "MainNet") == .mainnet)
    }

    @Test("accepts preview")
    func preview() {
        #expect(Network(argument: "preview") == .preview)
    }

    @Test("accepts preprod")
    func preprod() {
        #expect(Network(argument: "preprod") == .preprod)
    }

    @Test("accepts guildnet")
    func guildnet() {
        #expect(Network(argument: "guildnet") == .guildnet)
    }

    @Test("accepts sanchonet")
    func sanchonet() {
        #expect(Network(argument: "sanchonet") == .sanchonet)
    }

    @Test("returns nil for an unknown network")
    func unknown() {
        #expect(Network(argument: "testnet") == nil)
        #expect(Network(argument: "") == nil)
    }
}
