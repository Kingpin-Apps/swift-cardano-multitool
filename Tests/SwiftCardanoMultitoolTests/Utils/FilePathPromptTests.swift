import Foundation
import Testing
@testable import SwiftCardanoMultitool

/// An in-memory directory tree for completion tests. Paths are absolute; directories end with `/`.
struct FakeListing: DirectoryListing {
    let paths: Set<String>

    init(_ paths: [String]) {
        self.paths = Set(paths)
    }

    private func normalized(_ path: String) -> String {
        let standardized = (path as NSString).standardizingPath
        return standardized == "/" ? "/" : standardized + "/"
    }

    func entries(atPath path: String) -> [FilePathCompleter.Entry]? {
        let directory = normalized(path)
        guard directory == "/" || paths.contains(directory) else { return nil }
        return paths.compactMap { candidate in
            guard candidate.hasPrefix(directory), candidate != directory else { return nil }
            let rest = candidate.dropFirst(directory.count)
            let isDirectory = rest.hasSuffix("/")
            let name = isDirectory ? String(rest.dropLast()) : String(rest)
            guard !name.contains("/") else { return nil }
            return FilePathCompleter.Entry(name: name, isDirectory: isDirectory)
        }
    }

    func itemKind(atPath path: String) -> FilePathCompleter.ItemKind {
        let standardized = (path as NSString).standardizingPath
        if paths.contains(standardized + "/") || standardized == "/" { return .directory }
        if paths.contains(standardized) { return .file }
        return .missing
    }
}

@Suite("FilePathCompleter")
struct FilePathCompleterTests {

    static let listing = FakeListing([
        "/home/", "/home/me/", "/home/me/keys/", "/home/me/keys/alice.payment.vkey", "/home/me/keys/alice.payment.skey",
        "/home/me/keys/pool/", "/home/me/keys/pool/cold.skey",
        "/work/", "/work/alpha.script", "/work/alpine.script", "/work/notes.txt", "/work/.hidden.skey",
        "/work/My Keys/", "/work/My Keys/clé.plutus",
    ])

    func completer(_ selection: FilePathCompleter.Selection = .files, matching: (@Sendable (String) -> Bool)? = nil) -> FilePathCompleter {
        FilePathCompleter(selection: selection, fileMatches: matching, baseDirectory: "/work", homeDirectory: "/home/me", listing: Self.listing)
    }

    @Test("splits input into the directory as typed and the partial name")
    func split() {
        #expect(FilePathCompleter.split("keys/al") == ("keys/", "al"))
        #expect(FilePathCompleter.split("alpha") == ("", "alpha"))
        #expect(FilePathCompleter.split("/abs/") == ("/abs/", ""))
        #expect(FilePathCompleter.split("~") == ("~/", ""))
    }

    @Test("lists directories first, then files, and hides dot files unless typed")
    func listing() {
        let names = completer().suggestions(for: "").map(\.displayName)
        #expect(names == ["My Keys/", "alpha.script", "alpine.script", "notes.txt"])
        #expect(completer().suggestions(for: ".h").map(\.name) == [".hidden.skey"])
    }

    @Test("fileMatches limits suggested files but keeps directories")
    func fileMatches() {
        let names = completer(matching: { $0.hasSuffix(".script") }).suggestions(for: "").map(\.displayName)
        #expect(names == ["My Keys/", "alpha.script", "alpine.script"])
        #expect(completer(.directories).suggestions(for: "").map(\.displayName) == ["My Keys/"])
    }

    @Test("expands ~ and resolves parent directories")
    func homeAndParent() {
        #expect(completer().suggestions(for: "~/ke").map(\.completion) == ["~/keys/"])
        #expect(completer().suggestions(for: "~/keys/").map(\.completion) == ["~/keys/pool/", "~/keys/alice.payment.skey", "~/keys/alice.payment.vkey"])
        #expect(completer().suggestions(for: "../home/me/k").map(\.completion) == ["../home/me/keys/"])
        #expect(completer().suggestions(for: "..").first?.completion == "../")
        #expect(completer().expanded("~/keys/pool/cold.skey") == "/home/me/keys/pool/cold.skey")
    }

    @Test("falls back to names containing the text when nothing starts with it")
    func substring() {
        #expect(completer().suggestions(for: "~/keys/payment.v").map(\.name) == ["alice.payment.vkey"])
        #expect(completer().suggestions(for: "pine").map(\.name) == ["alpine.script"])
    }

    @Test("matching ignores case and keeps spaces and accents")
    func caseAndUnicode() {
        #expect(completer().suggestions(for: "my").map(\.completion) == ["My Keys/"])
        #expect(completer().suggestions(for: "My Keys/cl").map(\.completion) == ["My Keys/clé.plutus"])
    }

    @Test("common completion extends to the shared prefix, or the only match")
    func commonCompletion() {
        let c = completer()
        #expect(c.commonCompletion(for: "al", suggestions: c.suggestions(for: "al")) == "alp")
        #expect(c.commonCompletion(for: "alph", suggestions: c.suggestions(for: "alph")) == "alpha.script")
        #expect(c.commonCompletion(for: "alp", suggestions: c.suggestions(for: "alp")) == nil)
        #expect(c.commonCompletion(for: "~/keys/alice.payment.", suggestions: c.suggestions(for: "~/keys/alice.payment.")) == nil)
    }

    @Test("item kinds resolve relative, home and absolute paths")
    func itemKinds() {
        #expect(completer().itemKind(of: "alpha.script") == .file)
        #expect(completer().itemKind(of: "My Keys/") == .directory)
        #expect(completer().itemKind(of: "~/keys") == .directory)
        #expect(completer().itemKind(of: "/work/nope") == .missing)
    }
}

@Suite("FilePathPromptState")
struct FilePathPromptStateTests {

    func state(
        _ selection: FilePathCompleter.Selection = .files,
        defaultValue: String? = nil,
        mustExist: Bool = true,
        validate: @escaping (String) -> [String] = { _ in [] }
    ) -> FilePathPromptState {
        FilePathPromptState(
            completer: FilePathCompleter(selection: selection, baseDirectory: "/work", homeDirectory: "/home/me", listing: FilePathCompleterTests.listing),
            defaultValue: defaultValue,
            mustExist: mustExist,
            validate: validate
        )
    }

    mutating func type(_ text: String, into state: inout FilePathPromptState) {
        for character in text { _ = state.handle(.character(character)) }
    }

    @Test("tab completes the common prefix, then cycles through matches")
    mutating func tabCompletion() {
        var s = state()
        type("al", into: &s)
        #expect(s.handle(.tab) == .continue)
        #expect(s.input == "alp")
        _ = s.handle(.tab)
        #expect(s.selectedSuggestion?.name == "alpha.script")
        _ = s.handle(.tab)
        #expect(s.selectedSuggestion?.name == "alpine.script")
        _ = s.handle(.shiftTab)
        #expect(s.selectedSuggestion?.name == "alpha.script")
        #expect(s.handle(.enter) == .submit("alpha.script"))
    }

    @Test("enter on a highlighted directory opens it instead of submitting")
    mutating func openDirectory() {
        var s = state()
        type("~/", into: &s)
        _ = s.handle(.down)
        #expect(s.selectedSuggestion?.name == "keys")
        #expect(s.handle(.enter) == .continue)
        #expect(s.input == "~/keys/")
        _ = s.handle(.down)
        _ = s.handle(.down)
        #expect(s.handle(.enter) == .submit("/home/me/keys/alice.payment.skey"))
    }

    @Test("enter on a typed directory opens it when files are wanted")
    mutating func typedDirectory() {
        var s = state()
        type("My Keys", into: &s)
        #expect(s.handle(.enter) == .continue)
        #expect(s.input == "My Keys/")
    }

    @Test("directories can be chosen when directories are wanted")
    mutating func chooseDirectory() {
        var s = state(.directories)
        type("~/keys/", into: &s)
        #expect(s.handle(.enter) == .submit("/home/me/keys"))
    }

    @Test("missing paths and failed validation show errors and keep prompting")
    mutating func errors() {
        var s = state(validate: { $0.hasSuffix(".txt") ? ["Not a script."] : [] })
        type("nope.script", into: &s)
        #expect(s.handle(.enter) == .continue)
        #expect(s.errors == ["nope.script does not exist."])
        _ = s.handle(.clear)
        #expect(s.errors.isEmpty)
        type("notes.txt", into: &s)
        #expect(s.handle(.enter) == .continue)
        #expect(s.errors == ["Not a script."])
    }

    @Test("empty input uses the default, or asks for a path")
    mutating func defaults() {
        var withDefault = state(defaultValue: "alpha.script")
        #expect(withDefault.handle(.enter) == .submit("alpha.script"))
        var without = state()
        #expect(without.handle(.enter) == .continue)
        #expect(without.errors == ["Enter a path."])
    }

    @Test("new paths are accepted when they don't need to exist")
    mutating func newPath() {
        var s = state(mustExist: false)
        type("out/new.cert", into: &s)
        #expect(s.handle(.enter) == .submit("out/new.cert"))
    }

    @Test("ctrl+w removes the last path component, backspace one character")
    mutating func editing() {
        var s = state()
        type("~/keys/pool/", into: &s)
        _ = s.handle(.deleteComponent)
        #expect(s.input == "~/keys/")
        _ = s.handle(.backspace)
        #expect(s.input == "~/keys")
        #expect(FilePathPromptState.removingLastComponent("a/b.vkey") == "a/")
        #expect(FilePathPromptState.removingLastComponent("b.vkey") == "")
    }

    @Test("escape clears the highlight, then hides the suggestions")
    mutating func escape() {
        var s = state()
        _ = s.handle(.down)
        #expect(s.selectedIndex != nil)
        _ = s.handle(.escape)
        #expect(s.selectedIndex == nil)
        #expect(s.showSuggestions)
        _ = s.handle(.escape)
        #expect(!s.showSuggestions)
    }
}

@Suite("FilePathKeyDecoder")
struct FilePathKeyDecoderTests {

    /// Decodes all keys in a byte sequence; bytes are all "pending" at once, as from a terminal.
    func keys(_ bytes: [UInt8]) -> [FilePathKey] {
        final class Buffer: @unchecked Sendable { var bytes: [UInt8]; init(_ b: [UInt8]) { bytes = b } }
        let buffer = Buffer(bytes)
        let next: () -> UInt8? = { buffer.bytes.isEmpty ? nil : buffer.bytes.removeFirst() }
        let decoder = FilePathKeyDecoder(readByte: next, readPendingByte: next)
        var result: [FilePathKey] = []
        while let key = decoder.nextKey() { result.append(key) }
        return result
    }

    @Test("decodes characters, control keys and arrow sequences")
    func decodes() {
        #expect(keys(Array("a/".utf8)) == [.character("a"), .character("/")])
        #expect(keys([0x09, 0x0D, 0x7F, 0x15, 0x17]) == [.tab, .enter, .backspace, .clear, .deleteComponent])
        #expect(keys([0x1B, 0x5B, 0x41, 0x1B, 0x5B, 0x42, 0x1B, 0x5B, 0x43, 0x1B, 0x5B, 0x5A]) == [.up, .down, .right, .shiftTab])
        #expect(keys([0x1B]) == [.escape])
    }

    @Test("decodes multi-byte UTF-8 characters")
    func utf8() {
        #expect(keys(Array("clé".utf8)) == [.character("c"), .character("l"), .character("é")])
    }

    @Test("ignores other escape sequences such as the delete key")
    func ignoresUnknown() {
        #expect(keys([0x1B, 0x5B, 0x33, 0x7E, 0x61]) == [.character("a")])
    }
}
