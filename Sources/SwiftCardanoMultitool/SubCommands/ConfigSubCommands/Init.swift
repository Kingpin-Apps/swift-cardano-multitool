import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoUtils

extension ConfigMainCommand {
    
    struct Init: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Initialize a configuration file."
        )
        
        @Option(name: .shortAndLong, help: "The path to save the config file.")
        var configPath: FilePath? = nil
        
        @Flag(help: "Whether to perform a dry run without writing the file.")
        var isDryRun: Bool = false
        
        /// Wizard to interactively gather missing parameters
        mutating func wizard() async throws {
            let noora = try await Terminal.shared.noora()
            
            self.isDryRun = noora.yesOrNoChoicePrompt(
                title: "Is Dry Run",
                question: "Perform a dry run without writing the file?",
                defaultAnswer: false,
                description: "If yes, the configuration will be displayed but not saved to a file."
            )
            
            if !self.isDryRun {
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
                        return
                    }
                }
                                
                let configFileName = noora.textPrompt(
                    title: "Config File Name",
                    prompt: "Enter the name of the configuration file:",
                    description: "The path where the configuration file will be saved.",
                    collapseOnAnswer: false,
                    validationRules: [NonEmptyValidationRule(error: "Config name cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                
                let cwd = FilePath(FileManager.default.currentDirectoryPath)
                self.configPath = cwd.appending(configFileName)
            }
        }
        
        mutating func run() async throws {
            if configPath == nil && !isDryRun {
                try await self.wizard()
            }
            
            let noora = try await Terminal.shared.noora()
            let config = try MultitoolConfig.default()
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = [
                .prettyPrinted,
                .sortedKeys,
                .withoutEscapingSlashes
            ]
            
            try noora.json(config, encoder: encoder)
            print("\n\n")
            
            if !isDryRun {
                try config.save(to: configPath!)
                
                spacedPrint(
                    "Configuration file saved to: \(.path(try .init(validating: configPath!.string)))"
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
