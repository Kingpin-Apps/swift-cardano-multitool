import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoChain


extension WorkOfflineMainCommand {
    struct Attach: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "attach",
            abstract: "Embed a file into the offline transfer file.",
            discussion: """
            Base64-encodes a file and stores it inside the offline transfer JSON.
            Useful for carrying keys, scripts, or metadata across the
            online-offline boundary without needing multiple separate files.
            """
        )

        @Option(name: [.short, .long], help: "Path to the file to attach.")
        var file: FilePath

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
            try FileUtils.checkFileExists(file)

            let fileName = file.lastComponent?.string ?? file.string
            let fileSize = FileUtils.fileSize(file) ?? 0

            spacedPrint("Attaching \(.primary(fileName)) (\(fileSize) bytes) into the offline transfer file...")

            var transfer = try OfflineTransfer.load(from: inFile)

            let base64Data = try FileUtils.base64EncodedFile(file)

            let entry = OfflineTransferFileEntry(
                name: fileName,
                size: fileSize,
                base64: base64Data
            )

            transfer.files.append(entry)
            transfer.history.append(OfflineTransferHistory(action: .attach(fileName: fileName)))

            try transfer.save(to: inFile)

            spacedPrint("\(.success("'\(fileName)' has been embedded in the offline transfer file."))")
        }
    }
}
