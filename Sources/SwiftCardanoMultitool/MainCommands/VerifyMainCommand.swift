import Foundation
import ArgumentParser

enum VerifyCommands: String, Subcommandable, AlignedChoiceDescribable {
    case `default`
    case cip8
    case cip30
    case cip100
    case back
    case exit

    var name: String {
        switch self {
            case .default: return "Default Ed25519"
            case .cip8: return "CIP-8 (COSE_Sign1)"
            case .cip30: return "CIP-30 (Wallet signData)"
            case .cip100: return "CIP-100 (Governance metadata)"
            case .back: return "Back"
            case .exit: return "Exit"
        }
    }

    var details: String {
        switch self {
            case .default: return "Verify a detached Ed25519 signature against a payload."
            case .cip8: return "Verify a CIP-8 COSE_Sign1 message."
            case .cip30: return "Verify a CIP-30 signData response."
            case .cip100: return "Verify every author signature in a CIP-100 governance metadata document."
            case .back: return "Go back to the main menu."
            case .exit: return "Leave the program."
        }
    }

    static var subcommands: [any AsyncParsableCommand.Type] {
        return Self.allCases.compactMap {
            switch $0 {
                case .back, .exit:
                    return .none
                default:
                    return $0.command()
            }
        }
    }

    func command() -> any AsyncParsableCommand.Type {
        switch self {
            case .default: return VerifyMainCommand.VerifyDefault.self
            case .cip8: return VerifyMainCommand.VerifyCIP8.self
            case .cip30: return VerifyMainCommand.VerifyCIP30.self
            case .cip100: return VerifyMainCommand.VerifyCIP100.self
            case .back: return MainMenuCommand.self
            case .exit: return ExitCommand.self
        }
    }
}

/// Verification operations for signatures produced by `scm sign …` and
/// equivalent cardano-signer outputs.
struct VerifyMainCommand: AsyncParsableCommand, MainCommandable {
    typealias E = VerifyCommands

    var name: String { "Verify" }

    static let configuration = CommandConfiguration(
        commandName: "verify",
        abstract: "Verify signatures and signed metadata.",
        discussion: """
        Verify Ed25519 signatures, CIP-8 / CIP-30 COSE_Sign1 messages,
        CIP-88 Calidus registration blobs, and CIP-100 governance metadata
        author witnesses. Exits 0 on a valid signature, non-zero otherwise.
        """,
        subcommands: VerifyCommands.subcommands
    )
}
