import ArgumentParser
import Foundation
import Testing
@testable import SwiftCardanoMultitool

@Suite("install completions")
struct InstallCompletionsTests {

    let home = URL(fileURLWithPath: "/home/user")

    @Test("default paths are the ones each shell loads from")
    func defaultPaths() {
        #expect(completionScriptURL(for: .zsh, environment: [:], home: home).path == "/home/user/.zfunc/_scm")
        #expect(completionScriptURL(for: .bash, environment: [:], home: home).path
            == "/home/user/.local/share/bash-completion/completions/scm")
        #expect(completionScriptURL(for: .fish, environment: [:], home: home).path
            == "/home/user/.config/fish/completions/scm.fish")
    }

    @Test("ZDOTDIR and the XDG variables move the paths; empty values are ignored")
    func environmentOverrides() {
        let env = ["ZDOTDIR": "/z", "XDG_DATA_HOME": "/data", "XDG_CONFIG_HOME": ""]
        #expect(completionScriptURL(for: .zsh, environment: env, home: home).path == "/z/.zfunc/_scm")
        #expect(completionScriptURL(for: .bash, environment: env, home: home).path
            == "/data/bash-completion/completions/scm")
        #expect(completionScriptURL(for: .fish, environment: env, home: home).path
            == "/home/user/.config/fish/completions/scm.fish")
    }

    @Test("zsh asks for an fpath line only when .zshrc does not already have one")
    func zshFpathHint() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("scm-zdot-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let destination = dir.appendingPathComponent(".zfunc/_scm")
        func steps() -> [String] {
            completionNextSteps(for: .zsh, destination: destination, customPath: false,
                                environment: ["ZDOTDIR": dir.path], home: home)
        }

        #expect(steps().contains { $0.contains("fpath=(") })
        try "fpath=(~/.zfunc $fpath)\nautoload -Uz compinit && compinit\n"
            .write(to: dir.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)
        #expect(!steps().contains { $0.contains("fpath=(") })
    }

    @Test("writes the same script as --generate-completion-script to --output")
    func writesScript() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("scm-comp-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let target = dir.appendingPathComponent("nested/scm.fish")

        var cmd = try InstallMainCommand.Completions.parse(["--shell", "fish", "--output", target.path])
        try await cmd.run()

        let written = try String(contentsOf: target, encoding: .utf8)
        #expect(written == SwiftCardanoMultitool.completionScript(for: .fish) + "\n")
    }

    @Test("rejects an unknown --shell at parse time")
    func rejectsUnknownShell() {
        #expect(throws: (any Error).self) {
            _ = try InstallMainCommand.Completions.parse(["--shell", "powershell"])
        }
    }
}
