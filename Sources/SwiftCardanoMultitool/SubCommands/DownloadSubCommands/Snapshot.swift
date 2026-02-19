import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils


extension DownloadMainCommand {
    struct Snapshot: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Download blockchain snapshot.")
        
        @Option(name: .shortAndLong, help: "The network to download database snapshot for. Will use the default network if not specified.")
        var network: Network? = nil
        
        /// Wizard to interactively gather missing parameters
        mutating func wizard() async throws {
            network = noora.singleChoicePrompt(
                title: "Cardano Network",
                question: "Select the Cardano network to download snapshot for:",
                options: Network.allCases.filter({ network in
                    network != .guildnet && network != .sanchonet && network !=
                        .custom(0)
                }),
                description: "Available networks: mainnet, preview, preprod.",
            )
        }
        
        /// Main execution function
        mutating func run() async throws {
            
            let config = try await MultitoolConfig.load()
            
            if network == nil {
                if let cardanoConfig = config.cardano {
                    network = cardanoConfig.network
                } else {
                    try await self.wizard()
                }
            }
            
            let mithril = try await MithrilClient(
                configuration: config.toSwiftCardanoUtilsConfig()
            )
            
            let _ = try await mithril.listSnapshots()
            
            let _ = try await noora.progressStep(
                message: "Downloading latest snapshot...",
                successMessage: "Successfully downloaded the latest snapshot.",
                errorMessage: "Failed to download the latest snapshot",
                showSpinner: true
            ) { updateMessage in
                return try await mithril.downloadLatestSnapshot()
            }
            
        }
    }
}
