import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoChain


extension WorkOfflineMainCommand {
    struct Extract: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "extract",
            abstract: "Extract embedded files from the offline transfer file.",
            discussion: """
            Decodes all files stored inside the offline transfer JSON and writes
            them to the output directory (defaults to the current directory).
            """
        )

        @Option(name: [.short, .long], help: "Path to the offline transfer file.")
        var inFile: FilePath?

        @Option(name: [.short, .long], help: "Directory to extract files into (defaults to current directory).")
        var outDir: FilePath?

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

            let outputDir = outDir ?? FilePath(FileManager.default.currentDirectoryPath)

            var transfer = try OfflineTransfer.load(from: inFile)

            guard !transfer.files.isEmpty else {
                noora.warning(.alert(
                    "No attached files found in the offline transfer file.",
                    takeaway: "Use 'scm work-offline attach' to embed files first."
                ))
                return
            }

            spacedPrint("Extracting \(transfer.files.count) file(s) to: \(.path(try .init(validating: outputDir.string)))")

            var extractedCount = 0
            for fileEntry in transfer.files {
                guard let name = fileEntry.name, let base64Data = fileEntry.base64 else {
                    noora.warning(.alert("Skipping unnamed or empty file entry."))
                    continue
                }

                guard let decodedData = Data(base64Encoded: base64Data) else {
                    noora.warning(.alert("Could not decode base64 data for '\(name)'. Skipping."))
                    continue
                }

                let destPath = outputDir.appending(name)
                try decodedData.write(to: URL(fileURLWithPath: destPath.string), options: .atomic)

                transfer.history.append(OfflineTransferHistory(action: .extractedFile(fileName: name)))
                extractedCount += 1

                formatPrint("  \(.success("✓")) \(.primary(name))")
            }

            try transfer.save(to: inFile)

            spacedPrint("\(.success("\(extractedCount) file(s) extracted successfully."))")
        }
    }
}
