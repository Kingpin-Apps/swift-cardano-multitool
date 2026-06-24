import Foundation
import ArgumentParser
import SystemPackage

extension ConfigMainCommand.Topology {

    struct Show: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "show",
            abstract: "Display the Cardano node topology file."
        )

        @Option(
            name: .long,
            help: "Path to the topology file. Defaults to the [cardano] topology path in the active config."
        )
        var path: FilePath?

        mutating func run() async throws {
            let config = try await MultitoolConfig.load()
            let resolved = try resolveTopologyPath(explicit: path, config: config)
            try printJSONFile(at: resolved, label: "Topology")
        }
    }
}
