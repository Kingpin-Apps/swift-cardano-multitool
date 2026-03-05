import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoChain

extension QueryMainCommand {
    struct StakePool: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Query stake pool information.",
            usage: """
            scm query pool <poolId>
            """,
            discussion: """
            This command allows you to query information about a specific stake 
            pool. You can specify the pool operator using various formats, 
            including bech32 (e.g., pool1...), hex hash, or a .node.vkey file. 
            The command will return details about the specified stake pool, such
            as its metadata, performance, and delegation status.
            """,
            aliases: ["pool"]
        )
        
        @Option(name: [.short, .long], help: "The pool operator (PoolOperator) to delegate to. Supports: bech32 (pool1...), hex hash, .node.vkey file.")
        var poolOperator: PoolOperator?
        
        // MARK: - Wizard
        
        /// Interactive wizard to gather missing parameters
        mutating func wizard() async throws {
            poolOperator = try await getPoolOperator()
        }
        
        // MARK: - Run
        
        mutating func run() async throws {
            // Run wizard if required parameters are missing
            if poolOperator == nil {
                try await wizard()
            }
            
            guard let poolOperator = poolOperator else {
                noora.error(.alert(
                    "Pool Operator is required.",
                    takeaways: ["Provide a valid Pool Operator identifier."]
                ))
                throw ExitCode.validationFailure
            }
            
            let config = try await MultitoolConfig.load()
            let context = try await getContext(config: config)
            try await printContextInfo(config: config, context: context)
            
            spacedPrint("Querying stake pool information for \(.primary("\(poolOperator)"))...")
            
            let poolInfo = try await noora.progressStep(
                message: "Fetching stake pool information via \(context.name)...",
                successMessage: "Successfully retrieved stake pool information.",
                errorMessage: "Failed to retrieve stake pool information.",
                showSpinner: true
            ) { updateMessage in
                return try await context
                    .stakePoolInfo(poolId: try poolOperator.id(.bech32))
            }
            
        }
    }
}
