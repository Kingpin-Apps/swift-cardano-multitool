import ArgumentParser
import SwiftCardanoUtils

extension RunMainCommand {
    struct Ogmios: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Run ogmios.")
        
        mutating func run() async throws {
            let config = try await MultitoolConfig.load()
            
            let ogmios = try await SwiftCardanoUtils.Ogmios(
                configuration: config.toSwiftCardanoUtilsConfig()
            )
            
            try await ogmios.start()
        }
    }
}
