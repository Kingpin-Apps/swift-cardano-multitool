import Foundation
import ArgumentParser
import SystemPackage

extension ConfigMainCommand.NodeConfig {

    struct Set: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "set",
            abstract: "Store the path to the Cardano node configuration file."
        )

        @Argument(help: "Path to the node config (config.json) file.")
        var path: FilePath

        mutating func run() async throws {
            warnIfPathMissing(path, label: "Node config")
            try await updateActiveCardanoConfig { $0.config = path }
            noora.success(.alert("Node config path set to \(.primary(path.string))."))
        }
    }
}
