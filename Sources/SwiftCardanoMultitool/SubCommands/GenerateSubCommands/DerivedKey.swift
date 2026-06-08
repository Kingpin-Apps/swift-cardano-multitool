import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoSigner
import SwiftMnemonic

/// Cardano BIP-32 derivation-path shortcut, mapped to a `ShelleyKeyKind`.
public enum CardanoPathShortcut: String, ExpressibleByArgument, CaseIterable, CustomStringConvertible {
    case payment
    case stake
    case drep
    case ccCold = "cc-cold"
    case ccHot = "cc-hot"
    case pool
    case calidus

    public var description: String { rawValue }

    public func kind(account: UInt32 = 0, index: UInt32 = 0) -> ShelleyKeyKind {
        switch self {
        case .payment: return .payment(account: account, index: index)
        case .stake: return .stake(account: account, index: index)
        case .drep: return .drep(account: account, index: index)
        case .ccCold: return .ccCold(account: account, index: index)
        case .ccHot: return .ccHot(account: account, index: index)
        case .pool: return .pool(account: account)
        case .calidus: return .calidus(account: account)
        }
    }
}

/// Hardware-wallet derivation variant.
public enum HwVariant: String, ExpressibleByArgument, CaseIterable, CustomStringConvertible {
    case icarus
    case ledger
    case trezor

    public var description: String { rawValue }
}

extension GenerateMainCommand {

    struct DerivedKey: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "derived-key",
            abstract: "Derive a BIP-32 key for any Cardano role from a BIP-39 mnemonic.",
            usage: """
            scm generate derived-key --name mykey --path payment
            scm generate derived-key --name mydrep --path drep --variant ledger
            """
        )

        @Option(name: [.short, .long], help: "Output file prefix — produces <name>.skey, <name>.vkey, and <name>.mnemonics.")
        var name: String? = nil

        @Option(name: [.short, .long], help: "Derivation path shortcut.")
        var path: CardanoPathShortcut? = nil

        @Option(name: .long, help: "Sub-account index for derivation (default 0).")
        var account: UInt32 = 0

        @Option(name: .long, help: "Leaf index for derivation (default 0).")
        var index: UInt32 = 0

        @Option(name: .long, help: "BIP-39 mnemonic phrase. If omitted, a new mnemonic is generated.")
        var mnemonics: String? = nil

        @Option(name: .long, help: "Optional BIP-39 passphrase (the '25th word').")
        var passphrase: String = ""

        @Option(name: .long, help: "Master-key variant. Options: icarus (default), ledger, trezor.")
        var variant: HwVariant = .icarus

        @Option(name: .long, help: "Mnemonic language used when generating a new phrase.")
        var language: Language = .english

        @Option(name: .long, help: "Word count for newly generated mnemonics.")
        var wordCount: WordCount = .twentyFour

        mutating func wizard() async throws {
            name = noora.textPrompt(
                title: "Key Name",
                prompt: "Enter the output file prefix:",
                validationRules: [NonEmptyValidationRule(error: "Name cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            path = noora.singleChoicePrompt(
                title: "Derivation Path",
                question: "Pick a derivation path shortcut.",
                options: CardanoPathShortcut.allCases,
                description: "Maps to the corresponding CIP-1852 / CIP-1853 / CIP-1854 path."
            )
            variant = noora.singleChoicePrompt(
                title: "Variant",
                question: "Pick the master-key derivation variant.",
                options: HwVariant.allCases,
                description: "Use 'icarus' for cardano-cli / cardano-address compatibility, 'ledger' or 'trezor' for hardware-wallet parity."
            )
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
            if name == nil || path == nil {
                try await wizard()
            }
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let skey = cwd.appending("\(name!).skey")
            let vkey = cwd.appending("\(name!).vkey")
            let mnemonicsFile = cwd.appending("\(name!).mnemonics")
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
            let kind = path!.kind(account: account, index: index)

            let bundle: KeyPairBundle
            switch variant {
            case .icarus:
                bundle = try Signer.Keygen.shelley(mnemonic: words, passphrase: passphrase, kind: kind)
            case .ledger:
                bundle = try Signer.Keygen.ledger(mnemonic: words, passphrase: passphrase, kind: kind)
            case .trezor:
                bundle = try Signer.Keygen.trezor(mnemonic: words, passphrase: passphrase, kind: kind)
            }

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
            print(noora.format("\nSigning Key: \(.primary("\(skey.string)"))"))
            try await FileUtils.displayFile(skey)
            print(noora.format("\nVerification Key: \(.primary("\(vkey.string)"))"))
            try await FileUtils.displayFile(vkey)
            noora.success(.alert("Derived key generated."))
        }
    }
}
