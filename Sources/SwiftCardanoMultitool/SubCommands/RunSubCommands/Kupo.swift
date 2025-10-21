import ArgumentParser
import SwiftCardanoUtils

extension RunMainCommand {
    struct Kupo: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Run kupo.")
        
        mutating func run() async throws {
            let config = try await MultitoolConfig.load()
            
            let kupo = try await SwiftCardanoUtils.Kupo(
                configuration: config.toSwiftCardanoUtilsConfig()
            )
            
            try await kupo.start()
        }
    }
}
