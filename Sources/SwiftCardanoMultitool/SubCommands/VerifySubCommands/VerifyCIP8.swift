import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoCIPs
import SwiftCardanoSigner

extension VerifyMainCommand {

    struct VerifyCIP8: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "cip8",
            abstract: "Verify a CIP-8 COSE_Sign1 signed message.",
            usage: """
            scm verify cip8 --cose-sign1 84582a… --cose-key a401…
            """
        )

        @Option(name: .customLong("cose-sign1"), help: "Hex-encoded COSE_Sign1 message.")
        var coseSign1: String? = nil

        @Option(name: .customLong("cose-key"), help: "Hex-encoded COSE_Key (required when not embedded).")
        var coseKey: String? = nil

        @OptionGroup var output: SignerOutputOptions

        mutating func wizard() async throws {
            coseSign1 = noora.textPrompt(
                title: "COSE_Sign1",
                prompt: "Enter the hex-encoded COSE_Sign1:",
                validationRules: [NonEmptyValidationRule(error: "COSE_Sign1 cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            let key = noora.textPrompt(
                title: "COSE_Key",
                prompt: "Enter the hex-encoded COSE_Key (or leave blank if embedded):",
                collapseOnAnswer: true
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            coseKey = key.isEmpty ? nil : key
        }

        mutating func run() async throws {
            if coseSign1 == nil {
                try await wizard()
            }
            let signed = SignedMessage(signature: coseSign1!, key: coseKey)
            let result = try Signer.CIP8.verify(signed)
            let rendered = try SignerUtils.renderVerificationResult(
                result,
                workMode: "verify-cip8",
                format: output.format
            )
            try await SignerUtils.emit(rendered, to: output.outFile)
            if !result.verified {
                throw ExitCode.failure
            }
        }
    }
}
