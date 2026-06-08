import Foundation
import ArgumentParser

enum SignCommands: String, Subcommandable, AlignedChoiceDescribable {
    case `default`
    case cip8
    case cip30
    case cip36
    case cip88
    case cip100
    case back
    case exit

    var name: String {
        switch self {
            case .default: return "Default Ed25519"
            case .cip8: return "CIP-8 (COSE_Sign1)"
            case .cip30: return "CIP-30 (Wallet signData)"
            case .cip36: return "CIP-36 (Catalyst voting)"
            case .cip88: return "CIP-88 (Calidus pool registration)"
            case .cip100: return "CIP-100 (Governance metadata)"
            case .back: return "Back"
            case .exit: return "Exit"
        }
    }

    var details: String {
        switch self {
            case .default: return "Sign an arbitrary payload with an Ed25519 key."
            case .cip8: return "Wrap a payload in a CIP-8 COSE_Sign1 envelope tied to an address."
            case .cip30: return "Produce a CIP-30 signData response (CIP-8 with attached COSE_Key)."
            case .cip36: return "Build a CIP-36 Catalyst voting registration or deregistration."
            case .cip88: return "Build a CIP-88 / CIP-151 Calidus pool-key registration."
            case .cip100: return "Sign a CIP-100 governance metadata document (JSON-LD)."
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
            case .default: return SignMainCommand.SignDefault.self
            case .cip8: return SignMainCommand.SignCIP8.self
            case .cip30: return SignMainCommand.SignCIP30.self
            case .cip36: return SignMainCommand.SignCIP36.self
            case .cip88: return SignMainCommand.SignCIP88.self
            case .cip100: return SignMainCommand.SignCIP100.self
            case .back: return MainMenuCommand.self
            case .exit: return ExitCommand.self
        }
    }
}

/// Off-chain signing operations — Ed25519, COSE_Sign1, Catalyst voting, governance metadata.
///
/// Wraps the cardano-signer.js feature surface, backed by the native
/// `swift-cardano-signer` library so callers can sign without shelling out.
struct SignMainCommand: AsyncParsableCommand, MainCommandable {
    typealias E = SignCommands

    var name: String { "Sign" }

    static let configuration = CommandConfiguration(
        commandName: "sign",
        abstract: "Sign messages, governance metadata, and registrations.",
        discussion: """
        Off-line / off-chain signing operations. Covers plain Ed25519
        signatures, CIP-8 / CIP-30 wallet message signing, CIP-36 Catalyst
        voting registrations, CIP-88 Calidus pool-key registrations, and
        CIP-100 governance metadata witnesses.
        """,
        subcommands: SignCommands.subcommands
    )
}
