import Foundation
import ArgumentParser
import SystemPackage

extension ConfigMainCommand.NodeConfig {

    struct Show: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "show",
            abstract: "Display the Cardano node configuration (config.json)."
        )

        @Option(
            name: .long,
            help: "Path to the node config file. Defaults to the [cardano] config path in the active config."
        )
        var path: FilePath?

        mutating func run() async throws {
            let config = try await MultitoolConfig.load()
            let resolved = try resolveNodeConfigPath(explicit: path, config: config)
            try printJSONFile(at: resolved, label: "Node Config")
        }
    }
}
