import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoUtils
import SwiftCardanoCore

extension ConfigMainCommand {

    struct Init: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Initialize a configuration file."
        )

        @Option(name: .shortAndLong, help: "The Cardano network (mainnet, preprod, preview, guildnet, sanchonet).")
        var network: ConfigNetwork? = nil

        @Option(name: .shortAndLong, help: "The config file format (json, toml).")
        var fileType: ConfigFileType? = nil

        @Option(name: .long, help: "The path to save the config file. Defaults to $HOME/.scm/config-{network}.{fileType}.")
        var configPath: FilePath? = nil

        @Flag(help: "Whether to perform a dry run without writing the file.")
        var isDryRun: Bool = false

        @Flag(name: .shortAndLong, help: "Overwrite the config file if it already exists.")
        var overwrite: Bool = false

        private func defaultConfigPath(network: ConfigNetwork, fileType: ConfigFileType) -> FilePath {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            return FilePath("\(home)/.scm/config-\(network.rawValue).\(fileType.rawValue)")
        }

        /// Best-effort autodetection of the node socket, config, and topology paths so a
        /// freshly generated config works against a local node without hand-editing.
        ///
        /// - Socket: the canonical `CARDANO_NODE_SOCKET_PATH` (what cardano-cli and
        ///   cardano-node themselves read), falling back to `CARDANO_SOCKET_PATH`.
        /// - Config / topology: the `share/<network>/{config,topology}.json` pair that
        ///   ships alongside the cardano-node binary (`…/bin/cardano-node` ⇒
        ///   `…/share/<network>/…`). The cardano-cli install dir is tried as a fallback.
        ///
        /// Only slots that are still empty are filled, so values already resolved from
        /// the environment (e.g. `CARDANO_CONFIG`) are never overwritten.
        /// - Returns: Human-readable descriptions of what was detected, for display.
        private func discoverCardanoPaths(
            network: ConfigNetwork,
            into config: inout MultitoolConfig
        ) -> [String] {
            guard config.cardano != nil else { return [] }
            var found: [String] = []

            // Socket — prefer the canonical CARDANO_NODE_SOCKET_PATH. The socket file is
            // created by the node at runtime, so we don't require it to exist yet.
            if config.cardano?.socket == nil,
               let socket = Environment.getFilePath(.cardanoNodeSocketPath)
                ?? Environment.getFilePath(.cardanoSocketPath) {
                config.cardano?.socket = socket
                found.append("socket → \(socket.string)")
            }

            // Config + topology — discover from the node (then cli) install's
            // share/<network>/ directory.
            if config.cardano?.config == nil || config.cardano?.topology == nil {
                let binaries = [config.cardano?.node, config.cardano?.cli].compactMap { $0 }
                for binary in binaries {
                    // …/bin/cardano-node → …/share/<network>
                    let shareDir = binary
                        .removingLastComponent()      // strip the binary
                        .removingLastComponent()      // strip bin/
                        .appending("share")
                        .appending(network.rawValue)

                    if config.cardano?.config == nil {
                        let candidate = shareDir.appending("config.json")
                        if FileManager.default.fileExists(atPath: candidate.string) {
                            config.cardano?.config = candidate
                            found.append("config → \(candidate.string)")
                        }
                    }
                    if config.cardano?.topology == nil {
                        let candidate = shareDir.appending("topology.json")
                        if FileManager.default.fileExists(atPath: candidate.string) {
                            config.cardano?.topology = candidate
                            found.append("topology → \(candidate.string)")
                        }
                    }
                    if config.cardano?.config != nil && config.cardano?.topology != nil {
                        break
                    }
                }
            }

            return found
        }
        
        /// Wizard to interactively gather missing parameters
        mutating func wizard() async throws {
            if self.network == nil {
                self.network = Prompts.current.singleChoicePrompt(
                    title: "Network",
                    question: "Select the Cardano network:",
                    description: nil,
                    filterMode: .disabled
                )
            }

            if self.fileType == nil {
                self.fileType = Prompts.current.singleChoicePrompt(
                    title: "File Type",
                    question: "Select the config file format:",
                    description: nil,
                    filterMode: .disabled
                )
            }

        }

        mutating func run() async throws {
            if self.network == nil || self.fileType == nil {
                try await self.wizard()
            }
            
            guard let network = self.network, let fileType = self.fileType else {
                noora.error("Network and file type are required to initialize the config.")
                throw ExitCode.validationFailure
            }

            if configPath == nil && !isDryRun {
                let envConfigPath = Environment.getFilePath(.config)

                if let envConfigPath = envConfigPath {
                    let useEnv = noora.yesOrNoChoicePrompt(
                        title: "Use Environment Config Path",
                        question: "An environment variable for config path is set to \(envConfigPath). Do you want to use this path?",
                        defaultAnswer: true,
                        description: "If yes, the configuration will be saved to the path specified in the environment variable."
                    )
                    if useEnv {
                        self.configPath = envConfigPath
                    }
                }

                if self.configPath == nil {
                    self.configPath = defaultConfigPath(network: network, fileType: fileType)
                }
            }
            
            var config = try MultitoolConfig.default(network: network.network)

            // Autodetect node socket / config / topology so the generated file works
            // against a local node without hand-editing.
            let discovered = discoverCardanoPaths(network: network, into: &config)
            if discovered.isEmpty {
                noora.info(.alert(
                    "Could not autodetect node socket / config / topology paths.",
                    takeaways: [
                        "Set \(.primary("CARDANO_NODE_SOCKET_PATH")) for the node socket.",
                        "Install cardano-node so its \(.primary("share/\(network.rawValue)/")) config + topology can be found, or edit the generated file.",
                    ]
                ))
            } else {
                noora.info(.alert(
                    "Autodetected Cardano node paths:",
                    takeaways: discovered.map { TerminalText(stringLiteral: $0) }
                ))
            }

            switch fileType {
                case .json:
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                    try noora.json(config, encoder: encoder)
                case .toml:
                    print(String(data: try config.encodeAsToml(), encoding: .utf8) ?? "")
                case .yaml:
                    print(String(data: try config.encodeAsYaml(), encoding: .utf8) ?? "")
            }
            print("\n")

            if !isDryRun {
                guard let configPath = self.configPath else {
                    noora.error("Config path is required to save the config file.")
                    throw ExitCode.validationFailure
                }

                let dirPath = (configPath.string as NSString).deletingLastPathComponent
                try FileManager.default.createDirectory(
                    atPath: dirPath,
                    withIntermediateDirectories: true
                )

                if !overwrite && FileManager.default.fileExists(atPath: configPath.string) {
                    self.overwrite = noora.yesOrNoChoicePrompt(
                        title: "Overwrite",
                        question: "A config file already exists at \(configPath). Overwrite it?",
                        defaultAnswer: false,
                        description: "If no, the command will exit without writing the file."
                    )
                    guard overwrite else {
                        noora.warning(.alert("Skipped.", takeaway: "Config file was not overwritten."))
                        return
                    }
                }

                try config.save(to: configPath, as: fileType, overwrite: overwrite)
                
                let absolute = FileManager.default.currentDirectoryPath + "/" + configPath.string

                spacedPrint(
                    "Configuration file saved to: \(pathComponent("/" + absolute))"
                )

                noora.success(
                    .alert("Configuration file successfully initialized.")
                )
            } else {
                noora.info("Dry run enabled, configuration will not be saved to a file.")
            }
        }
    }
}
