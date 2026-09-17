import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoUtils

extension HashMainCommand {

    struct Script: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "script",
            abstract: "Compute the hash of a script.",
            usage: """
            scm hash script --script-file myPolicy.policy.script
            scm hash script --script-file validator.plutus
            """,
            discussion: """
            Equivalent to 'cardano-cli hash script' and 'cardano-cli transaction policyid'.
            Accepts a native script JSON file or a Plutus script text envelope (PlutusScriptV1,
            V2 or V3). The script hash is also the policy ID of a minting policy.
            """,
            aliases: ["policy-id"]
        )

        @Option(name: [.customShort("s"), .customLong("script-file")], help: "Filepath of the script.")
        var scriptFile: FilePath? = nil

        @Option(name: .shortAndLong, help: "Optional output file. Default is to write to stdout.")
        var outFile: FilePath? = nil

        @Option(name: .shortAndLong, help: "Whether to use the cardano-cli or SwiftCardano to compute the hash.")
        var tool: Tool? = nil

        mutating func wizard() async throws {
            scriptFile = try promptFilePath(
                title: "Script File",
                question: "Select the script file:",
                matching: { [".script", ".plutus", ".json"].contains(where: $0.hasSuffix) }
            )
            tool = try await getToolToUse()
        }

        mutating func run() async throws {
            if scriptFile == nil {
                guard isInteractiveSession() else {
                    noora.error(.alert("Missing script file.", takeaways: ["Use --script-file."]))
                    throw ExitCode.validationFailure
                }
                try await wizard()
            }
            guard let scriptFile else { throw ExitCode.validationFailure }
            let path = FileUtils.absolutePath(scriptFile)

            let result: (kind: String, hash: String)
            do {
                // Parse first so both tools reject unsupported files the same way.
                result = try HashUtils.scriptHash(scriptFile: path)
            } catch {
                noora.error(.alert("Could not hash the script.", takeaways: ["\(error.localizedDescription)"]))
                throw ExitCode.failure
            }

            let hash: String
            let resolvedTool = try await resolveTool(tool)
            switch resolvedTool {
                case .cardanoCLI:
                    let config = try await MultitoolConfig.load(quiet: isatty(FileHandle.standardOutput.fileDescriptor) == 0)
                    let cli = try await CardanoCLI(configuration: config.toSwiftCardanoUtilsConfig())
                    hash = try await cli.hash.script(arguments: ["--script-file", path.string])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                case .swiftCardano:
                    hash = result.hash
            }

            var inputs: [(String, String)] = [("Script file", scriptFile.string), ("Script type", result.kind)]
            if let size = (try? FileManager.default.attributesOfItem(atPath: path.string))?[.size] as? Int {
                inputs.append(("File size", HashUtils.byteCount(size)))
            }
            try HashUtils.emit(HashReport(
                title: "Script Hash",
                summary: "Hashing a \(result.kind.lowercased())",
                inputs: inputs,
                method: result.kind.hasPrefix("Native")
                    ? "blake2b-224 of 0x00 + the script's CBOR → 28-byte script hash (also the policy ID)"
                    : "blake2b-224 of the language tag + the script bytes → 28-byte script hash (also the policy ID)",
                hash: hash, tool: resolvedTool, outFile: outFile
            ))
        }
    }

    struct GenesisFile: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "genesis-file",
            abstract: "Compute the hash of a genesis file.",
            usage: """
            scm hash genesis-file --genesis shelley-genesis.json
            """,
            discussion: """
            Equivalent to 'cardano-cli hash genesis-file'. Prints the blake2b-256 hash of
            the file's exact bytes, as used for the *GenesisHash entries of the node configuration.
            """
        )

        @Option(name: [.customShort("g"), .long], help: "The genesis file.")
        var genesis: FilePath? = nil

        @Option(name: .shortAndLong, help: "Optional output file. Default is to write to stdout.")
        var outFile: FilePath? = nil

        @Option(name: .shortAndLong, help: "Whether to use the cardano-cli or SwiftCardano to compute the hash.")
        var tool: Tool? = nil

        mutating func wizard() async throws {
            genesis = try promptFilePath(
                title: "Genesis File",
                question: "Select the genesis file:",
                matching: { $0.contains("genesis") && $0.hasSuffix(".json") }
            )
            tool = try await getToolToUse()
        }

        mutating func run() async throws {
            if genesis == nil {
                guard isInteractiveSession() else {
                    noora.error(.alert("Missing genesis file.", takeaways: ["Use --genesis."]))
                    throw ExitCode.validationFailure
                }
                try await wizard()
            }
            guard let genesis else { throw ExitCode.validationFailure }
            let path = FileUtils.absolutePath(genesis)

            let hash: String
            let resolvedTool = try await resolveTool(tool)
            do {
                switch resolvedTool {
                    case .cardanoCLI:
                        let config = try await MultitoolConfig.load(quiet: isatty(FileHandle.standardOutput.fileDescriptor) == 0)
                        let cli = try await CardanoCLI(configuration: config.toSwiftCardanoUtilsConfig())
                        hash = try await cli.hash.genesisFile(arguments: ["--genesis", path.string])
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    case .swiftCardano:
                        hash = try HashUtils.genesisFileHash(path)
                }
            } catch {
                noora.error(.alert("Could not hash the genesis file.", takeaways: ["\(error.localizedDescription)"]))
                throw ExitCode.failure
            }

            var inputs: [(String, String)] = [("Genesis file", genesis.string)]
            if let size = (try? FileManager.default.attributesOfItem(atPath: path.string))?[.size] as? Int {
                inputs.append(("Size", HashUtils.byteCount(size)))
            }
            try HashUtils.emit(HashReport(
                title: "Genesis File Hash",
                summary: "Hashing a genesis file",
                inputs: inputs,
                method: "blake2b-256 of the exact file bytes → 32-byte genesis hash",
                hash: hash, tool: resolvedTool, outFile: outFile
            ))
        }
    }
}
