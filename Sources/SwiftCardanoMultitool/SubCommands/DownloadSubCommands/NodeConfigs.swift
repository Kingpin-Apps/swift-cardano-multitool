import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils


extension DownloadMainCommand {
    struct NodeConfigs: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Download node configuration files from https://book.world.dev.cardano.org"
        )
        
        @Option(name: .shortAndLong, help: "The network to download configs for.")
        var network: Network? = nil
        
        @Flag(help: "Whether to download for a block producer node or relay node.")
        var blockPoducer: Bool = false
        
        @Flag(help: "Whether to download configs for cardano-db-sync.")
        var dbSync = false
        
        @Flag(help: "Whether to download configs for cardano-submit-api.")
        var submitApi = false
        
        /// Wizard to interactively gather missing parameters
        mutating func wizard() async throws {
            let noora = try await Terminal.shared.noora()
            
            network = noora.singleChoicePrompt(
                title: "Cardano Network",
                question: "Select the Cardano network to download configs for:",
                options: Network.allCases.filter({ network in
                    network != .guildnet && network != .sanchonet && network !=
                        .custom(0)
                }),
                description: "Available networks: mainnet, preview, preprod.",
            )
            
            blockPoducer = noora.yesOrNoChoicePrompt(
                title: "Node Type",
                question: "Is this for a block producer node?",
                defaultAnswer: false,
                description: "Choose 'no' for a relay node."
            )
            
            dbSync = noora.yesOrNoChoicePrompt(
                title: "Cardano-DB-Sync",
                question: "Do you want to download configs for cardano-db-sync?",
                defaultAnswer: false,
                description: "Choose 'yes' to download the db-sync configs."
            )
            
            submitApi = noora.yesOrNoChoicePrompt(
                title: "Cardano-Submit-API",
                question: "Do you want to download configs for cardano-submit-api?",
                defaultAnswer: false,
                description: "Choose 'yes' to download the submit-api configs."
            )
        }
        
        /// Main execution function
        mutating func run() async throws {
            if network == nil {
                try await self.wizard()
            }
            
            let noora = try await Terminal.shared.noora()
            
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            
            let downloadDir = cwd.appending("config")
            try FileManager.default.createDirectory(
                atPath: downloadDir.string,
                withIntermediateDirectories: true
            )
            
            print(
                noora.format("Downloading configs to: \(.path(try .init(validating: downloadDir.string)))"),
                terminator: "\n\n"
            )
            let baseUrl = "https://book.world.dev.cardano.org/environments/\(network!.description)/"
            
            var configFiles: [String] = []
            
            if blockPoducer {
                configFiles.append("config-bp.json")
            } else {
                configFiles.append("config.json")
            }
            configFiles.append(contentsOf: [
                "topology.json",
                "byron-genesis.json",
                "shelley-genesis.json",
                "alonzo-genesis.json",
                "conway-genesis.json",
                "peer-snapshot.json",
                "checkpoints.json",
            ])

            if dbSync {
                configFiles.append("db-sync-config.json")
            }

            if submitApi {
                configFiles.append("submit-api-config.json")
            }
            
            print(
                noora.format(
                    "Downloading configurations for network: \(.primary(network!.description)) from \(.link(title: baseUrl, href: baseUrl))"),
                terminator: "\n\n"
            )
            
            for file in configFiles {
                let fileUrl = URL(string: baseUrl + file)!
                let destination = downloadDir.appending(file)
                do {
                    let (data, response) = try await URLSession.shared.data(from: fileUrl)
                    guard let httpResponse = response as? HTTPURLResponse,
                            (200...299).contains(httpResponse.statusCode)
                    else {
                        noora.warning(
                            .alert(
                                "Failed to download \(file): Invalid response code: \((response as? HTTPURLResponse)?.statusCode ?? 0)",
                                takeaway: "Ensure the file is still publicly available at the source URL: \(fileUrl.absoluteString)"
                            ),
                        )
                        continue
                    }
                    
                    try data.write(to: URL(fileURLWithPath: destination.string))
                    
                    noora.success(
                        .alert("Downloaded \(.primary(file)) to \(.path(try .init(validating: destination.string)))")
                    )
                } catch {
                    noora.error(
                        .alert(
                            "Failed to download \(file). \(error.localizedDescription)",
                            takeaways: [
                                "Check your internet connection.",
                                "Ensure the file still exists at the source URL: \(fileUrl.absoluteString)"
                            ]
                        )
                    )
                }
            }
        }
    }
}
