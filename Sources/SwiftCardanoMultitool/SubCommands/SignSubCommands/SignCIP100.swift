import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoSigner

extension SignMainCommand {

    struct SignCIP100: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "cip100",
            abstract: "Sign a CIP-100 governance metadata JSON-LD document and append an author witness.",
            usage: """
            scm sign cip100 --data-file proposal.jsonld --secret-key author.skey --author-name "Hareem"
            """
        )

        @Option(name: .long, help: "UTF-8 JSON-LD document to sign.")
        var data: String? = nil

        @Option(name: .customLong("data-file"), help: "Path to the JSON-LD document to sign.")
        var dataFile: FilePath? = nil

        @Option(name: [.customShort("s"), .customLong("secret-key")], help: "Author signing key — path to a .skey file or raw hex.")
        var secretKey: String? = nil

        @Option(name: .customLong("author-name"), help: "Display name to attach to the author entry.")
        var authorName: String? = nil

        @OptionGroup var output: SignerOutputOptions

        mutating func wizard() async throws {
            let path = noora.textPrompt(
                title: "JSON-LD Document",
                prompt: "Enter the path to the JSON-LD document:",
                validationRules: [NonEmptyValidationRule(error: "Path cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            dataFile = FilePath(path)
            secretKey = SignerUtils.promptSecretKeyPath(
                title: "Author Signing Key",
                prompt: "Enter the path to the author .skey file:"
            )
            let name = noora.textPrompt(
                title: "Author Name",
                prompt: "Enter the author name (optional, press enter to skip):",
                collapseOnAnswer: true
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            authorName = name.isEmpty ? nil : name
        }

        mutating func run() async throws {
            if (data == nil && dataFile == nil) || secretKey == nil {
                try await wizard()
            }
            let document = try SignerUtils.resolveData(text: data, hex: nil, file: dataFile)
            let key = try SignerUtils.resolveSecretKey(secretKey!)
            let signed = try await Signer.CIP100.signMetadata(
                document: document,
                signingKey: key,
                authorName: authorName
            )
            guard let text = String(data: signed, encoding: .utf8) else {
                throw ValidationError("Signed document was not valid UTF-8.")
            }
            try await SignerUtils.emit(text, to: output.outFile)
        }
    }
}
