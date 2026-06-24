import Foundation
import ArgumentParser
import SystemPackage

extension ConfigMainCommand.Genesis {

    struct Show: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "show",
            abstract: "Display a Cardano genesis file."
        )

        @Option(name: .shortAndLong, help: "Genesis era: byron, shelley, alonzo, or conway.")
        var era: GenesisEra?

        @Option(
            name: .long,
            help: "Path to the genesis file. Defaults to resolving it from the node config."
        )
        var path: FilePath?

        /// Interactively gather the era when it wasn't provided on the command line.
        mutating func wizard() async throws {
            if era == nil {
                era = Prompts.current.singleChoicePrompt(
                    title: "Genesis Era",
                    question: "Select the genesis era to display:",
                    description: nil,
                    filterMode: .disabled
                )
            }
        }

        mutating func run() async throws {
            if era == nil {
                try await wizard()
            }

            guard let era else {
                noora.error("A genesis era is required.")
                throw ExitCode.validationFailure
            }

            let config = try await MultitoolConfig.load()
            let resolved = try resolveGenesisPath(era: era, explicit: path, config: config)
            try printJSONFile(at: resolved, label: "\(era.rawValue.capitalized) Genesis")
        }
    }
}
