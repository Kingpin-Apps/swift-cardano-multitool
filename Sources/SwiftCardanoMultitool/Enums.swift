import ArgumentParser

public enum LogLevel: String, CaseIterable, CodingKeyRepresentable, Codable, Hashable, Sendable {
    case info = "info"
    case debug = "debug"
    case warn = "warn"
    case error = "error"
}

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
