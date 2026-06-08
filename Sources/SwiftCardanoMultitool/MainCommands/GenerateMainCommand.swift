import Foundation
import ArgumentParser

enum GenerateCommands: String, Subcommandable, AlignedChoiceDescribable {
    case nodeColdKeys = "node-cold-keys"
    case nodeKesKeys = "node-kes-keys"
    case nodeOperationalCertificate = "node-operational-certificate"
    case nodeVrfKeys = "node-vrf-keys"
    case paymentAddressOnly = "payment-address-only"
    case paymentAndStakeAddress = "payment-and-stake-address"
    case keyRotation = "key-rotation"
    case poolJSON = "pool-json"
    case dRep = "drep"
    case policy = "policy"
    case assetMeta = "asset-meta"
    case ed25519
    case derivedKey = "derived-key"
    case voteKey = "vote-key"
    case calidusKey = "calidus-key"
    case byronKey = "byron-key"
    case back
    case exit

    var name: String {
        switch self {
            case .nodeColdKeys: return "Cold keys"
            case .nodeKesKeys: return "KES keys"
            case .nodeVrfKeys: return "VRF keys"
            case .nodeOperationalCertificate: return "Operational Certificate"
            case .paymentAddressOnly: return "Payment Address"
            case .paymentAndStakeAddress: return "Payment and Stake Address"
            case .keyRotation: return "Key Rotation"
            case .poolJSON: return "Pool.json"
            case .dRep: return "DRep Keys"
            case .policy: return "Policy"
            case .assetMeta: return "Asset Meta"
            case .ed25519: return "Ed25519 Key"
            case .derivedKey: return "BIP-32 Derived Key"
            case .voteKey: return "CIP-36 Vote Key"
            case .calidusKey: return "Calidus Pool Key"
            case .byronKey: return "Byron Key"
            case .back: return "Back"
            case .exit: return "Exit"
        }
    }

    var details: String {
        switch self {
            case .nodeColdKeys: return "Generate a new set of cold keys."
            case .nodeKesKeys: return "Generate the node KES keys."
            case .nodeVrfKeys: return "Generate the node VRF keys."
            case .nodeOperationalCertificate: return "Generate the node operational certificate."
            case .paymentAddressOnly: return "Generate a payment address only."
            case .paymentAndStakeAddress: return "Generate a payment and stake address."
            case .keyRotation: return "Rotate KES keys and generate a new operational certificate."
            case .poolJSON: return "Generate a new pool.json file."
            case .dRep: return "Generate Cardano governance DRep (Delegated Representative) keys."
            case .policy: return "Generate a Cardano native-script minting policy."
            case .assetMeta: return "Generate signed off-chain asset metadata for the Cardano Token Registry."
            case .ed25519: return "Generate a random Ed25519 keypair (no derivation tree)."
            case .derivedKey: return "Derive a BIP-32 key for any Cardano role from a mnemonic."
            case .voteKey: return "Generate a CIP-36 Catalyst voting keypair from a mnemonic."
            case .calidusKey: return "Generate a CIP-151 Calidus pool-operator keypair from a mnemonic."
            case .byronKey: return "Generate a Byron-era (Daedalus) keypair from a mnemonic."
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
            case .nodeColdKeys:
                return GenerateMainCommand.NodeColdKeys.self
            case .nodeKesKeys:
                return GenerateMainCommand.NodeKESKeys.self
            case .nodeVrfKeys:
                return GenerateMainCommand.NodeVRFKeys.self
            case .nodeOperationalCertificate:
                return GenerateMainCommand.NodeOperationalCertificate.self
            case .paymentAddressOnly:
                return GenerateMainCommand.PaymentAddressOnly.self
            case .paymentAndStakeAddress:
                return GenerateMainCommand.PaymentAndStakeAddress.self
            case .keyRotation:
                return GenerateMainCommand.KeyRotation.self
            case .poolJSON:
                return GenerateMainCommand.PoolJSON.self
            case .dRep:
                return GenerateMainCommand.DRepKeys.self
            case .policy:
                return GenerateMainCommand.Policy.self
            case .assetMeta:
                return GenerateMainCommand.AssetMeta.self
            case .ed25519:
                return GenerateMainCommand.Ed25519Key.self
            case .derivedKey:
                return GenerateMainCommand.DerivedKey.self
            case .voteKey:
                return GenerateMainCommand.VoteKey.self
            case .calidusKey:
                return GenerateMainCommand.CalidusKey.self
            case .byronKey:
                return GenerateMainCommand.ByronKey.self
            case .back:
                return MainMenuCommand.self
            case .exit:
                return ExitCommand.self
        }
    }
}

/// Generates cryptographic key pairs, addresses, and pool metadata.
///
/// Covers all key material needed for stake pool operation (cold, KES, VRF,
/// operational certificate) as well as wallet address generation and pool
/// registration metadata. See <doc:GenerateCommand> for full documentation.
struct GenerateMainCommand: AsyncParsableCommand, MainCommandable {
    typealias E = GenerateCommands

    var name: String { "Generate" }

    static let configuration = CommandConfiguration(
        commandName: "generate",
        abstract: "Generate keys, addresses, certificates, and pool metadata.",
        discussion: """
        Generate all cryptographic material needed to operate a Cardano node
        or wallet: cold/KES/VRF key pairs, operational certificates, payment
        and stake addresses, KES key rotation, and pool.json metadata files.
        """,
        subcommands: GenerateCommands.subcommands,
        aliases: ["gen"]
    )
}
