import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoSigner

extension GovernanceMainCommand {

    struct Canonize: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "canonize",
            abstract: "Compute the URDNA2015 canonical form and blake2b-256 hash of a CIP-100 JSON-LD document.",
            usage: """
            scm governance canonize --data-file proposal.jsonld
            scm governance canonize --data-file proposal.jsonld --out-canonized proposal.nq --json-extended
            """
        )

        @Option(name: .long, help: "UTF-8 JSON-LD document.")
        var data: String? = nil

        @Option(name: .customLong("data-file"), help: "Path to the JSON-LD document.")
        var dataFile: FilePath? = nil

        @Option(name: .customLong("out-canonized"), help: "Write the canonical N-Quads to this file.")
        var outCanonized: FilePath? = nil

        @OptionGroup var output: SignerOutputOptions

        mutating func wizard() async throws {
            dataFile = try filePathPrompt(
                title: "JSON-LD Document",
                question: "Enter the path to the JSON-LD document:",
                fileMatches: { $0.hasSuffix(".jsonld") || $0.hasSuffix(".json") }
            )
        }

        mutating func run() async throws {
            if data == nil && dataFile == nil && isInteractiveSession() {
                try await wizard()
            }
            let document = try SignerUtils.resolveData(text: data, hex: nil, file: dataFile)
            let hash = try await Signer.CIP100.canonicalBodyHash(of: document)

            if let outCanonized = outCanonized {
                noora.warning("The Swift backend currently exposes only the canonical body hash; the raw N-Quads cannot be written to \(outCanonized.string) until swift-cardano-cips surfaces them.")
            }

            let rendered: String
            switch output.format {
            case .plain:
                rendered = hash.toHex
            case .json:
                rendered = try SignerUtils.jsonString(["canonicalBodyHash": hash.toHex])
            case .jsonExtended:
                rendered = try SignerUtils.jsonString([
                    "workMode": "canonize-cip100",
                    "canonicalBodyHash": hash.toHex,
                ])
            }
            try await SignerUtils.emit(rendered, to: output.outFile)
        }
    }
}
