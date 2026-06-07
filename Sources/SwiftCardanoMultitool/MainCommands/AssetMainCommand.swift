import Foundation
import ArgumentParser

enum AssetCommands: String, Subcommandable, AlignedChoiceDescribable {
    case mint
    case burn
    case back
    case exit

    var name: String {
        switch self {
            case .mint: return "Mint"
            case .burn: return "Burn"
            case .back: return "Back"
            case .exit: return "Exit"
        }
    }

    var details: String {
        switch self {
            case .mint: return "Mint a native asset using a local minting policy."
            case .burn: return "Burn a native asset using a local minting policy."
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
            case .mint: return AssetMainCommand.Mint.self
            case .burn: return AssetMainCommand.Burn.self
            case .back: return MainMenuCommand.self
            case .exit: return ExitCommand.self
        }
    }
}

/// Native asset lifecycle operations: mint and burn tokens under a local minting policy.
///
/// Both subcommands load `<policyName>.policy.{id,script,vkey,skey|hwsfile}` from the
/// current directory, build a balanced transaction that sets `mint = MultiAsset(...)`
/// with the appropriate sign, sign with both the payment and policy keys, and
/// (optionally) submit. The `<policyName>.<assetDisplay>.asset` sidecar is updated
/// with a sequence-numbered audit entry on success.
struct AssetMainCommand: AsyncParsableCommand, MainCommandable {
    typealias E = AssetCommands

    var name: String { "Asset" }

    static let configuration = CommandConfiguration(
        commandName: "asset",
        abstract: "Mint and burn native assets.",
        discussion: """
        High-level mint/burn commands that wrap the full build–sign–submit pipeline.
        Requires a policy generated via 'scm generate policy' and a funded payment
        address. Optional CIP-20 plaintext messages and external metadata-JSON files
        flow through to the transaction's auxiliary data.
        """,
        subcommands: AssetCommands.subcommands
    )
}
