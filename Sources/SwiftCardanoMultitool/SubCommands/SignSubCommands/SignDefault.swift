import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoSigner
import SwiftNaCl

extension SignMainCommand {

    struct SignDefault: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "default",
            abstract: "Sign an arbitrary payload with an Ed25519 signing key (plain mode).",
            usage: """
            scm sign default --data "hello" --secret-key payment.skey
            scm sign default --data-hex 48656c6c6f --secret-key payment.skey --json-extended
            scm sign default --data-file message.txt --secret-key payment.skey --out-file sig.txt
            """
        )

        @Option(name: .long, help: "UTF-8 string payload to sign.")
        var data: String? = nil

        @Option(name: .customLong("data-hex"), help: "Hex-encoded payload to sign.")
        var dataHex: String? = nil

        @Option(name: .customLong("data-file"), help: "File whose contents will be signed.")
        var dataFile: FilePath? = nil

        @Option(name: [.customShort("s"), .customLong("secret-key")], help: "Signing key — path to a .skey file or raw hex.")
        var secretKey: String? = nil

        @Flag(name: .customLong("calidus"), help: "Treat the signing key as a Calidus key and also emit the CIP-151 calidus_id (bech32).")
        var calidus: Bool = false

        @OptionGroup var output: SignerOutputOptions

        mutating func wizard() async throws {
            let source = SignerUtils.promptDataSource(title: "Data to sign")
            switch source {
            case .text:
                data = noora.textPrompt(
                    title: "Data",
                    prompt: "Enter the text to sign:",
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
            secretKey = SignerUtils.promptSecretKeyPath()
        }

        mutating func run() async throws {
            if (data == nil && dataHex == nil && dataFile == nil) || secretKey == nil {
                try await wizard()
            }
            let payload = try SignerUtils.resolveData(text: data, hex: dataHex, file: dataFile)
            let key = try SignerUtils.resolveSecretKey(secretKey!)
            let result = try Signer.sign(payload: payload, signingKey: key)

            var extras: [(key: String, value: String)] = []
            if calidus {
                let pubKey = result.publicKey.prefix(32)
                let keyHash = try SwiftNaCl.Hash().blake2b(
                    data: Data(pubKey),
                    digestSize: 28,
                    encoder: SwiftNaCl.RawEncoder.self
                )
                let calidusId = try Signer.CIP129.encode(
                    keyHash: keyHash,
                    as: .calidus,
                    isScript: false
                )
                extras.append((key: "calidusId", value: calidusId))
            }

            let rendered = try SignerUtils.renderDefaultSign(
                result,
                payload: payload,
                signingKey: key,
                format: output.format,
                includeSecret: output.includeSecret,
                extras: extras
            )
            try await SignerUtils.emit(rendered, to: output.outFile)
        }
    }
}
