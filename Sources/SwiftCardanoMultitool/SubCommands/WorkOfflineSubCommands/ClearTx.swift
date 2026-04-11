import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoChain


extension WorkOfflineMainCommand {
    struct ClearTx: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "clear-tx",
            abstract: "Remove all queued transactions from the offline transfer file.",
            discussion: """
            Clears the transactions list in the offline transfer file, allowing
            you to start fresh without creating a new file.
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

            let count = transfer.transactions.count
            transfer.transactions = []
            transfer.history.append(OfflineTransferHistory(action: .clearTransactions))

            try transfer.save(to: inFile)

            spacedPrint("\(.success("Cleared \(count) queued transaction(s). You can start over."))")
        }
    }
}
