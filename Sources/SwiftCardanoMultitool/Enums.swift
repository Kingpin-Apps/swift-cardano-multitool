import ArgumentParser
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
                return "The path to the file."
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
