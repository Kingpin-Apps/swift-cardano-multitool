import Foundation
import ArgumentParser
import Noora
import SwiftCardanoChain

extension QueryMainCommand {
    struct Tip: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Query the tip of the blockchain.",
            usage: """
            scm query tip
            """,
            discussion: """
            This command retrieves the current tip of the blockchain, which 
            includes information such as the current slot number, block hash, 
            and block number. The output is displayed in a human-readable 
            format, and if the context supports it (like Cardano CLI), the full 
            JSON response will also be printed for more detailed information.
            """
        )
        
        func run() async throws {
            let config = try await MultitoolConfig.load()
            let context = try await getContext(config: config)
            try await printContextInfo(config: config, context: context)
            
            if let context = context as? CardanoCliChainContext {
                let chainTip = try await noora.progressStep(
                    message: "Querying blockchain tip...",
                    successMessage: "Successfully retrieved the blockchain tip.",
                    errorMessage: "Failed to retrieve the blockchain tip.",
                    showSpinner: true
                ) { updateMessage in
                    return try await context.queryChainTip()
                }
                
                spacedPrint(
                    "\nCurrent Tip: "
                )
                try noora.json(chainTip)
                
                spacedPrint(
                    "\n\n\(.muted("(via \(context.name))"))"
                )
            } else {
                let tip = try await noora.progressStep(
                    message: "Querying blockchain tip...",
                    successMessage: "Successfully retrieved the blockchain tip.",
                    errorMessage: "Failed to retrieve the blockchain tip.",
                    showSpinner: true
                ) { updateMessage in
                    return try await context.lastBlockSlot()
                }
                
                spacedPrint(
                    "Current Tip: \(.primary(tip.description)) \(.muted("(via \(context.name))"))"
                )
            }
        }
    }
}
