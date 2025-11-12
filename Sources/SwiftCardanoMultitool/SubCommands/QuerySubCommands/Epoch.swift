import Foundation
import ArgumentParser
import Noora
import SwiftCardanoChain

extension QueryMainCommand {
    struct Epoch: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Get current epoch.")
        
        func run() async throws {
            let config = try await MultitoolConfig.load()
            let context = try await getContext(config: config)
            try await printInfo(config: config, context: context)
            
            let epoch = try await noora.progressStep(
                message: "Querying current epoch...",
                successMessage: "Successfully retrieved the current epoch.",
                errorMessage: "Failed to retrieve the current epoch.",
                showSpinner: true
            ) { updateMessage in
                return try await context.epoch()
            }
            
            spacedPrint(
                "\nCurrent Epoch: \(.primary(epoch.description)) \(.muted("(via \(context.name))"))"
            )
        }
    }
}
