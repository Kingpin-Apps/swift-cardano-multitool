import Foundation
import ArgumentParser
import Noora
import SwiftCardanoChain

extension QueryMainCommand {
    struct Era: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Get current era.")
        
        func run() async throws {
            let config = try await MultitoolConfig.load()
            let context = try await getContext(config: config)
            try await printContextInfo(config: config, context: context)
            
            let era = try await noora.progressStep(
                message: "Querying current era...",
                successMessage: "Successfully retrieved the current era.",
                errorMessage: "Failed to retrieve the current era.",
                showSpinner: true
            ) { updateMessage in
                return try await context.era()
            }
            
            guard let era = era else {
                noora.error(.alert(
                    "Failed to determine the current era. \(String(describing: era))",
                    takeaways: [
                        "Ensure the node is fully synced and reachable.",
                        "Verify the chain context configuration."
                    ]
                 ))
                throw ExitCode.failure
            }
            
            spacedPrint(
                "\nCurrent Era: \(.primary(era.description.capitalized)) \(.muted("(via \(context.name))"))"
            )
        }
    }
}
