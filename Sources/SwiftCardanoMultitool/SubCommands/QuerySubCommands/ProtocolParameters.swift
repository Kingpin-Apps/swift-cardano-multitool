import Foundation
import ArgumentParser
import Noora
import SystemPackage


extension QueryMainCommand {
    struct ProtocolParameters: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Query protocol parameters.")
        
        @Option(
            name: .shortAndLong,
            help: "The name of the file to save the protocol parameters to."
        )
        var fileName: FilePath? = nil
        
        @Flag(
            inversion: .prefixedNo,
            help: "Whether to save the output to a file."
        )
        var save = true
        
        /// Wizard to interactively gather missing parameters
        mutating func wizard() async throws {
            save = Prompts.current.yesOrNoChoicePrompt(
                title: "Save to File",
                question: "Would you like to save the protocol parameters to a file?",
                defaultAnswer: false,
                description: "Choose 'yes' to save the protocol parameters to a file, or 'no' to only display them on the console."
            )

            if fileName == nil && save {

                let cwd = FilePath(FileManager.default.currentDirectoryPath)

                let filePathString = Prompts.current.textPrompt(
                    title: "File Name",
                    prompt: "Enter the name of the file to save the protocol parameters to:",
                    description: "The file name where the protocol parameters will be saved. Default is 'protocol-parameters.json'.",
                    collapseOnAnswer: true
                )
                
                if filePathString.isEmpty {
                    fileName = cwd.appending("protocol-parameters.json")
                    return
                } else {
                    fileName = cwd.appending(filePathString)
                }
                
            }
        }
        
        mutating func run() async throws {
            if fileName == nil && save {
                try await wizard()
            }
            
            let config = try await MultitoolConfig.load()
            
            let context = try await getContext(config: config)
            
            try await printContextInfo(config: config, context: context)
            
            let protocolParameters = try await noora.progressStep(
                message: "Querying current protocol parameters...",
                successMessage: "Successfully retrieved the protocol parameters.",
                errorMessage: "Failed to retrieve the protocol parameters.",
                showSpinner: true
            ) { updateMessage in
                return try await context.protocolParameters()
            }
            
            spacedPrint(
                "\nProtocol Parameters: "
            )
            try noora.json(protocolParameters)
            
            if save {
                spacedPrint(
                    "Saving to file...\n"
                )
                guard let path = fileName else {
                    noora.error(
                        .alert(
                            "No file name provided to save protocol parameters.",
                            takeaways: [
                                "Please provide a valid file name using the --file-name option or disable saving by using the --no-save flag."
                            ]
                        )
                    )
                    throw ExitCode.failure
                }
                try protocolParameters.save(to: path.string, overwrite: true)
                
                noora.success(.alert("Protocol parameters saved to file:  \(.path(try .init(validating: path.string)))."))
            }
        }
    }
}
