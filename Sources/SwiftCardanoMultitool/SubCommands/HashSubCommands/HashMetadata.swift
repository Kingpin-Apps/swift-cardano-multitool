import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoUtils

extension HashMainCommand {

    struct DRepMetadata: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "drep-metadata",
            abstract: "Calculate the hash of a DRep metadata file.",
            usage: """
            scm hash drep-metadata --drep-metadata-file myDRep.jsonld
            scm hash drep-metadata --drep-metadata-url https://example.com/drep.jsonld --expected-hash 1a2b…
            """,
            discussion: """
            Equivalent to 'cardano-cli governance drep metadata-hash'. Prints the blake2b-256
            hash of the file's exact bytes, for the DRep registration or update anchor.
            With --expected-hash the command exits non-zero when the hashes differ.
            """
        )

        @Option(name: [.customShort("f"), .customLong("drep-metadata-file")], help: "DRep metadata file to hash.")
        var metadataFile: FilePath? = nil

        @Option(name: [.customShort("u"), .customLong("drep-metadata-url")], help: "URL of the DRep metadata file to hash (HTTP(S) and IPFS).")
        var metadataUrl: String? = nil

        @Option(name: .customLong("expected-hash"), help: "Expected hash; fails when the computed hash differs.")
        var expectedHash: String? = nil

        @Option(name: .shortAndLong, help: "Optional output file. Default is to write to stdout.")
        var outFile: FilePath? = nil

        @Option(name: .shortAndLong, help: "Whether to use the cardano-cli or SwiftCardano to compute the hash.")
        var tool: Tool? = nil

        func validate() throws {
            try MetadataHashInput.validate(file: metadataFile, url: metadataUrl, expectedHash: expectedHash,
                                           fileFlag: "--drep-metadata-file", urlFlag: "--drep-metadata-url")
        }

        mutating func run() async throws {
            var input = MetadataHashInput(kind: .drep, file: metadataFile, url: metadataUrl, expectedHash: expectedHash, tool: tool)
            try await input.run(outFile: outFile)
        }
    }

    struct PoolMetadata: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "pool-metadata",
            abstract: "Calculate the hash of a stake pool metadata file.",
            usage: """
            scm hash pool-metadata --pool-metadata-file mypool.metadata.json
            scm hash pool-metadata --pool-metadata-url https://example.com/pool.json --expected-hash 1a2b…
            """,
            discussion: """
            Equivalent to 'cardano-cli stake-pool metadata-hash'. The metadata is checked
            first, as the ledger requires: at most 512 bytes, a JSON object with name (up to
            50 characters), description (up to 255), ticker (3-5) and homepage.
            With --expected-hash the command exits non-zero when the hashes differ.
            """,
            aliases: ["stake-pool-metadata"]
        )

        @Option(name: [.customShort("f"), .customLong("pool-metadata-file")], help: "Filepath of the pool metadata.")
        var metadataFile: FilePath? = nil

        @Option(name: [.customShort("u"), .customLong("pool-metadata-url")], help: "URL of the pool metadata file to hash (HTTP(S) and IPFS).")
        var metadataUrl: String? = nil

        @Option(name: .customLong("expected-hash"), help: "Expected hash; fails when the computed hash differs.")
        var expectedHash: String? = nil

        @Option(name: .shortAndLong, help: "Optional output file. Default is to write to stdout.")
        var outFile: FilePath? = nil

        @Option(name: .shortAndLong, help: "Whether to use the cardano-cli or SwiftCardano to compute the hash.")
        var tool: Tool? = nil

        func validate() throws {
            try MetadataHashInput.validate(file: metadataFile, url: metadataUrl, expectedHash: expectedHash,
                                           fileFlag: "--pool-metadata-file", urlFlag: "--pool-metadata-url")
        }

        mutating func run() async throws {
            var input = MetadataHashInput(kind: .pool, file: metadataFile, url: metadataUrl, expectedHash: expectedHash, tool: tool)
            try await input.run(outFile: outFile)
        }
    }
}

/// Shared handling for the DRep and stake pool metadata hash commands.
struct MetadataHashInput {
    enum Kind {
        case drep, pool

        var label: String { self == .drep ? "DRep" : "stake pool" }
        var title: String { self == .drep ? "DRep Metadata Hash" : "Pool Metadata Hash" }
        var fileFlag: String { self == .drep ? "--drep-metadata-file" : "--pool-metadata-file" }
        var urlFlag: String { self == .drep ? "--drep-metadata-url" : "--pool-metadata-url" }
    }

    let kind: Kind
    var file: FilePath?
    var url: String?
    var expectedHash: String?
    var tool: Tool?

    static func validate(file: FilePath?, url: String?, expectedHash: String?, fileFlag: String, urlFlag: String) throws {
        if file != nil && url != nil {
            throw ValidationError("Provide only one of \(fileFlag) or \(urlFlag).")
        }
        if let expectedHash, HashUtils.normalizedHash32(expectedHash) == nil {
            throw ValidationError("--expected-hash must be a 32-byte hash (64 hex characters).")
        }
    }

    mutating func wizard() async throws {
        let options = ["Metadata file", "URL"]
        let choice = noora.singleChoicePrompt(
            title: "Metadata",
            question: "Where is the \(kind.label) metadata?",
            options: options
        )
        if choice == options[0] {
            file = try promptFilePath(
                title: "Metadata File",
                question: "Select the \(kind.label) metadata file:",
                matching: { [".json", ".jsonld"].contains(where: $0.hasSuffix) }
            )
        } else {
            url = noora.textPrompt(
                title: "Metadata URL",
                prompt: "Enter the URL of the \(kind.label) metadata:",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "The URL cannot be empty.")]
            ).trimmed
        }
        let expected = noora.textPrompt(
            title: "Expected Hash",
            prompt: "Enter the expected hash to compare against (leave empty to skip):",
            collapseOnAnswer: true,
            validationRules: [HashOrEmptyValidationRule(error: "Enter a 64-character hex hash or leave it empty.")]
        ).trimmed
        expectedHash = expected.isEmpty ? nil : expected
        if tool == nil { tool = try await getToolToUse() }
    }

    mutating func run(outFile: FilePath?) async throws {
        if file == nil && url == nil {
            guard isInteractiveSession() else {
                noora.error(.alert(
                    "Missing \(kind.label) metadata.",
                    takeaways: ["Use \(kind.fileFlag) or \(kind.urlFlag)."]
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
                    let cli = try await HashUtils.cardanoCLI()
                    let arguments = file.map { [kind.fileFlag, FileUtils.absolutePath($0).string] } ?? [kind.urlFlag, url ?? ""]
                    let output: String
                    switch kind {
                        case .drep: output = try await cli.governance.drepMetadataHash(arguments: arguments)
                        case .pool: output = try await cli.stakePool.metadataHash(arguments: arguments)
                    }
                    hash = output.trimmed
                case .swiftCardano:
                    let data = try await loadData()
                    if kind == .pool {
                        try HashUtils.validatePoolMetadata(data)
                    }
                    hash = try HashUtils.anchorDataHash(data)
            }
        } catch {
            noora.error(.alert("Could not hash the \(kind.label) metadata.", takeaways: ["\(error.localizedDescription)"]))
            throw ExitCode.failure
        }

        var inputs: [(String, String)] = []
        if let file {
            inputs.append(("Metadata file", file.string))
            if let size = (try? FileManager.default.attributesOfItem(atPath: FileUtils.absolutePath(file).string))?[.size] as? Int {
                inputs.append(("Size", HashUtils.byteCount(size)))
            }
        } else if let url {
            inputs.append(("Metadata URL", url))
        }
        if kind == .pool, let data = file.flatMap({ FileManager.default.contents(atPath: FileUtils.absolutePath($0).string) }),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let name = json["name"] as? String, let ticker = json["ticker"] as? String {
                inputs.append(("Pool", "\(name) (\(ticker))"))
            }
        }
        if let expectedHash {
            inputs.append(("Expected hash", expectedHash.lowercased()))
        }
        try HashUtils.emit(HashReport(
            title: kind.title,
            summary: "Hashing \(kind == .drep ? "DRep" : "stake pool") metadata",
            inputs: inputs,
            method: kind == .pool
                ? "Checked (≤ 512 bytes; name, description, ticker, homepage), then blake2b-256 of the exact bytes → 32-byte metadata hash"
                : "blake2b-256 of the exact bytes → 32-byte metadata hash",
            hash: hash, tool: resolvedTool, outFile: outFile, expectedHash: expectedHash
        ))
    }

    private func loadData() async throws -> Data {
        if let file {
            let path = FileUtils.absolutePath(file)
            guard let data = FileManager.default.contents(atPath: path.string) else {
                throw SwiftCardanoMultitoolError.fileNotFound(path)
            }
            return data
        }
        guard let url else {
            throw SwiftCardanoMultitoolError.valueError("No \(kind.label) metadata provided.")
        }
        guard isatty(FileHandle.standardOutput.fileDescriptor) != 0 else {
            return try await HashUtils.downloadMetadata(url)
        }
        return try await noora.progressStep(
            message: "Downloading \(kind.label) metadata...",
            successMessage: "Metadata downloaded.",
            errorMessage: "Failed to download the metadata.",
            showSpinner: true
        ) { _ in
            try await HashUtils.downloadMetadata(url)
        }
    }
}
