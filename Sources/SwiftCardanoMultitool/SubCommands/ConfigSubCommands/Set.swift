import Foundation
import ArgumentParser
import Noora
import SystemPackage

extension ConfigMainCommand {

    struct Set: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "set",
            abstract: "Set the path to a configuration file.",
            discussion: """
            Set the path for the scm configuration, node config, or topology
            file. Without a type or --path you'll be prompted. Genesis files are
            derived from the node config and can't be set directly.
            """
        )

        @Argument(help: "What to set: config, node-config, or topology.")
        var type: ConfigTarget?

        @Option(name: .long, help: "Path to set. If omitted, you'll be prompted.")
        var path: FilePath?

        /// Interactively gather the target and path when missing.
        mutating func wizard() async throws {
            if type == nil {
                type = noora.singleChoicePrompt(
                    title: "Set Config",
                    question: "Which configuration path would you like to set?",
                    options: ConfigTarget.settableCases,
                    description: "Choose what to set:"
                )
            }
            if path == nil {
                let entered = noora.textPrompt(
                    title: "Path",
                    prompt: "Enter the path to the file:",
                    validationRules: [NonEmptyValidationRule(error: "Path cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                path = FilePath(entered)
            }
        }

        mutating func run() async throws {
            if type == nil || path == nil {
                try await wizard()
            }

            guard let type, let path else {
                noora.error("A config type and a path are required.")
                throw ExitCode.validationFailure
            }

            switch type {
                case .config:
                    warnIfPathMissing(path, label: "Config")
                    Environment.set(.config, value: path.string)
                    noora.success(
                        .alert(
                            "Active config set to \(.primary(path.string)).",
                            takeaways: [
                                "Applies to this session; export \(.command("\(Environment.config.rawValue)=\(path.string)")) to persist it.",
                            ]
                        )
                    )

                case .nodeConfig:
                    warnIfPathMissing(path, label: "Node config")
                    try await updateActiveCardanoConfig { $0.config = path }
                    noora.success(.alert("Node config path set to \(.primary(path.string))."))

                case .topology:
                    warnIfPathMissing(path, label: "Topology")
                    try await updateActiveCardanoConfig { $0.topology = path }
                    noora.success(.alert("Topology path set to \(.primary(path.string))."))

                case .genesis:
                    noora.error(
                        .alert(
                            "Genesis files can't be set directly.",
                            takeaways: [
                                "Genesis paths are derived from the node config.",
                                "Set the node config with \(.command("scm config set node-config --path <path>")).",
                            ]
                        )
                    )
                    throw ExitCode.validationFailure
            }
        }
    }
}
