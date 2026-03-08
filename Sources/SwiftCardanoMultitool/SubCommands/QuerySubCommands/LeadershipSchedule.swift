import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoChain

extension QueryMainCommand {
    struct LeadershipSchedule: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Query leadership schedule for a stake pool.",
            usage: """
            scm query leadership-schedule ---address-name test
            """,
            discussion: """
            Get the leadership schedule for a specific stake pool. You can 
            specify the pool operator using various formats, including bech32 
            (e.g., pool1...), hex hash, or a .node.vkey file. The command will 
            return the upcoming slots where the specified stake pool is 
            scheduled to produce blocks, along with relevant details such as 
            slot numbers.
            """
        )
        
        @Option(name: [.short, .long], help: "The pool operator (PoolOperator) to check. Supports: bech32 (pool1...), hex hash, .node.vkey file.")
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
        }
    }
}
