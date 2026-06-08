import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoSigner

extension VerifyMainCommand {

    struct VerifyDefault: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "default",
            abstract: "Verify a detached Ed25519 signature against a payload.",
            usage: """
            scm verify default --data "hello" --public-key payment.vkey --signature 8a5fd6…
            """
        )

        @Option(name: .long, help: "UTF-8 string payload to verify.")
        var data: String? = nil

        @Option(name: .customLong("data-hex"), help: "Hex-encoded payload to verify.")
        var dataHex: String? = nil

        @Option(name: .customLong("data-file"), help: "File whose contents were signed.")
        var dataFile: FilePath? = nil

        @Option(name: [.customShort("p"), .customLong("public-key")], help: "Verification key — path to a .vkey file or raw hex.")
        var publicKey: String? = nil

        @Option(name: .long, help: "64-byte Ed25519 signature as hex.")
        var signature: String? = nil

        @OptionGroup var output: SignerOutputOptions

        mutating func wizard() async throws {
            let source = SignerUtils.promptDataSource(title: "Data to verify")
            switch source {
            case .text:
                data = noora.textPrompt(
                    title: "Data",
                    prompt: "Enter the text that was signed:",
                    validationRules: [NonEmptyValidationRule(error: "Data cannot be empty.")]
                )
            case .hex:
                dataHex = noora.textPrompt(
                    title: "Hex Data",
                    prompt: "Enter the hex-encoded payload:",
                    validationRules: [NonEmptyValidationRule(error: "Hex data cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines)
            case .file:
                let path = noora.textPrompt(
                    title: "Data File",
                    prompt: "Enter the path to the file:",
                    validationRules: [NonEmptyValidationRule(error: "Path cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                dataFile = FilePath(path)
            }
            publicKey = SignerUtils.promptPublicKeyPath()
            signature = noora.textPrompt(
                title: "Signature",
                prompt: "Enter the hex signature:",
                validationRules: [NonEmptyValidationRule(error: "Signature cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        mutating func run() async throws {
            if (data == nil && dataHex == nil && dataFile == nil) || publicKey == nil || signature == nil {
                try await wizard()
            }
            let payload = try SignerUtils.resolveData(text: data, hex: dataHex, file: dataFile)
            let vkey = try SignerUtils.resolvePublicKey(publicKey!)
            let sig = try SignerUtils.resolveSignature(signature!)
            let valid = try Signer.verify(
                payload: payload,
                signature: sig,
                verificationKey: vkey
            )
            let rendered = try SignerUtils.renderDefaultVerify(
                valid: valid,
                payload: payload,
                signature: sig,
                verificationKey: vkey,
                format: output.format
            )
            try await SignerUtils.emit(rendered, to: output.outFile)
            if !valid {
                throw ExitCode.failure
            }
        }
    }
}
