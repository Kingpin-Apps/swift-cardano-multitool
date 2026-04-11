import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoChain


extension WorkOfflineMainCommand {
    struct New: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "new",
            abstract: "Create a new offline transfer file.",
            usage: """
            scm work-offline new
            """,
            discussion: """
            This command allows you to create a new offline transfer file. An 
            offline transfer file is a JSON file that contains all the necessary
            information for performing an offline transaction, such as the 
            sender and recipient addresses, the amount to be transferred, and 
            any additional metadata. This file can then be used in conjunction 
            with the 'sign' command to complete the offline transaction process.
            """
        )
        
        @Option(name: [.short, .long], help: "Output filepath of the offline transfer file.")
        var outFile: FilePath?
        
        // MARK: - Run
        
        mutating func run() async throws {
            let config = try await MultitoolConfig.load()
            
            if (outFile == nil) {
                if let offlineFile = config.offlineFile {
                    outFile = offlineFile
                } else {
                    let cwd = FilePath(FileManager.default.currentDirectoryPath)
                    outFile = cwd.appending("offline-transfer.json")
                }
            }
            
            guard let outFile else {
                noora.error(.alert(
                    "Output file path is required.",
                    takeaways: ["Provide a valid output file path using the --out option or set 'offlineFile' in the config file."]
                ))
                throw ExitCode.validationFailure
            }
            
            let context = try await getContext(config: config)
            try await printContextInfo(config: config, context: context)
            
            let absolute = FileManager.default.currentDirectoryPath + "/" + outFile.string
            
            spacedPrint("\nBuilding a fresh new offline transfer JSON at: \(.path(try .init(validating: absolute)))")
            
            guard let version = SwiftCardanoMultitool.version else {
                throw SwiftCardanoMultitoolError.invalidConfiguration(
                    "Unable to retrieve SwiftCardanoMultitool version."
                )
            }
            
            let protocolParameters = try await getProtocolParameters(
                context: context
            )
            
            let protocolData = try await OfflineTransferProtocolData(
                protocolParameters: protocolParameters,
                genesisParameters: context.genesisParameters(),
                era: context.era(),
                network: config.cardano?.network ?? .preview
            )
            
            var offlineTransfer = try OfflineTransfer.new(at: outFile)
            offlineTransfer.general = OfflineTransferGeneral(
                onlineVersion: "SwiftCardanoMultitool v\(version) via \(context.name)",
            )
            offlineTransfer.protocol = protocolData
            
            try offlineTransfer.save(to: outFile)
            
            try noora.json(offlineTransfer)
        }
    }
}
