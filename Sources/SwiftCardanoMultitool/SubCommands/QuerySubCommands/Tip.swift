import Foundation
import ArgumentParser
import Noora


extension QueryMainCommand {
    struct Tip: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Query the tip of the blockchain.")
        
        func run() async throws {
            let config = try await MultitoolConfig.load()
            
            let context = try await getContext(config: config)
            
            let tip = try await context.lastBlockSlot()
            
            print(noora.format(
                "Current Tip: \(.primary(tip.description)) \(.muted("(via \(String(describing: type(of: context))))"))"
            ))
        }
    }
}
