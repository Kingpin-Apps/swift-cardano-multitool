import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore

extension GenerateMainCommand {

    struct Ed25519Key: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "ed25519",
            abstract: "Generate a random non-derivable Ed25519 keypair.",
            usage: """
            scm generate ed25519 --name mykey
            """
        )

        @Option(name: [.short, .long], help: "Output file prefix — produces <name>.skey and <name>.vkey.")
        var name: String? = nil

        mutating func wizard() async throws {
            name = noora.textPrompt(
                title: "Key Name",
                prompt: "Enter the output file prefix (without .skey / .vkey):",
                validationRules: [NonEmptyValidationRule(error: "Name cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        mutating func run() async throws {
            if name == nil {
                try await wizard()
            }
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let skeyPath = cwd.appending("\(name!).skey")
            let vkeyPath = cwd.appending("\(name!).vkey")
            try await FileUtils.checkFile(skeyPath)
            try await FileUtils.checkFile(vkeyPath)

            let seed = Data.randomBytes(count: 32)
            let signingKey = try SigningKey(payload: seed)
            let verificationKey: VerificationKey = try signingKey.toVerificationKey()
            try signingKey.save(to: skeyPath.string)
            try verificationKey.save(to: vkeyPath.string)
            try await FileUtils.fileLock(skeyPath)
            try await FileUtils.fileLock(vkeyPath)

            print(noora.format("\nSigning Key: \(.primary("\(skeyPath.string)"))"))
            try await FileUtils.displayFile(skeyPath)
            print(noora.format("\nVerification Key: \(.primary("\(vkeyPath.string)"))"))
            try await FileUtils.displayFile(vkeyPath)
            noora.success(.alert("Ed25519 keypair generated."))
        }
    }
}
