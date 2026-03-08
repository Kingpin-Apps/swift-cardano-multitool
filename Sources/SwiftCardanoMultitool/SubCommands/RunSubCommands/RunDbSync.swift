import Foundation
import ArgumentParser
import Noora
import SwiftCardanoUtils

extension RunMainCommand {
    struct DbSync: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "db-sync",
            abstract: "Run cardano-db-sync."
        )

        @Option(
            name: [.customShort("c"), .customLong("config")],
            help: "Path to the cardano-db-sync config JSON file."
        )
        var dbSyncConfig: String?

        @Option(
            name: [.customShort("s"), .customLong("socket-path")],
            help: "Path to the cardano-node socket file."
        )
        var socketPath: String?

        @Option(
            name: [.customShort("S"), .customLong("state-dir")],
            help: "Directory for cardano-db-sync state."
        )
        var stateDir: String?

        @Option(
            name: [.customLong("schema-dir")],
            help: "Path to the SQL schema directory. If omitted, the bundled schema is used."
        )
        var schemaDir: String?

        mutating func wizard(cardanoConfig: CardanoConfig?) async throws {
            if dbSyncConfig == nil {
                dbSyncConfig = noora.textPrompt(
                    title: "Db-Sync Config",
                    prompt: "Path to the cardano-db-sync config JSON file:"
                )
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

            if stateDir == nil {
                stateDir = noora.textPrompt(
                    title: "State Directory",
                    prompt: "Directory for cardano-db-sync state (will be created if needed):"
                )
            }
        }

        mutating func run() async throws {
            let config = try await MultitoolConfig.load()

            if dbSyncConfig == nil || socketPath == nil || stateDir == nil {
                try await wizard(cardanoConfig: config.cardano)
            }

            guard let configPath = dbSyncConfig, !configPath.isEmpty else {
                noora.error(.alert(
                    "Db-sync config path is required.",
                    takeaways: ["Provide it with --config or via the interactive prompt."]
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
            guard let state = stateDir, !state.isEmpty else {
                noora.error(.alert(
                    "State directory is required.",
                    takeaways: ["Provide it with --state-dir or via the interactive prompt."]
                ))
                throw ExitCode.failure
            }

            var arguments = [
                "--config", configPath,
                "--socket-path", socket,
                "--state-dir", state,
            ]
            if let schema = schemaDir {
                arguments += ["--schema-dir", schema]
            }

            spacedPrint("Starting \(.primary("cardano-db-sync"))...")
            noora.warning(.alert(
                "cardano-db-sync requires a running PostgreSQL instance.",
                takeaway: "Ensure the PGPASSFILE or connection string environment variables are set."
            ))

            try await runForegroundProcess(binary: "cardano-db-sync", arguments: arguments)
        }
    }
}
