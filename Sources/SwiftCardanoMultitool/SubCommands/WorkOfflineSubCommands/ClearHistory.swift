import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoChain


extension WorkOfflineMainCommand {
    struct ClearHistory: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "clear-history",
            abstract: "Clear history entries from the offline transfer file.",
            discussion: """
            Removes all history entries from the offline transfer file, leaving
            only a single 'history cleared' entry.
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

            let count = transfer.history.count
            transfer.history = [OfflineTransferHistory(action: .clearHistory)]

            try transfer.save(to: inFile)

            spacedPrint("\(.success("Cleared \(count) history entry/entries."))")
        }
    }
}
