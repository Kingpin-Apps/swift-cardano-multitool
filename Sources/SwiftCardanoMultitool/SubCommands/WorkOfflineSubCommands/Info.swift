import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoChain


extension WorkOfflineMainCommand {
    struct Info: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "info",
            abstract: "Display the contents of the offline transfer file.",
            discussion: """
            Displays a summary of what is stored in the offline transfer file,
            including protocol parameters, history, addresses with balances,
            attached files, and queued transactions.
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

            do {
                try FileUtils.checkFileExists(inFile)
            } catch {
                noora.error(.alert(
                    "Offline transfer file not found at: \(.path(try .init(validating: inFile.string)))",
                    takeaways: ["Run 'scm work-offline new' to create a fresh file."]
                ))
                throw ExitCode.validationFailure
            }

            let transfer = try OfflineTransfer.load(from: inFile)

            spacedPrint("Checking contents of: \(.path(try .init(validating: inFile.string)))\n")

            // Protocol
            if transfer.protocol.protocolParameters != nil {
                formatPrint("Protocol-Parameters: \(.success("present"))")
            } else {
                formatPrint("Protocol-Parameters: \(.danger("missing"))")
            }

            if let era = transfer.protocol.era {
                spacedPrint("Era: \(.primary("\(era)"))")
            } else {
                spacedPrint("Era: \(.danger("missing"))")
            }

            // Versions
            if let onlineVersion = transfer.general.onlineVersion {
                spacedPrint("Online Version: \(.primary(onlineVersion))")
            }
            if let offlineVersion = transfer.general.offlineVersion {
                spacedPrint("Offline Version: \(.primary(offlineVersion))")
            }

            // History
            let historyCount = transfer.history.count
            formatPrint("History Entries: \(.primary("\(historyCount)"))")
            if let last = transfer.history.last {
                let action = last.action?.description ?? "unknown"
                let dateStr = last.date.map { ISO8601DateFormatter().string(from: $0) } ?? "unknown"
                spacedPrint("  Last Action: \(.success(action)) \(.muted("(\(dateStr))"))")
            } else {
                print()
            }

            // Addresses
            let addrCount = transfer.addresses.count
            formatPrint("Address Entries: \(.primary("\(addrCount)"))")
            for (idx, addr) in transfer.addresses.enumerated() {
                let name = addr.name ?? "Unnamed"
                let total = addr.totalAmount ?? 0
                let adaStr = lovelaceToAdaString(UInt64(max(0, total)))
                let typeStr = addr.type.map { " [\($0.description)]" } ?? ""
                if addr.used {
                    spacedPrint("  [\(idx + 1)] \(.primary(name))\(typeStr) \(.muted(adaStr)) \(.danger("(used)"))")
                } else {
                    spacedPrint("  [\(idx + 1)] \(.primary(name))\(typeStr) \(.muted(adaStr))")
                }
            }

            // Files
            let filesCount = transfer.files.count
            formatPrint("Files Attached: \(.primary("\(filesCount)"))")
            for (idx, file) in transfer.files.enumerated() {
                let name = file.name ?? "unknown"
                let size = file.size.map { "\($0) bytes" } ?? "unknown size"
                let date = file.date ?? "unknown date"
                spacedPrint("  [\(idx + 1)] \(.primary(name)) \(.muted("(\(size), \(date))"))")
            }

            // Transactions
            let txCount = transfer.transactions.count
            formatPrint("Transactions Queued: \(.primary("\(txCount)"))")
            for (idx, tx) in transfer.transactions.enumerated() {
                let era = tx.era.map { "\($0)" } ?? "unknown era"
                let from = tx.fromName ?? tx.fromAddress ?? "unknown"
                let to = tx.toName ?? tx.toAddress ?? "unknown"
                let date = tx.date ?? "unknown"
                spacedPrint("  [\(idx + 1)] [\(era)] from \(.primary(from)) to \(.primary(to)) \(.muted("(\(date))"))")
            }
        }
    }
}
