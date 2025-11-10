import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoUtils

extension ConfigMainCommand {
    
    struct Select: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Select configuration values."
        )
        
        mutating func run() async throws {
            
            let configs = try await MultitoolConfigs.load()
            
            let selectedConfig = noora.singleChoicePrompt(
                title: "Select Config",
                question: "Select the configuration that you would like to use.",
                options: configs.configs.map { $0.key },
                description: "Choose one of the following configs:",
            )
            
            let configPath = configs.configs[selectedConfig]!
            
            Environment.set(.config, value: configPath.string)
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = [
                .prettyPrinted,
                .sortedKeys,
                .withoutEscapingSlashes
            ]
            
            try noora.json(configs, encoder: encoder)
            print("\n\n")
            
            await MainMenuCommand.main([])
        }
    }
}
