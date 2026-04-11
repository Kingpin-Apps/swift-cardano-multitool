import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoChain


extension WorkOfflineMainCommand {
    struct ClearFiles: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "clear-files",
            abstract: "Remove all attached files from the offline transfer file.",
            discussion: """
            Clears the files list in the offline transfer file, freeing up space
            by removing all previously attached file embeddings.
            """
        )

        @Option(name: [.short, .long], help: "Path to the offline transfer file.")
        var inFile: FilePath?

        mutating func run() async throws {
            let config = try await MultitoolConfig.load()

            if inFile == nil {
                if let offlineFile = config.offlineFile {
                    inFile = offlineFile
                } else {
                    let cwd = FilePath(FileManager.default.currentDirectoryPath)
                    inFile = cwd.appending("offline-transfer.json")
                }
            }

            guard let inFile else {
                noora.error(.alert(
                    "No offline transfer file path could be determined.",
                    takeaways: ["Set 'offlineFile' in config or pass --in-file."]
                ))
                throw ExitCode.validationFailure
            }

            try FileUtils.checkFileExists(inFile)

            var transfer = try OfflineTransfer.load(from: inFile)

            let count = transfer.files.count
            transfer.files = []
            transfer.history.append(OfflineTransferHistory(action: .clearFiles))

            try transfer.save(to: inFile)

            spacedPrint("\(.success("Cleared \(count) attached file(s)."))")
        }
    }
}
