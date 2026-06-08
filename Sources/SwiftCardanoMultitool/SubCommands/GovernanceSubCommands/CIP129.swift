import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoCIPs
import SwiftCardanoSigner

extension GovernanceMainCommand {

    struct CIP129Command: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "cip129",
            abstract: "Encode or decode CIP-129 / CIP-151 bech32 governance identifiers.",
            subcommands: [Encode.self, Decode.self]
        )

        struct Encode: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                commandName: "encode",
                abstract: "Encode a 28-byte key hash as a CIP-129 bech32 ID.",
                usage: """
                scm governance cip129 encode --prefix drep --key-hash a1b2c3...
                """
            )

            @Option(name: .long, help: "Bech32 prefix: drep, ccCold, ccHot, calidus.")
            var prefix: String? = nil

            @Option(name: .customLong("key-hash"), help: "28-byte Blake2b-224 key hash as hex.")
            var keyHash: String? = nil

            @Flag(name: .long, help: "Encode as a script-form ID (not valid for calidus).")
            var script: Bool = false

            mutating func wizard() async throws {
                prefix = noora.singleChoicePrompt(
                    title: "Prefix",
                    question: "Which CIP-129 prefix?",
                    options: Signer.CIP129.Prefix.allCases.map(\.rawValue),
                    description: "drep / ccCold / ccHot / calidus."
                )
                keyHash = noora.textPrompt(
                    title: "Key Hash",
                    prompt: "Enter the 28-byte (56-hex-char) Blake2b-224 hash:",
                    validationRules: [NonEmptyValidationRule(error: "Key hash cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                script = noora.yesOrNoChoicePrompt(
                    title: "Script Form",
                    question: "Encode as a script-form ID?",
                    defaultAnswer: false
                )
            }

            mutating func run() async throws {
                if prefix == nil || keyHash == nil {
                    try await wizard()
                }
                guard let prefixValue = Signer.CIP129.Prefix(rawValue: prefix!) else {
                    throw ValidationError("Unknown prefix '\(prefix!)'. Use one of: \(Signer.CIP129.Prefix.allCases.map(\.rawValue).joined(separator: ", ")).")
                }
                guard let bytes = Data(hexString: keyHash!), bytes.count == 28 else {
                    throw ValidationError("--key-hash must be 28 bytes (56 hex chars).")
                }
                let encoded = try Signer.CIP129.encode(keyHash: bytes, as: prefixValue, isScript: script)
                print(encoded)
            }
        }

        struct Decode: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                commandName: "decode",
                abstract: "Decode a CIP-129 / CIP-151 bech32 ID into its prefix, key hash, and script flag.",
                usage: """
                scm governance cip129 decode --id drep1ygx...
                """
            )

            @Option(name: .long, help: "Bech32 governance identifier (e.g. drep1…, cc_cold1…, cc_hot1…, calidus1…).")
            var id: String? = nil

            mutating func wizard() async throws {
                id = noora.textPrompt(
                    title: "Bech32 ID",
                    prompt: "Enter the bech32 governance ID:",
                    validationRules: [NonEmptyValidationRule(error: "ID cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            mutating func run() async throws {
                if id == nil {
                    try await wizard()
                }
                let (prefix, keyHash, isScript) = try Signer.CIP129.decode(id!)
                print(noora.format("Prefix:    \(.primary(prefix.rawValue))"))
                print(noora.format("Key Hash:  \(.primary(keyHash.toHex))"))
                print(noora.format("Script:    \(.primary(isScript ? "true" : "false"))"))
            }
        }
    }
}
