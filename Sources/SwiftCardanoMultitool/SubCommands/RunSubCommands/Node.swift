import ArgumentParser
import SwiftCardanoUtils

extension RunMainCommand {
    struct Node: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Run cardano-node.")
        
        mutating func run() async throws {
            let config = try await MultitoolConfig.load()
            
            let node = try await CardanoNode(
                configuration: config.toSwiftCardanoUtilsConfig()
            )
            
            try await node.start()
        }
    }
}
