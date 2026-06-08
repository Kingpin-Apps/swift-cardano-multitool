import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoSigner
import SwiftMnemonic

extension GenerateMainCommand {

    struct VoteKey: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "vote-key",
            abstract: "Generate a CIP-36 Catalyst voting keypair from a BIP-39 mnemonic.",
            usage: """
            scm generate vote-key --name myvote
            scm generate vote-key --name myvote --account 0 --address 0
            """
        )

        @Option(name: [.short, .long], help: "Output file prefix — produces <name>.vote.skey, <name>.vote.vkey, <name>.vote.mnemonics.")
        var name: String? = nil

        @Option(name: .long, help: "Account index (default 0).")
        var account: UInt32 = 0

        @Option(name: .long, help: "Address index (default 0).")
        var address: UInt32 = 0

        @Option(name: .long, help: "Existing BIP-39 mnemonic. If omitted, a new one is generated.")
        var mnemonics: String? = nil

        @Option(name: .long, help: "Optional BIP-39 passphrase.")
        var passphrase: String = ""

        @Option(name: .long, help: "Mnemonic language for newly generated phrases.")
        var language: Language = .english

        @Option(name: .long, help: "Word count for newly generated mnemonics.")
        var wordCount: WordCount = .twentyFour

        mutating func wizard() async throws {
            name = noora.textPrompt(
                title: "Vote Key Name",
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
                    prompt: "Enter your existing mnemonic phrase:",
                    validationRules: [NonEmptyValidationRule(error: "Mnemonic cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        mutating func run() async throws {
            if name == nil {
                try await wizard()
            }
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let skey = cwd.appending("\(name!).vote.skey")
            let vkey = cwd.appending("\(name!).vote.vkey")
            let mnemonicsFile = cwd.appending("\(name!).vote.mnemonics")
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

            let bundle = try Signer.Keygen.cip36(
                mnemonic: words,
                passphrase: passphrase,
                account: account,
                address: address
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
            print(noora.format("\nVote Signing Key: \(.primary("\(skey.string)"))"))
            try await FileUtils.displayFile(skey)
            print(noora.format("\nVote Verification Key: \(.primary("\(vkey.string)"))"))
            try await FileUtils.displayFile(vkey)
            noora.success(.alert("CIP-36 vote keypair generated."))
        }
    }
}
