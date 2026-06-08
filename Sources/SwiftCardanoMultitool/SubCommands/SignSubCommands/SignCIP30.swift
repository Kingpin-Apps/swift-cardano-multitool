import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoSigner

extension SignMainCommand {

    struct SignCIP30: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "cip30",
            abstract: "Produce a CIP-30 signData response (CIP-8 with attached COSE_Key).",
            usage: """
            scm sign cip30 --data "hello" --secret-key wallet.skey
            scm sign cip30 --data-hex 7b22... --secret-key stake.skey --testnet --json-extended
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

        @Flag(name: .long, help: "Use testnet network ID when deriving the signing address.")
        var testnet: Bool = false

        @OptionGroup var output: SignerOutputOptions

        mutating func wizard() async throws {
            let source = SignerUtils.promptDataSource(title: "CIP-30 data to sign")
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
            testnet = noora.yesOrNoChoicePrompt(
                title: "Network",
                question: "Use testnet network ID?",
                defaultAnswer: false
            )
        }

        mutating func run() async throws {
            if (data == nil && dataHex == nil && dataFile == nil) || secretKey == nil {
                try await wizard()
            }
            let payload = try SignerUtils.resolveData(text: data, hex: dataHex, file: dataFile)
            let key = try SignerUtils.resolveSecretKey(secretKey!)
            let network: Network = testnet ? .preprod : .mainnet
            let signed = try Signer.CIP30.signData(
                payload: payload,
                signingKey: key,
                network: network
            )
            let rendered = try SignerUtils.renderSignedMessage(
                signed,
                workMode: "sign-cip30",
                payload: payload,
                format: output.format
            )
            try await SignerUtils.emit(rendered, to: output.outFile)
        }
    }
}
