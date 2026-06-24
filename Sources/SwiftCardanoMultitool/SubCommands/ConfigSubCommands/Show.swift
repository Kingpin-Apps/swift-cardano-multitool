import Foundation
import ArgumentParser
import Noora
import SystemPackage

extension ConfigMainCommand {

    struct Show: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "show",
            abstract: "Show a configuration's contents, or its path with --path.",
            discussion: """
            Pick what to show: the scm configuration itself, the node config, a
            genesis file, or the topology file. Without a type you'll be prompted.
            Pass --path to print the resolved file path instead of the contents.
            """
        )

        @Argument(help: "What to show: config, node-config, genesis, or topology.")
        var type: ConfigTarget?

        @Option(name: .shortAndLong, help: "Genesis era (byron, shelley, alonzo, conway). Only used with 'genesis'.")
        var era: GenesisEra?

        @Flag(name: .long, help: "Print the resolved file path instead of the file contents.")
        var path: Bool = false

        /// Interactively gather the target (and era, for genesis) when missing.
        mutating func wizard() async throws {
            if type == nil {
                type = noora.singleChoicePrompt(
                    title: "Show Config",
                    question: "Which configuration would you like to show?",
                    description: "Choose what to display:"
                )
            }
            if type == .genesis, era == nil {
                era = Prompts.current.singleChoicePrompt(
                    title: "Genesis Era",
                    question: "Select the genesis era to display:",
                    description: nil,
                    filterMode: .disabled
                )
            }
        }

        mutating func run() async throws {
            if type == nil || (type == .genesis && era == nil) {
                try await wizard()
            }

            guard let type else {
                noora.error("A config type is required.")
                throw ExitCode.validationFailure
            }

            let config = try await MultitoolConfig.load()

            switch type {
                case .config:
                    if path {
                        guard let activePath = Environment.getFilePath(.config) else {
                            noora.error(
                                .alert(
                                    "No active config path is set.",
                                    takeaways: [
                                        "Set the \(.primary(Environment.config.rawValue)) environment variable.",
                                    ]
                                )
                            )
                            throw ExitCode.failure
                        }
                        print(activePath.string)
                    } else {
                        try printMultitoolConfig(config)
                    }

                case .nodeConfig:
                    let resolved = try resolveNodeConfigPath(config: config)
                    if path { print(resolved.string) }
                    else { try printJSONFile(at: resolved, label: "Node Config") }

                case .genesis:
                    guard let era else {
                        noora.error("A genesis era is required.")
                        throw ExitCode.validationFailure
                    }
                    let resolved = try resolveGenesisPath(era: era, config: config)
                    if path { print(resolved.string) }
                    else { try printJSONFile(at: resolved, label: "\(era.rawValue.capitalized) Genesis") }

                case .topology:
                    let resolved = try resolveTopologyPath(config: config)
                    if path { print(resolved.string) }
                    else { try printJSONFile(at: resolved, label: "Topology") }
            }
        }
    }
}
