import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore



extension GenerateMainCommand {    
    struct PoolJSON: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Create a new pool.json file with the specified number of pools and their details."
        )
        
        @Option(name: .shortAndLong, help: "The name of the pool. The pool file will be saved as <poolName>.json.")
        var poolName: String? = nil
        
        @Option(name: .shortAndLong, help: "Overwrite the existing pool.json file if it exists.")
        var overwrite: Bool = false
        
        /// Wizard to interactively gather missing parameters
        mutating func wizard() async throws {
            poolName = noora.textPrompt(
                title: "Pool Name",
                prompt: "Enter the name of the pool:",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Pool name cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            
            try self.validate()
        }
        
        mutating func run() async throws {
            if poolName == nil {
                try await self.wizard()
            }
            
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            
            let poolFile = cwd.appending("\(poolName!).json")
            
            if !overwrite {
                do {
                    try FileUtils.checkFileNotExists(poolFile)
                } catch SwiftCardanoMultitoolError.fileAlreadyExists {
                    noora.error(.alert(
                        "Pool.json file already exist at location: \(poolFile.string)",
                        takeaways: [
                            "Delete or move the existing file if you want to create a new one with the same name.",
                            "Use the --overwrite flag to automatically overwrite the existing file."
                        ]
                    ))
                    throw ExitCode.validationFailure
                }
            }
            
            var pool = Pool(name: poolName!)
            
            try pool.save(to: poolFile, overwrite: overwrite)
            
            noora.success(.alert(
                "Pool.json file created successfully.",
                takeaways: [
                    "File location: \(poolFile.string)",
                    "You can edit the file to add more details about the pool, such as its description, ticker, homepage, and other metadata.",
                    "Make sure to keep the JSON structure valid when editing the file."
                ]
            ))
        }
    }
}
