import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoUtils

extension ConfigMainCommand {
    
    struct Show: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show current configuration."
        )
        
        mutating func run() async throws {
            
            let config = try await MultitoolConfig.load()
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = [
                .prettyPrinted,
                .sortedKeys,
                .withoutEscapingSlashes
            ]
            
            try noora.json(config, encoder: encoder)
            print("\n\n")
        }
    }
}
