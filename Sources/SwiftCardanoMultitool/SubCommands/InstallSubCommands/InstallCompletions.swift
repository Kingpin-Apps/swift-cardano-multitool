import Foundation
import ArgumentParser
import Noora
import SystemPackage

extension CompletionShell: @retroactive _SendableMetatype {}
extension CompletionShell: @retroactive ExpressibleByArgument {}

extension InstallMainCommand {
    /// Writes the shell completion script where the user's shell loads it from.
    struct Completions: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "completions",
            abstract: "Install tab completion for your shell.",
            discussion: """
            Writes the completion script for zsh, bash or fish into your home folder:

              zsh   ~/.zfunc/_scm (or $ZDOTDIR/.zfunc/_scm)
              bash  ~/.local/share/bash-completion/completions/scm
              fish  ~/.config/fish/completions/scm.fish

            Run it again after upgrading scm to pick up new commands and options.
            Homebrew and the .deb package already install completion, so this is
            for other installs.
            """
        )

        @Option(name: .shortAndLong, help: "Shell to install for. Defaults to the shell in $SHELL.")
        var shell: CompletionShell?

        @Option(name: .shortAndLong, help: "Write the script to this path instead.")
        var output: FilePath?

        mutating func wizard() async throws {
            let choice: String = noora.singleChoicePrompt(
                title: "Shell",
                question: "Which shell should tab completion be installed for?",
                options: CompletionShell.allCases.map(\.rawValue),
                description: "Could not tell your shell from $SHELL."
            )
            shell = CompletionShell(rawValue: choice)
        }

        mutating func run() async throws {
            if shell == nil {
                shell = CompletionShell.autodetected()
            }
            if shell == nil, isInteractiveSession() {
                try await wizard()
            }
            guard let shell else {
                throw ValidationError("Could not tell your shell from $SHELL. Pass --shell zsh, bash or fish.")
            }

            let environment = ProcessInfo.processInfo.environment
            // $HOME, as the shell sees it; `homeDirectoryForCurrentUser` ignores it.
            let home = environment["HOME"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) }
                ?? FileManager.default.homeDirectoryForCurrentUser
            let destination = output.map { URL(fileURLWithPath: $0.string) }
                ?? completionScriptURL(for: shell, environment: environment, home: home)

            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            // Same bytes as `scm --generate-completion-script`, which ends with a newline.
            try (SwiftCardanoMultitool.completionScript(for: shell) + "\n")
                .write(to: destination, atomically: true, encoding: .utf8)

            noora.success(.alert(
                "Installed \(shell.rawValue) completion to \(destination.path).",
                takeaways: completionNextSteps(
                    for: shell,
                    destination: destination,
                    customPath: output != nil,
                    environment: environment,
                    home: home
                ).map { "\($0)" }
            ))
        }
    }
}

/// Where each shell loads a user's completion scripts from without extra setup,
/// except zsh, whose `fpath` has no per-user folder by default.
func completionScriptURL(for shell: CompletionShell, environment: [String: String], home: URL) -> URL {
    func directory(_ variable: String, default fallback: String?) -> URL {
        if let value = environment[variable], !value.isEmpty {
            return URL(fileURLWithPath: value)
        }
        return fallback.map { home.appendingPathComponent($0) } ?? home
    }

    switch shell {
        case .bash:
            return directory("XDG_DATA_HOME", default: ".local/share")
                .appendingPathComponent("bash-completion/completions/scm")
        case .fish:
            return directory("XDG_CONFIG_HOME", default: ".config")
                .appendingPathComponent("fish/completions/scm.fish")
        default:
            return directory("ZDOTDIR", default: nil)
                .appendingPathComponent(".zfunc/_scm")
    }
}

/// What the user still has to do for the shell to find the script.
func completionNextSteps(
    for shell: CompletionShell,
    destination: URL,
    customPath: Bool,
    environment: [String: String],
    home: URL
) -> [String] {
    let folder = destination.deletingLastPathComponent().path
    switch shell {
        case .bash:
            if customPath {
                return ["Add `source \(destination.path)` to ~/.bashrc, then open a new shell."]
            }
            return [
                "Open a new shell. bash-completion 2 loads the script on first use of scm.",
                "Without bash-completion, add `source \(destination.path)` to ~/.bashrc.",
            ]
        case .fish:
            if customPath {
                return ["Add `source \(destination.path)` to ~/.config/fish/config.fish."]
            }
            return ["Open a new shell; fish loads the script on first use of scm."]
        default:
            let zdotdir = environment["ZDOTDIR"].flatMap { $0.isEmpty ? nil : $0 } ?? home.path
            let zshrc = URL(fileURLWithPath: zdotdir).appendingPathComponent(".zshrc")
            let rc = (try? String(contentsOf: zshrc, encoding: .utf8)) ?? ""
            var steps: [String] = []
            if !rc.contains(folder) && !(rc.contains(".zfunc") && !customPath) {
                steps.append("Add this to \(zshrc.path) before `compinit` runs: fpath=(\(folder) $fpath)")
                if !rc.contains("compinit") {
                    steps.append("…and, if nothing runs it yet: autoload -Uz compinit && compinit")
                }
            }
            steps.append("Open a new shell. If completion is stale, delete ~/.zcompdump* and open another.")
            return steps
    }
}
