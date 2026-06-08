import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoSigner
import SwiftMnemonic

extension GenerateMainCommand {

    struct ByronKey: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "byron-key",
            abstract: "Generate a Byron-era (Daedalus) keypair from a BIP-39 mnemonic.",
            usage: """
            scm generate byron-key --name mybyron
            """,
            discussion: """
            Currently only the Daedalus variant is supported. Yoroi paperwallet
            and Exodus variants are not yet ported in swift-cardano-signer.
            """
        )

        @Option(name: [.short, .long], help: "Output file prefix — produces <name>.byron.skey, <name>.byron.vkey, <name>.byron.mnemonics.")
        var name: String? = nil

        @Option(name: .long, help: "Existing BIP-39 mnemonic. If omitted, a new one is generated.")
        var mnemonics: String? = nil

        @Option(name: .long, help: "Mnemonic language for newly generated phrases.")
        var language: Language = .english

        @Option(name: .long, help: "Word count for newly generated mnemonics.")
        var wordCount: WordCount = .twentyFour

        mutating func wizard() async throws {
            name = noora.textPrompt(
                title: "Byron Key Name",
                prompt: "Enter the output file prefix:",
                validationRules: [NonEmptyValidationRule(error: "Name cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            if noora.yesOrNoChoicePrompt(
                title: "Mnemonic",
                question: "Use an existing mnemonic? (No = generate a new one)",
                defaultAnswer: false
            ) {
                mnemonics = noora.textPrompt(
                    title: "Mnemonic",
                    prompt: "Enter your existing Daedalus mnemonic phrase:",
                    validationRules: [NonEmptyValidationRule(error: "Mnemonic cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        mutating func run() async throws {
            if name == nil {
                try await wizard()
            }
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let skey = cwd.appending("\(name!).byron.skey")
            let vkey = cwd.appending("\(name!).byron.vkey")
            let mnemonicsFile = cwd.appending("\(name!).byron.mnemonics")
            try await FileUtils.checkFile(skey)
            try await FileUtils.checkFile(vkey)

            let phrase: String
            if let existing = mnemonics, !existing.isEmpty {
                phrase = existing
            } else {
                phrase = try HDWallet.generateMnemonic(
                    language: language,
                    wordCount: wordCount
                ).joined(separator: " ")
                print(noora.format("Generated mnemonic: \(.primary(phrase))"))
            }
            let words = phrase.split(separator: " ").map(String.init)

            let bundle = try Signer.Keygen.byron(
                mnemonic: words,
                variant: .daedalus
            )

            try bundle.signingKey.save(to: skey.string)
            try bundle.verificationKey.save(to: vkey.string)
            if mnemonics == nil {
                try await FileUtils.checkFile(mnemonicsFile)
                try phrase.write(toFile: mnemonicsFile.string, atomically: true, encoding: .utf8)
                try await FileUtils.fileLock(mnemonicsFile)
            }
            try await FileUtils.fileLock(skey)
            try await FileUtils.fileLock(vkey)

            print(noora.format("\nDerivation Path: \(.primary(bundle.path))"))
            print(noora.format("\nByron Signing Key: \(.primary("\(skey.string)"))"))
            try await FileUtils.displayFile(skey)
            print(noora.format("\nByron Verification Key: \(.primary("\(vkey.string)"))"))
            try await FileUtils.displayFile(vkey)
            noora.success(.alert("Byron keypair generated."))
        }
    }
}
