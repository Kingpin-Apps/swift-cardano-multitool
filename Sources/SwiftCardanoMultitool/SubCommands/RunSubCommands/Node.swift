import ArgumentParser
import SwiftCardanoUtils

extension RunMainCommand {
    struct Node: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Run cardano-node.")
        
        @Option(
            name: .shortAndLong,
            help: "Whether to use the default entrypoint for the container or build the arguments from the config."
        )
        var useDefaultEntrypoint: Bool?
        
        mutating func wizard() async throws {
            useDefaultEntrypoint = noora.yesOrNoChoicePrompt(
                title: "Use Default Entrypoint?",
                question: "Would you like to use the default entrypoint for the container, or build the arguments from the config file?",
                defaultAnswer: false,
                description: "Using the default entrypoint will run the node with the default command and arguments defined in the container image. Building the arguments from the config file will construct the command and arguments based on the configuration provided in your config file. Choose 'yes' to use the default entrypoint, or 'no' to build the command and arguments from the config file."
            )
        }
        
        mutating func run() async throws {
            
            let config = try await MultitoolConfig.load()
            
            guard let cardanoConfig = config.cardano else {
                noora.error(.alert(
                    "Cardano configuration missing: \(config)",
                    takeaways: [
                        "Please ensure that your config file contains a 'cardano' section with the necessary configuration for running the node."
                    ]
                ))
                throw ExitCode.failure
            }
            
            if let container = cardanoConfig.container,
               useDefaultEntrypoint == nil {
                try await wizard()
            } else {
                useDefaultEntrypoint = false
            }
            
            let node = try await CardanoNode(
                configuration: config.toSwiftCardanoUtilsConfig()
            )
            
            try await node.start(useDefaultEntrypoint: useDefaultEntrypoint!)
        }
    }
}
