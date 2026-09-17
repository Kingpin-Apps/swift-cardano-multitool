import Foundation
import ArgumentParser

enum HashCommands: String, Subcommandable, AlignedChoiceDescribable {
    case paymentKey = "payment-key"
    case stakeKey = "stake-key"
    case drepKey = "drep-key"
    case committeeKey = "committee-key"
    case poolId = "pool-id"
    case vrfKey = "vrf-key"
    case genesisKey = "genesis-key"
    case anchorData = "anchor-data"
    case drepMetadata = "drep-metadata"
    case poolMetadata = "pool-metadata"
    case script
    case genesisFile = "genesis-file"
    case back
    case exit

    var name: String {
        switch self {
            case .paymentKey: return "Payment Key Hash"
            case .stakeKey: return "Stake Key Hash"
            case .drepKey: return "DRep Key Hash / ID"
            case .committeeKey: return "Committee Key Hash"
            case .poolId: return "Pool ID"
            case .vrfKey: return "VRF Key Hash"
            case .genesisKey: return "Genesis Key Hash"
            case .anchorData: return "Anchor Data"
            case .drepMetadata: return "DRep Metadata"
            case .poolMetadata: return "Pool Metadata"
            case .script: return "Script"
            case .genesisFile: return "Genesis File"
            case .back: return "Back"
            case .exit: return "Exit"
        }
    }

    var details: String {
        switch self {
            case .paymentKey: return "Hash of a payment verification key (address key-hash)."
            case .stakeKey: return "Hash of a stake verification key (stake-address key-hash)."
            case .drepKey: return "DRep key hash or ID (governance drep id)."
            case .committeeKey: return "Hash of a committee hot or cold key (governance committee key-hash)."
            case .poolId: return "Pool ID from a cold verification key (stake-pool id)."
            case .vrfKey: return "Hash of a VRF verification key (node key-hash-VRF)."
            case .genesisKey: return "Hash of a genesis, delegate or UTxO key (genesis key-hash)."
            case .anchorData: return "Hash of governance anchor data from text, a file or a URL."
            case .drepMetadata: return "Hash of a DRep metadata file (governance drep metadata-hash)."
            case .poolMetadata: return "Hash of a stake pool metadata file (stake-pool metadata-hash)."
            case .script: return "Hash of a native or Plutus script."
            case .genesisFile: return "Hash of a genesis file for the node configuration."
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
            case .paymentKey: return HashMainCommand.PaymentKey.self
            case .stakeKey: return HashMainCommand.StakeKey.self
            case .drepKey: return HashMainCommand.DRepKey.self
            case .committeeKey: return HashMainCommand.CommitteeKey.self
            case .poolId: return HashMainCommand.PoolId.self
            case .vrfKey: return HashMainCommand.VRFKey.self
            case .genesisKey: return HashMainCommand.GenesisKey.self
            case .anchorData: return HashMainCommand.AnchorData.self
            case .drepMetadata: return HashMainCommand.DRepMetadata.self
            case .poolMetadata: return HashMainCommand.PoolMetadata.self
            case .script: return HashMainCommand.Script.self
            case .genesisFile: return HashMainCommand.GenesisFile.self
            case .back: return MainMenuCommand.self
            case .exit: return ExitCommand.self
        }
    }
}

/// Hashes of keys, scripts, anchor data and genesis files — the `cardano-cli hash`,
/// `address key-hash` and `stake-address key-hash` equivalents.
struct HashMainCommand: AsyncParsableCommand, MainCommandable {
    typealias E = HashCommands

    var name: String { "Hash" }

    static let configuration = CommandConfiguration(
        commandName: "hash",
        abstract: "Compute hashes and IDs of keys, scripts, metadata, anchor data and genesis files.",
        discussion: """
        Compute the hashes passed to the various --*-hash arguments of other commands.
        When the output is piped, only the hash is printed so it can be captured,
        e.g. HASH=$(scm hash script --script-file policy.script).
        """,
        subcommands: HashCommands.subcommands
    )
}
