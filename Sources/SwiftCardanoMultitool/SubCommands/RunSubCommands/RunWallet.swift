import Foundation
import ArgumentParser
import Noora
import SwiftCardanoUtils

extension RunMainCommand {
    struct Wallet: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "cardano-wallet",
            abstract: "Run cardano-wallet."
        )

        @Option(
            name: [.customShort("s"), .customLong("node-socket")],
            help: "Path to the cardano-node socket file."
        )
        var nodeSocket: String?

        @Option(
            name: [.customShort("d"), .customLong("database")],
            help: "Directory for cardano-wallet's database."
        )
        var database: String?

        @Option(
            name: .shortAndLong,
            help: "Port for the wallet HTTP server. Defaults to 8090."
        )
        var port: Int?

        @Option(
            name: [.customLong("testnet")],
            help: "Path to the Byron genesis JSON file (for testnet). Mutually exclusive with --mainnet."
        )
        var testnet: String?

        @Flag(
            name: [.customLong("mainnet")],
            help: "Connect to mainnet. Mutually exclusive with --testnet."
        )
        var mainnet: Bool = false

        mutating func wizard(cardanoConfig: CardanoConfig?) async throws {
            if nodeSocket == nil {
                if let socket = cardanoConfig?.socket {
                    nodeSocket = socket.string
                } else {
                    nodeSocket = noora.textPrompt(
                        title: "Node Socket",
                        prompt: "Path to the cardano-node socket file:"
                    )
                }
            }

            if !mainnet && testnet == nil {
                let network = cardanoConfig?.network
                let isMainnet = network == .mainnet
                mainnet = isMainnet
                if !mainnet {
                    testnet = noora.textPrompt(
                        title: "Byron Genesis",
                        prompt: "Path to the Byron genesis JSON file (required for testnet/preview/preprod):"
                    )
                }
            }

            if database == nil {
                database = noora.textPrompt(
                    title: "Database Directory",
                    prompt: "Directory for cardano-wallet's database (will be created if needed):"
                )
            }

            if port == nil {
                let useDefault = noora.yesOrNoChoicePrompt(
                    title: "Port",
                    question: "Use default port (8090)?",
                    defaultAnswer: true,
                    description: "Choose 'no' to specify a custom port."
                )
                if !useDefault {
                    let portStr = noora.textPrompt(
                        title: "Port",
                        prompt: "Enter the port number:"
                    )
                    port = Int(portStr)
                }
            }
        }

        mutating func run() async throws {
            let config = try await MultitoolConfig.load()

            let needsWizard = nodeSocket == nil || database == nil || (!mainnet && testnet == nil)
            if needsWizard {
                try await wizard(cardanoConfig: config.cardano)
            }

            guard let socket = nodeSocket, !socket.isEmpty else {
                noora.error(.alert(
                    "Node socket path is required.",
                    takeaways: ["Provide it with --node-socket or set it in your config file."]
                ))
                throw ExitCode.failure
            }
            guard let db = database, !db.isEmpty else {
                noora.error(.alert(
                    "Database directory is required.",
                    takeaways: ["Provide it with --database or via the interactive prompt."]
                ))
                throw ExitCode.failure
            }

            var arguments = [
                "serve",
                "--node-socket", socket,
                "--database", db,
            ]

            if mainnet {
                arguments.append("--mainnet")
            } else if let genesisFile = testnet, !genesisFile.isEmpty {
                arguments += ["--testnet", genesisFile]
            } else {
                noora.error(.alert(
                    "Network not specified.",
                    takeaways: ["Pass --mainnet or --testnet <byron-genesis-file>."]
                ))
                throw ExitCode.failure
            }

            if let p = port {
                arguments += ["--port", String(p)]
            }

            spacedPrint("Starting \(.primary("cardano-wallet")) on port \(.secondary(String(port ?? 8090)))...")

            try await runForegroundProcess(binary: "cardano-wallet", arguments: arguments)
        }
    }
}
