import Foundation
import ArgumentParser
import SystemPackage

extension ConfigMainCommand.Topology {

    struct Set: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "set",
            abstract: "Store the path to the Cardano node topology file."
        )

        @Argument(help: "Path to the topology file.")
        var path: FilePath

        mutating func run() async throws {
            warnIfPathMissing(path, label: "Topology")
            try await updateActiveCardanoConfig { $0.topology = path }
            noora.success(.alert("Topology path set to \(.primary(path.string))."))
        }
    }
}
