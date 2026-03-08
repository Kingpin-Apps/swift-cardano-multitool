import Foundation
import ArgumentParser
import Noora
import SwiftCardanoUtils

extension RunMainCommand {
    struct SubmitApi: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "submit-api",
            abstract: "Run cardano-submit-api."
        )

        @Option(
            name: [.customShort("c"), .customLong("config")],
            help: "Path to the cardano-node config JSON file."
        )
        var nodeConfig: String?

        @Option(
            name: [.customShort("s"), .customLong("socket-path")],
            help: "Path to the cardano-node socket file."
        )
        var socketPath: String?

        @Option(
            name: .shortAndLong,
            help: "Port for the submit-api HTTP server. Defaults to 8090."
        )
        var port: Int?

        mutating func wizard(cardanoConfig: CardanoConfig?) async throws {
            if nodeConfig == nil {
                if let config = cardanoConfig?.config {
                    let useExisting = noora.yesOrNoChoicePrompt(
                        title: "Node Config",
                        question: "Use node config from your config file (\(config.string))?",
                        defaultAnswer: true,
                        description: "Choose 'no' to specify a different path."
                    )
                    nodeConfig = useExisting ? config.string : noora.textPrompt(
                        title: "Node Config",
                        prompt: "Path to the cardano-node config JSON file:"
                    )
                } else {
                    nodeConfig = noora.textPrompt(
                        title: "Node Config",
                        prompt: "Path to the cardano-node config JSON file:"
                    )
                }
            }

            if socketPath == nil {
                if let socket = cardanoConfig?.socket {
                    socketPath = socket.string
                } else {
                    socketPath = noora.textPrompt(
                        title: "Socket Path",
                        prompt: "Path to the cardano-node socket file:"
                    )
                }
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

            if nodeConfig == nil || socketPath == nil {
                try await wizard(cardanoConfig: config.cardano)
            }

            guard let cfg = nodeConfig, !cfg.isEmpty else {
                noora.error(.alert(
                    "Node config path is required.",
                    takeaways: ["Provide it with --config or set it in your config file."]
                ))
                throw ExitCode.failure
            }
            guard let socket = socketPath, !socket.isEmpty else {
                noora.error(.alert(
                    "Socket path is required.",
                    takeaways: ["Provide it with --socket-path or set it in your config file."]
                ))
                throw ExitCode.failure
            }

            var arguments = [
                "--config", cfg,
                "--socket-path", socket,
            ]
            if let p = port {
                arguments += ["--port", String(p)]
            }

            spacedPrint("Starting \(.primary("cardano-submit-api")) on port \(.secondary(String(port ?? 8090)))...")

            try await runForegroundProcess(binary: "cardano-submit-api", arguments: arguments)
        }
    }
}
