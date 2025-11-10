import Foundation
import ArgumentParser
import Noora
import SwiftCardanoUtils

struct VersionMainCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Show the application's version."
    )
    
    func run() async throws {
        let config = try await MultitoolConfig.load()
        
        let context = try await getContext(config: config)
        
        try await printInfo(config: config, context: context)
    }
}
