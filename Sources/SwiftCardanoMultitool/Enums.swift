import ArgumentParser
import SwiftCardanoCore
import SystemPackage

public enum Mode: String, CaseIterable, CodingKeyRepresentable, Codable, Hashable , Sendable{
    case auto = "auto"
    case online = "online"
    case offline = "offline"
    case lite = "lite"
}

enum GetAddressBy: String, CaseIterable, AlignedChoiceDescribable {
    case name
    case path

    var name: String {
        switch self {
            case .name: return "Name"
            case .path: return "Path"
        }
    }

    var details: String {
        switch self {
            case .name: return "The name of the stem of the file."
            case .path: return "The path to the address.addr file."
        }
    }
}

enum GetTransactionBy: String, CaseIterable, AlignedChoiceDescribable {
    case cborHex
    case path

    var name: String {
        switch self {
            case .cborHex: return "CBOR Hex"
            case .path: return "Path"
        }
    }

    var details: String {
        switch self {
            case .cborHex: return "The CBOR Hex representation of the transaction."
            case .path: return "The path to the transaction file."
        }
    }
}

enum EnterAddressBy: String, CaseIterable, AlignedChoiceDescribable {
    case adahandle
    case address
    case path

    var name: String {
        switch self {
            case .adahandle: return "Adahandle"
            case .address: return "Address"
            case .path: return "Path"
        }
    }

    var details: String {
        switch self {
            case .adahandle: return "The adahandle associated with the address."
            case .address: return "The address in Bech32 or Hex format."
            case .path: return "The path to the file containing the address."
        }
    }
}

enum EnterDRepBy: String, CaseIterable, AlignedChoiceDescribable {
    case alwaysAbstain
    case alwaysNoConfidence
    case bech32
    case hex
    case path
    case vkey
    case skey
    case mnemonics

    var name: String {
        switch self {
            case .alwaysAbstain: return "Always Abstain"
            case .alwaysNoConfidence: return "Always No Confidence"
            case .bech32: return "Bech32"
            case .hex: return "Hex"
            case .path: return "Path"
            case .vkey: return "Vkey"
            case .skey: return "Skey"
            case .mnemonics: return "Mnemonics"
        }
    }

    var details: String {
        switch self {
            case .alwaysAbstain: return "Sets the DRep to always abstain."
            case .alwaysNoConfidence: return "Sets the DRep to always have no confidence."
            case .bech32: return "The DRep in Bech32 format."
            case .hex: return "The DRep in Hex format."
            case .path: return "The path to the file containing the DRep Id."
            case .vkey: return "The path to the verification key file."
            case .skey: return "The path to the signing key file."
            case .mnemonics: return "The mnemonics used to derive the DRep Id."
        }
    }
}

enum EnterPoolOperatorBy: String, CaseIterable, AlignedChoiceDescribable {
    case bech32
    case hex
    case path
    case vkey
    case skey

    var name: String {
        switch self {
            case .bech32: return "Bech32"
            case .hex: return "Hex"
            case .path: return "Path"
            case .vkey: return "Vkey"
            case .skey: return "Skey"
        }
    }

    var details: String {
        switch self {
            case .bech32: return "The Pool Operator ID in Bech32 format."
            case .hex: return "The Pool Operator ID in Hex format."
            case .path: return "The path to the file containing the Pool Operator ID."
            case .vkey: return "The path to the verification key file."
            case .skey: return "The path to the signing key file."
        }
    }
}

enum EnterCommitteeColdCredentialBy: String, CaseIterable, AlignedChoiceDescribable {
    case bech32
    case hex
    case vkey
    case skey

    var name: String {
        switch self {
            case .bech32: return "Bech32"
            case .hex: return "Hex"
            case .vkey: return "Vkey"
            case .skey: return "Skey"
        }
    }

    var details: String {
        switch self {
            case .bech32: return "The Committee Cold Credential in Bech32 format (cc_cold1...)."
            case .hex: return "The Committee Cold Credential as a 56-character hex key hash."
            case .vkey: return "The path to the cold verification key file (.cc-cold.vkey)."
            case .skey: return "The path to the cold signing key file (.cc-cold.skey)."
        }
    }
}

enum EnterCommitteeHotCredentialBy: String, CaseIterable, AlignedChoiceDescribable {
    case bech32
    case hex
    case vkey
    case skey

    var name: String {
        switch self {
            case .bech32: return "Bech32"
            case .hex: return "Hex"
            case .vkey: return "Vkey"
            case .skey: return "Skey"
        }
    }

    var details: String {
        switch self {
            case .bech32: return "The Committee Hot Credential in Bech32 format (cc_hot1...)."
            case .hex: return "The Committee Hot Credential as a 56-character hex key hash."
            case .vkey: return "The path to the hot verification key file (.cc-hot.vkey)."
            case .skey: return "The path to the hot signing key file (.cc-hot.skey)."
        }
    }
}

enum EnterDRepCredentialBy: String, CaseIterable, AlignedChoiceDescribable {
    case bech32
    case hex
    case vkey
    case skey

    var name: String {
        switch self {
            case .bech32: return "Bech32"
            case .hex: return "Hex"
            case .vkey: return "Vkey"
            case .skey: return "Skey"
        }
    }

    var details: String {
        switch self {
            case .bech32: return "The DRep Credential in Bech32 format (drep1...)."
            case .hex: return "The DRep Credential as a 56-character hex key hash."
            case .vkey: return "The path to the DRep verification key file (.drep.vkey)."
            case .skey: return "The path to the DRep signing key file (.drep.skey)."
        }
    }
}

enum EnterAssetMetaBy: String, CaseIterable, AlignedChoiceDescribable {
    case hexSubject
    case path

    var name: String {
        switch self {
            case .hexSubject: return "Hex Subject"
            case .path: return "File Path"
        }
    }

    var details: String {
        switch self {
            case .hexSubject: return "The asset subject as 56-120 hex characters (policyId || assetNameHex)."
            case .path: return "The path to a .asset JSON file containing a top-level `subject` field."
        }
    }
}

enum MoveInstantaneousRewardSourceOption: String, CaseIterable, AlignedChoiceDescribable {
    case reserves
    case treasury

    var name: String {
        switch self {
            case .reserves: return "Reserves"
            case .treasury: return "Treasury"
        }
    }

    var details: String {
        switch self {
            case .reserves: return "Transfer from the reserves."
            case .treasury: return "Transfer from the treasury."
        }
    }
}

public enum KeyGenMethod: String, CaseIterable, AlignedChoiceDescribable, ExpressibleByArgument, Sendable, Codable, Hashable {

    case cli = "cli"
    case enc = "enc"
    case hw = "hw"
    case hwMulti = "hw_multi"
    case hybrid = "hybrid"
    case hybridMulti = "hybrid_multi"
    case hybridEnc = "hybrid_enc"
    case hybridMultiEnc = "hybrid_multi_enc"
    case mnemonics = "mnemonics"

    public var isEncryptedType: Bool {
        switch self {
            case .enc, .hybridEnc, .hybridMultiEnc:
                return true
            case .cli, .hw, .hwMulti, .hybrid, .hybridMulti, .mnemonics:
                return false
        }
    }

    public var isHardwareType: Bool {
        switch self {
            case .hw, .hwMulti, .hybrid, .hybridMulti, .hybridEnc, .hybridMultiEnc:
                return true
            case .cli, .enc, .mnemonics:
                return false
        }
    }

    public var isMultisigType: Bool {
        switch self {
            case .hwMulti, .hybridMulti, .hybridMultiEnc:
                return true
            case .cli, .enc, .hw, .hybrid, .hybridEnc, .mnemonics:
                return false
        }
    }

    public var isHybridType: Bool {
        switch self {
            case .hybrid, .hybridMulti, .hybridEnc, .hybridMultiEnc:
                return true
            case .cli, .enc, .hw, .hwMulti, .mnemonics:
                return false
        }
    }

    public var name: String {
        switch self {
            case .cli: return "CLI"
            case .enc: return "Enc"
            case .hw: return "HW"
            case .hwMulti: return "HW Multi"
            case .hybrid: return "Hybrid"
            case .hybridMulti: return "Hybrid Multi"
            case .hybridEnc: return "Hybrid Enc"
            case .hybridMultiEnc: return "Hybrid Multi Enc"
            case .mnemonics: return "Mnemonics"
        }
    }

    public var details: String {
        switch self {
            case .cli: return "Keys generated using cardano-cli or SwiftCardano library."
            case .enc: return "Keys generated using cardano-cli or SwiftCardano library then encrypted using GnuPG."
            case .hw: return "Keys generated using Ledger/Trezor HW-Keys (Normal-Path 1852H/1815H/<Acc>/0,2/<Idx>)."
            case .hwMulti: return "Keys generated using Ledger/Trezor HW-Keys (MultiSig-Path 1854H/1815H/<Acc>/0,2/<Idx>)."
            case .hybrid: return "Payment keys using Ledger/Trezor HW-Keys, Staking keys via cardano-cli or SwiftCardano library (comfort mode for multiowner pools)."
            case .hybridEnc: return "Payment keys using Ledger/Trezor HW-Keys, Staking keys via cardano-cli or SwiftCardano library and encrypted via a Password."
            case .hybridMulti: return "Payment keys using Ledger/Trezor HW-Keys (MultiSig-Path 1854H/1815H/<Acc>/0/<Idx>), Staking keys via cliMultiSig hybrid keys generated."
            case .hybridMultiEnc: return "Payment keys using Ledger/Trezor HW-Keys (MultiSig-Path 1854H/1815H/<Acc>/0/<Idx>), Staking keys via cli and encrypted via a Password."
            case .mnemonics: return "Payment & Staking keys via cardano-cli or SwiftCardano library and also generates Mnemonics for LightWallet import possibilities."
        }
    }
}

public enum StartStopChoice: String, CaseIterable, CustomStringConvertible, ExpressibleByArgument, Sendable, Codable, Hashable {
    case start
    case stop
    
    public var description: String {
        switch self {
            case .start:
                return "Start process"
            case .stop:
                return "Stop process"
        }
    }
}

public enum SigningMethod {
    case softwareKey(FilePath)
    case hardwareWallet(FilePath)
    
    public var isHardware: Bool {
        switch self {
            case .hardwareWallet: return true
            case .softwareKey: return false
        }
    }
    
    public var path: FilePath {
        switch self {
            case .hardwareWallet(let path): return path
            case .softwareKey(let path): return path
        }
    }
}


public enum Tool: CaseIterable, CustomStringConvertible, ExpressibleByArgument, Sendable, Codable, Hashable {
    case swiftCardano
    case cardanoCLI
    
    public var description: String {
        switch self {
            case .swiftCardano:
                return "SwiftCardano"
            case .cardanoCLI:
                return "Cardano CLI"
        }
    }
    
    public init?(argument: String) {
        let trimmed = argument.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch trimmed {
            case "swiftcardano", "swift-cardano", "swift_cardano":
                self = .swiftCardano
            case "cardanocli", "cardano-cli", "cardano_cli":
                self = .cardanoCLI
            default:
                return nil
        }
    }
}



public enum WhichPeriod: CaseIterable, CustomStringConvertible, ExpressibleByArgument, Sendable, Codable, Hashable {
    case current
    case next
    
    public var description: String {
        switch self {
            case .current:
                return "Current"
            case .next:
                return "Next"
        }
    }
    
    public init?(argument: String) {
        let trimmed = argument.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch trimmed {
            case "current":
                self = .current
            case "next":
                self = .next
            default:
                return nil
        }
    }
}

/// Enum for transaction types
public enum TransactionType: String, Codable, Sendable, Hashable, CaseIterable, CustomStringConvertible {
    case transaction = "Transaction"
    case assetMinting = "AssetMinting"
    case assetBurning = "AssetBurning"
    case withdrawal = "Withdrawal"
    case stakeKeyRegistration = "StakeKeyRegistration"
    case stakeKeyDeRegistration = "StakeKeyDeRegistration"
    case delegationCertRegistration = "DelegationCertRegistration"
    case poolRegistration = "PoolRegistration"
    case poolReRegistration = "PoolReRegistration"
    case poolRetirement = "PoolRetirement"
    
    public var description: String { rawValue }
}

// MARK: - PoolJSON Enums

/// Enum for witness type indicating whether the witness is local or external
public enum WitnessType: String, Codable, Sendable, Hashable, CaseIterable, CustomStringConvertible {
    case local = "local"
    case external = "external"
    
    public var description: String { rawValue }
}

/// Enum for relay type
public enum SPORelayType: String, Codable, Sendable, Hashable, CaseIterable, CustomStringConvertible {
    case ip = "ip"
    case dns = "dns"
    
    public var description: String { rawValue }
}

/// Enum for host type
public enum HostType: String, Codable, Sendable, Hashable, CaseIterable, CustomStringConvertible {
    case ipv4 = "ipv4"
    case ipv6 = "ipv6"
    case single = "single"
    case multi = "multi"
    
    public var description: String { rawValue }
}

enum ConfigFileType: String, ExpressibleByArgument, CaseIterable, CustomStringConvertible, Sendable {
    case json
    case toml
    case yaml

    var description: String { rawValue }
    var defaultValueDescription: String { "json" }
}

enum ConfigNetwork: String, ExpressibleByArgument, CaseIterable, CustomStringConvertible, Sendable {
    case mainnet
    case preprod
    case preview
    case guildnet
    case sanchonet
    
    var description: String { rawValue }
    
    var network: Network {
        switch self {
            case .mainnet: return .mainnet
            case .preprod: return .preprod
            case .preview: return .preview
            case .guildnet: return .guildnet
            case .sanchonet: return .sanchonet
        }
    }
}

enum EnterVoterBy: String, CaseIterable, AlignedChoiceDescribable {
    case none
    case drep
    case spo
    case ccCold = "cc-cold"
    case ccHot = "cc-hot"

    var name: String {
        switch self {
            case .none: return "No voter filter"
            case .drep: return "DRep"
            case .spo: return "Stake Pool Operator"
            case .ccCold: return "Committee Member (cold)"
            case .ccHot: return "Committee Member (hot)"
        }
    }

    var details: String {
        switch self {
            case .none: return "Show all votes without filtering by voter."
            case .drep: return "Filter to votes cast by a specific DRep."
            case .spo: return "Filter to votes cast by a specific stake pool."
            case .ccCold: return "Filter to votes cast by a constitutional committee member (by cold credential)."
            case .ccHot: return "Filter to votes cast by a constitutional committee member (by authorized hot credential)."
        }
    }
}

enum VoteActionTypeFilter: String, CaseIterable, ExpressibleByArgument, AlignedChoiceDescribable {
    case any = "any"
    case parameterChange = "parameter-change"
    case hardFork = "hard-fork"
    case treasuryWithdrawal = "treasury-withdrawal"
    case noConfidence = "no-confidence"
    case updateCommittee = "update-committee"
    case newConstitution = "new-constitution"
    case infoAction = "info"

    var name: String {
        switch self {
            case .any: return "Any"
            case .parameterChange: return "Parameter Change"
            case .hardFork: return "Hard Fork Initiation"
            case .treasuryWithdrawal: return "Treasury Withdrawal"
            case .noConfidence: return "No Confidence"
            case .updateCommittee: return "Update Committee"
            case .newConstitution: return "New Constitution"
            case .infoAction: return "Info Action"
        }
    }

    var details: String {
        switch self {
            case .any: return "Include actions of every type."
            case .parameterChange: return "Protocol parameter update actions."
            case .hardFork: return "Hard-fork initiation actions."
            case .treasuryWithdrawal: return "Treasury withdrawal actions."
            case .noConfidence: return "No-confidence motions against the constitutional committee."
            case .updateCommittee: return "Actions that update the constitutional committee."
            case .newConstitution: return "Actions that propose a new constitution."
            case .infoAction: return "Non-binding informational actions."
        }
    }
}

/// Role of the voter casting a Conway-era vote. CC-Cold is intentionally absent — the
/// cold credential authorizes the hot credential, the hot credential votes.
enum VoterRole: String, CaseIterable, ExpressibleByArgument, AlignedChoiceDescribable {
    case drep
    case spo
    case ccHot = "cc-hot"

    var name: String {
        switch self {
            case .drep: return "DRep"
            case .spo: return "Stake Pool Operator"
            case .ccHot: return "Committee Member (hot)"
        }
    }

    var details: String {
        switch self {
            case .drep: return "Cast the vote as a registered DRep (.drep.vkey/.drep.skey)."
            case .spo: return "Cast the vote as a stake pool operator (.node.vkey/.node.skey)."
            case .ccHot: return "Cast the vote as a constitutional committee member's hot key (.cc-hot.vkey/.cc-hot.skey)."
        }
    }

    /// File-extension suffix used in the codebase's key-file naming convention. The
    /// matching signing key is `<stem>.<suffix>.skey` (or `.hwsfile`).
    var keyFileSuffix: String {
        switch self {
            case .drep: return "drep"
            case .spo: return "node"
            case .ccHot: return "cc-hot"
        }
    }
}

/// Conway-era governance action type. Mirrors `SwiftCardanoCore.GovActionCode` (which is the
/// CDDL tag) but uses bash-script-style hyphenated names so CLI args match `25a_genAction.sh`.
enum GovernanceActionType: String, CaseIterable, ExpressibleByArgument, AlignedChoiceDescribable {
    case infoAction = "info"
    case treasuryWithdrawal = "treasury-withdrawal"
    case noConfidence = "no-confidence"
    case newConstitution = "new-constitution"
    case hardForkInitiation = "hard-fork-initiation"
    case updateCommittee = "update-committee"
    case parameterChange = "parameter-change"

    var name: String {
        switch self {
            case .infoAction: return "Info Action"
            case .treasuryWithdrawal: return "Treasury Withdrawal"
            case .noConfidence: return "No Confidence"
            case .newConstitution: return "New Constitution"
            case .hardForkInitiation: return "Hard Fork Initiation"
            case .updateCommittee: return "Update Committee"
            case .parameterChange: return "Parameter Change"
        }
    }

    var details: String {
        switch self {
            case .infoAction:
                return "Non-binding informational action (no on-chain effect, just records the anchor)."
            case .treasuryWithdrawal:
                return "Withdraw lovelace from the treasury to one or more stake addresses."
            case .noConfidence:
                return "Motion of no-confidence against the current constitutional committee."
            case .newConstitution:
                return "Propose a new on-chain constitution document."
            case .hardForkInitiation:
                return "Trigger a hard fork at a new protocol major/minor version."
            case .updateCommittee:
                return "Add/remove constitutional committee members and adjust the threshold."
            case .parameterChange:
                return "Update one or more protocol parameters."
        }
    }

    /// Filename infix used when deriving default output paths, e.g. `mywallet_info_<ts>.action`.
    /// Matches the slugs used by the bash script for parity.
    var fileSlug: String {
        switch self {
            case .infoAction: return "info"
            case .treasuryWithdrawal: return "treasury-withdrawal"
            case .noConfidence: return "no-confidence"
            case .newConstitution: return "new-constitution"
            case .hardForkInitiation: return "hardfork"
            case .updateCommittee: return "update-committee"
            case .parameterChange: return "parameter-change"
        }
    }
}

/// User-facing vote choice. Maps 1:1 to `SwiftCardanoCore.Vote` via `asCoreVote`.
enum VoteChoice: String, CaseIterable, ExpressibleByArgument, AlignedChoiceDescribable {
    case yes
    case no
    case abstain

    var name: String {
        switch self {
            case .yes: return "Yes"
            case .no: return "No"
            case .abstain: return "Abstain"
        }
    }

    var details: String {
        switch self {
            case .yes: return "Vote YES to ratify the governance action."
            case .no: return "Vote NO to reject the governance action."
            case .abstain: return "Abstain — vote does not count toward the ratio numerator but still records participation."
        }
    }

    var asCoreVote: SwiftCardanoCore.Vote {
        switch self {
            case .yes: return .yes
            case .no: return .no
            case .abstain: return .abstain
        }
    }
}
