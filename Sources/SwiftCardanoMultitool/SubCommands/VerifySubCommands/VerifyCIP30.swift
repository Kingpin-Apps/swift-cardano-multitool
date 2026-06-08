import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoCIPs
import SwiftCardanoSigner

extension VerifyMainCommand {

    struct VerifyCIP30: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "cip30",
            abstract: "Verify a CIP-30 signData response.",
            usage: """
            scm verify cip30 --cose-sign1 84582a… --cose-key a401…
            """
        )

        @Option(name: .customLong("cose-sign1"), help: "Hex-encoded COSE_Sign1 message.")
        var coseSign1: String? = nil

        @Option(name: .customLong("cose-key"), help: "Hex-encoded COSE_Key returned alongside the signature.")
        var coseKey: String? = nil

        @OptionGroup var output: SignerOutputOptions

        mutating func wizard() async throws {
            coseSign1 = noora.textPrompt(
                title: "COSE_Sign1",
                prompt: "Enter the hex-encoded COSE_Sign1:",
                validationRules: [NonEmptyValidationRule(error: "COSE_Sign1 cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            coseKey = noora.textPrompt(
                title: "COSE_Key",
                prompt: "Enter the hex-encoded COSE_Key:",
                validationRules: [NonEmptyValidationRule(error: "COSE_Key cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        mutating func run() async throws {
            if coseSign1 == nil || coseKey == nil {
                try await wizard()
            }
            let signed = SignedMessage(signature: coseSign1!, key: coseKey)
            let result = try Signer.CIP30.verify(signed)
            let rendered = try SignerUtils.renderVerificationResult(
                result,
                workMode: "verify-cip30",
                format: output.format
            )
            try await SignerUtils.emit(rendered, to: output.outFile)
            if !result.verified {
                throw ExitCode.failure
            }
        }
    }
}
