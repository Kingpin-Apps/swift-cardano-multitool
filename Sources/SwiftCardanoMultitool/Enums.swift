import ArgumentParser
import SwiftCardanoCore
import SystemPackage

public enum Mode: String, CaseIterable, CodingKeyRepresentable, Codable, Hashable , Sendable{
    case auto = "auto"
    case online = "online"
    case offline = "offline"
    case lite = "lite"
}

enum GetAddressBy: String, CaseIterable, CustomStringConvertible {
    case name
    case path
    
    var description: String {
        switch self {
            case .name:
                return "The name of the stem of the file."
            case .path:
                return "The path to the address.addr file."
        }
    }
}

enum GetTransactionBy: String, CaseIterable, CustomStringConvertible {
    case cborHex
    case path
    
    var description: String {
        switch self {
            case .cborHex:
                return "The CBOR Hex representation of the transaction."
            case .path:
                return "The path to the transaction file."
        }
    }
}

enum EnterAddressBy: String, CaseIterable, CustomStringConvertible {
    case adahandle
    case address
    case path
    
    var description: String {
        switch self {
            case .adahandle:
                return "The adahandle associated with the address."
            case .address:
                return "The address in Bech32 or Hex format."
            case .path:
                return "The path to the file containing the address."
        }
    }
}

enum EnterDRepBy: String, CaseIterable, CustomStringConvertible {
    case alwaysAbstain
    case alwaysNoConfidence
    case bech32
    case hex
    case path
    case vkey
    case skey
    case mnemonics
    
    var description: String {
        switch self {
            case .alwaysAbstain:
                return "Sets the DRep to always abstain."
            case .alwaysNoConfidence:
                return "Sets the DRep to always have no confidence."
            case .bech32:
                return "The DRep in Bech32 format."
            case .hex:
                return "The DRep in Hex format."
            case .path:
                return "The path to the file containing the DRep Id."
            case .vkey:
                return "The path to the verification key file."
            case .skey:
                return "The path to the signing key file."
            case .mnemonics:
                return "The mnemonics used to derive the DRep Id."
        }
    }
}

enum EnterPoolOperatorBy: String, CaseIterable, CustomStringConvertible {
    case bech32
    case hex
    case path
    case vkey
    case skey
    
    var description: String {
        switch self {
            case .bech32:
                return "The Pool Operator ID in Bech32 format."
            case .hex:
                return "The Pool Operator ID in Hex format."
            case .path:
                return "The path to the file containing the Pool Operator ID."
            case .vkey:
                return "The path to the verification key file."
            case .skey:
                return "The path to the signing key file."
        }
    }
}

enum EnterCommitteeColdCredentialBy: String, CaseIterable, CustomStringConvertible {
    case bech32
    case hex
    case vkey
    case skey

    var description: String {
        switch self {
            case .bech32:
                return "The Committee Cold Credential in Bech32 format (cc_cold1...)."
            case .hex:
                return "The Committee Cold Credential as a 56-character hex key hash."
            case .vkey:
                return "The path to the cold verification key file (.cc-cold.vkey)."
            case .skey:
                return "The path to the cold signing key file (.cc-cold.skey)."
        }
    }
}

enum EnterCommitteeHotCredentialBy: String, CaseIterable, CustomStringConvertible {
    case bech32
    case hex
    case vkey
    case skey

    var description: String {
        switch self {
            case .bech32:
                return "The Committee Hot Credential in Bech32 format (cc_hot1...)."
            case .hex:
                return "The Committee Hot Credential as a 56-character hex key hash."
            case .vkey:
                return "The path to the hot verification key file (.cc-hot.vkey)."
            case .skey:
                return "The path to the hot signing key file (.cc-hot.skey)."
        }
    }
}

enum EnterDRepCredentialBy: String, CaseIterable, CustomStringConvertible {
    case bech32
    case hex
    case vkey
    case skey

    var description: String {
        switch self {
            case .bech32:
                return "The DRep Credential in Bech32 format (drep1...)."
            case .hex:
                return "The DRep Credential as a 56-character hex key hash."
            case .vkey:
                return "The path to the DRep verification key file (.drep.vkey)."
            case .skey:
                return "The path to the DRep signing key file (.drep.skey)."
        }
    }
}

enum MoveInstantaneousRewardSourceOption: String, CaseIterable, CustomStringConvertible {
    case reserves
    case treasury

    var description: String {
        switch self {
            case .reserves:
                return "Reserves - Transfer from the reserves."
            case .treasury:
                return "Treasury - Transfer from the treasury."
        }
    }
}

public enum KeyGenMethod: String, CaseIterable, CustomStringConvertible, ExpressibleByArgument, Sendable, Codable, Hashable {

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
    
    public var description: String {
        switch self {
            case .cli:
                return "Keys generated using cardano-cli or SwiftCardano library."
            case .enc:
                return "Keys generated using cardano-cli or SwiftCardano library then encrypted using GnuPG."
            case .hw:
                return "Keys generated using Ledger/Trezor HW-Keys (Normal-Path 1852H/1815H/<Acc>/0,2/<Idx>)."
            case .hwMulti:
                return "Keys generated using Ledger/Trezor HW-Keys (MultiSig-Path 1854H/1815H/<Acc>/0,2/<Idx>)."
            case .hybrid:
                return "Payment keys using Ledger/Trezor HW-Keys, Staking keys via cardano-cli or SwiftCardano library (comfort mode for multiowner pools)."
            case .hybridEnc:
                return "Payment keys using Ledger/Trezor HW-Keys, Staking keys via cardano-cli or SwiftCardano library and encrypted via a Password."
            case .hybridMulti:
                return "Payment keys using Ledger/Trezor HW-Keys (MultiSig-Path 1854H/1815H/<Acc>/0/<Idx>), Staking keys via cliMultiSig hybrid keys generated."
            case .hybridMultiEnc:
                return "Payment keys using Ledger/Trezor HW-Keys (MultiSig-Path 1854H/1815H/<Acc>/0/<Idx>), Staking keys via cli and encrypted via a Password."
            case .mnemonics:
                return "Payment & Staking keys via cardano-cli or SwiftCardano library and also generates Mnemonics for LightWallet import possibilities."
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
