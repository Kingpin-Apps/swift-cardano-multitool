import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoSigner

extension VerifyMainCommand {

    struct VerifyCIP100: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "cip100",
            abstract: "Verify every author witness signature in a CIP-100 governance metadata document.",
            usage: """
            scm verify cip100 --data-file proposal-signed.jsonld --json-extended
            """
        )

        @Option(name: .long, help: "UTF-8 JSON-LD document to verify.")
        var data: String? = nil

        @Option(name: .customLong("data-file"), help: "Path to the signed JSON-LD document.")
        var dataFile: FilePath? = nil

        @OptionGroup var output: SignerOutputOptions

        mutating func wizard() async throws {
            let path = noora.textPrompt(
                title: "JSON-LD Document",
                prompt: "Enter the path to the signed JSON-LD document:",
                validationRules: [NonEmptyValidationRule(error: "Path cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            dataFile = FilePath(path)
        }

        mutating func run() async throws {
            if data == nil && dataFile == nil {
                try await wizard()
            }
            let document = try SignerUtils.resolveData(text: data, hex: nil, file: dataFile)
            let result = try await Signer.CIP100.verifyMetadata(document)
            let rendered: String
            switch output.format {
            case .plain:
                rendered = result.allValid ? "true" : "false"
            case .json:
                rendered = try SignerUtils.jsonString([
                    "result": result.allValid ? "true" : "false",
                    "authorCount": String(result.authorResults.count),
                ])
            case .jsonExtended:
                let authors: [[String: String]] = result.authorResults.map { ar in
                    [
                        "name": ar.name ?? "",
                        "publicKey": ar.publicKey.toHex,
                        "valid": ar.valid ? "true" : "false",
                    ]
                }
                rendered = try SignerUtils.jsonString([
                    "workMode": "verify-cip100",
                    "result": result.allValid ? "true" : "false",
                    "canonicalBodyHash": result.canonicalBodyHash.toHex,
                    "authors": authors,
                ])
            }
            try await SignerUtils.emit(rendered, to: output.outFile)
            if !result.allValid {
                throw ExitCode.failure
            }
        }
    }
}
