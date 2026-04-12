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
        
        /// Wizard to interactively gather missing parameters
        mutating func wizard() async throws {
            if self.network == nil {
                self.network = noora.singleChoicePrompt(
                    title: "Network",
                    question: "Select the Cardano network:",
                    description: nil,
                    filterMode: .disabled
                )
            }
            
            if self.fileType == nil {
                self.fileType = noora.singleChoicePrompt(
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
            
            guard let configPath = self.configPath else {
                noora.error("Config path is required to save the config file.")
                throw ExitCode.validationFailure
            }

            let config = try MultitoolConfig.default(network: network.network)

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
                    "Configuration file saved to: \(.path(try .init(validating: "/" + absolute)))"
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
