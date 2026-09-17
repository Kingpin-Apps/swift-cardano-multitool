import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoUtils

extension HashMainCommand {

    struct AnchorData: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "anchor-data",
            abstract: "Compute the hash of some anchor data.",
            usage: """
            scm hash anchor-data --file-text proposal.jsonld
            scm hash anchor-data --url https://example.com/drep.jsonld --expected-hash 1a2b…
            scm hash anchor-data --text "Hello"
            """,
            discussion: """
            Equivalent to 'cardano-cli hash anchor-data'. Computes the blake2b-256 hash
            passed to --anchor-hash / --metadata-hash arguments. ipfs:// URLs are fetched
            through the gateway in IPFS_GATEWAY_URI (default https://ipfs.io/).
            With --expected-hash the command exits non-zero when the hashes differ.
            """
        )

        @Option(name: .long, help: "Text to hash as UTF-8.")
        var text: String? = nil

        @Option(name: .customLong("file-binary"), help: "Binary file to hash.")
        var fileBinary: FilePath? = nil

        @Option(name: .customLong("file-text"), help: "Text file to hash.")
        var fileText: FilePath? = nil

        @Option(name: .long, help: "A URL to the file to hash (HTTP(S) and IPFS only).")
        var url: String? = nil

        @Option(name: .customLong("expected-hash"), help: "Expected hash for the anchor data; fails when the computed hash differs.")
        var expectedHash: String? = nil

        @Option(name: .shortAndLong, help: "Optional output file. Default is to write to stdout.")
        var outFile: FilePath? = nil

        @Option(name: .shortAndLong, help: "Whether to use the cardano-cli or SwiftCardano to compute the hash.")
        var tool: Tool? = nil

        enum Source: String, CaseIterable, AlignedChoiceDescribable {
            case textFile
            case binaryFile
            case url
            case text

            var name: String {
                switch self {
                    case .textFile: return "Text file"
                    case .binaryFile: return "Binary file"
                    case .url: return "URL"
                    case .text: return "Text"
                }
            }

            var details: String {
                switch self {
                    case .textFile: return "A UTF-8 file such as a CIP-100 .jsonld document."
                    case .binaryFile: return "Any file, hashed byte for byte."
                    case .url: return "Download the anchor data from an HTTP(S) or ipfs:// URL."
                    case .text: return "Text entered here, hashed as UTF-8."
                }
            }
        }

        func validate() throws {
            let sources = [text != nil, fileBinary != nil, fileText != nil, url != nil].filter { $0 }.count
            if sources > 1 {
                throw ValidationError("Provide only one of --text, --file-binary, --file-text or --url.")
            }
            if let expectedHash, HashUtils.normalizedHash32(expectedHash) == nil {
                throw ValidationError("--expected-hash must be a 32-byte hash (64 hex characters).")
            }
        }

        mutating func wizard() async throws {
            let source: Source = noora.singleChoicePrompt(
                title: "Anchor Data",
                question: "What do you want to hash?",
                description: "Anchor data is hashed with blake2b-256."
            )
            switch source {
                case .textFile:
                    fileText = try promptFilePath(
                        title: "Text File",
                        question: "Select the file to hash:",
                        matching: { [".json", ".jsonld", ".txt", ".md"].contains(where: $0.hasSuffix) }
                    )
                case .binaryFile:
                    fileBinary = try promptFilePath(
                        title: "Binary File",
                        question: "Select the file to hash:",
                        matching: { !$0.hasPrefix(".") }
                    )
                case .url:
                    url = noora.textPrompt(
                        title: "URL",
                        prompt: "Enter the URL of the anchor data:",
                        collapseOnAnswer: true,
                        validationRules: [NonEmptyValidationRule(error: "The URL cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                case .text:
                    text = noora.textPrompt(
                        title: "Text",
                        prompt: "Enter the text to hash:",
                        collapseOnAnswer: true,
                        validationRules: [NonEmptyValidationRule(error: "The text cannot be empty.")]
                    )
            }

            let expected = noora.textPrompt(
                title: "Expected Hash",
                prompt: "Enter the expected hash to compare against (leave empty to skip):",
                collapseOnAnswer: true,
                validationRules: [HashOrEmptyValidationRule(error: "Enter a 64-character hex hash or leave it empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            expectedHash = expected.isEmpty ? nil : expected

            if tool == nil { tool = try await getToolToUse() }
        }

        mutating func run() async throws {
            if text == nil && fileBinary == nil && fileText == nil && url == nil {
                guard isInteractiveSession() else {
                    noora.error(.alert(
                        "Missing anchor data.",
                        takeaways: ["Use one of --text, --file-binary, --file-text or --url."]
                    ))
                    throw ExitCode.validationFailure
                }
                try await wizard()
            }

            let resolvedTool = try await resolveTool(tool)
            let hash: String
            do {
                switch resolvedTool {
                    case .cardanoCLI:
                        hash = try await hashWithCardanoCLI()
                    case .swiftCardano:
                        hash = try HashUtils.anchorDataHash(try await loadData())
                }
            } catch {
                noora.error(.alert("Could not hash the anchor data.", takeaways: ["\(error.localizedDescription)"]))
                throw ExitCode.failure
            }

            try HashUtils.emit(HashReport(
                title: "Anchor Data Hash",
                summary: "Hashing governance anchor data",
                inputs: inputDetails(),
                method: "blake2b-256 of the exact bytes → 32-byte anchor data hash",
                hash: hash, tool: resolvedTool, outFile: outFile, expectedHash: expectedHash
            ))
        }

        private func inputDetails() -> [(String, String)] {
            var details: [(String, String)] = []
            if let text {
                details.append(("Text", text.count > 60 ? String(text.prefix(57)) + "…" : text))
                details.append(("Size", HashUtils.byteCount(Data(text.utf8).count)))
            } else if let path = fileText ?? fileBinary {
                details.append((fileText != nil ? "Text file" : "Binary file", path.string))
                if let size = (try? FileManager.default.attributesOfItem(atPath: FileUtils.absolutePath(path).string))?[.size] as? Int {
                    details.append(("Size", HashUtils.byteCount(size)))
                }
            } else if let url {
                details.append(("URL", url))
            }
            if let expectedHash {
                details.append(("Expected hash", expectedHash.lowercased()))
            }
            return details
        }

        private func loadData() async throws -> Data {
            if let text {
                return Data(text.utf8)
            }
            if let path = fileText ?? fileBinary {
                let absolute = FileUtils.absolutePath(path)
                guard let data = FileManager.default.contents(atPath: absolute.string) else {
                    throw SwiftCardanoMultitoolError.fileNotFound(absolute)
                }
                if fileText != nil, String(data: data, encoding: .utf8) == nil {
                    throw SwiftCardanoMultitoolError.valueError("\(path.string) is not valid UTF-8 text. Use --file-binary instead.")
                }
                return data
            }
            if let url {
                // Keep piped output to just the hash.
                guard isatty(FileHandle.standardOutput.fileDescriptor) != 0 else {
                    return try await HashUtils.downloadAnchorData(url)
                }
                return try await noora.progressStep(
                    message: "Downloading anchor data...",
                    successMessage: "Anchor data downloaded.",
                    errorMessage: "Failed to download the anchor data.",
                    showSpinner: true
                ) { _ in
                    try await HashUtils.downloadAnchorData(url)
                }
            }
            throw SwiftCardanoMultitoolError.valueError("No anchor data provided.")
        }

        private func hashWithCardanoCLI() async throws -> String {
            let config = try await MultitoolConfig.load(quiet: isatty(FileHandle.standardOutput.fileDescriptor) == 0)
            let cli = try await CardanoCLI(configuration: config.toSwiftCardanoUtilsConfig())
            let arguments: [String]
            if let text {
                arguments = ["--text", text]
            } else if let fileText {
                arguments = ["--file-text", FileUtils.absolutePath(fileText).string]
            } else if let fileBinary {
                arguments = ["--file-binary", FileUtils.absolutePath(fileBinary).string]
            } else if let url {
                arguments = ["--url", url]
            } else {
                throw SwiftCardanoMultitoolError.valueError("No anchor data provided.")
            }
            // The expected hash is compared here rather than by cardano-cli so both tools report it the same way.
            return try await cli.hash.anchorData(arguments: arguments)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
