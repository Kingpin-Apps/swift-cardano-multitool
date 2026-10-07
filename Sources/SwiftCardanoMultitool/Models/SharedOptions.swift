import Foundation
import ArgumentParser
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftCardanoChain
import SwiftCardanoTxBuilder


struct SharedCertificateOptions: ParsableArguments {
    
    // MARK: - CertificateCommandable Arguments
    
    @Option(name: [.short, .long], help: "The file name to save the certificate to. If not specified, '{addressName}-{timestamp}.{type}.cert' will be used.")
    var outFile: FilePath? = nil
    
    @Flag(name: [.short, .long], help: "Whether to generate a transaction for the certificate")
    var generateTransaction: Bool = false
}


struct SharedTransactionOptions: ParsableArguments {
    // MARK: - TransactionCommandable Arguments
    
    @Option(name: [.short, .long], help: "Destination for rewards. Accepts: bech32 address, file base name, payment key hash, or $adahandle")
    var toAddress: PaymentAddressInfo?
    
    @Option(name: [.short, .long], help: "Address to pay transaction fees from. Accepts: bech32 address, file base name (resolves <name>.payment.addr, then <name>.addr), or $adahandle")
    var feePaymentAddress: PaymentAddressInfo?
    
    @Option(name: [.short, .customLong("message")], parsing: .upToNextOption, help: "Transaction message(s). Max 64 bytes each. Can be specified multiple times.")
    var messages: [String] = []
    
    @Option(name: .long, help: "Message encryption mode. Options: basic")
    var encryption: TransactionMessage.EncryptionMode?
    
    @Option(name: .long, help: "Passphrase for message encryption (default: cardano)")
    var passphrase: String = "cardano"
    
    @Option(name: .long, parsing: .upToNextOption, help: "Path(s) to JSON metadata file(s). Can be specified multiple times.")
    var metadataJson: [FilePath] = []
    
    @Option(name: .long, parsing: .upToNextOption, help: "Path(s) to CBOR metadata file(s). Can be specified multiple times.")
    var metadataCbor: [FilePath] = []
    
    @Option(name: .long, parsing: .upToNextOption, help: "Specific UTXOs to use. Format: txHash#index. Can be specified multiple times.")
    var utxoFilter: [String] = []
    
    @Option(name: .long, help: "Maximum number of input UTXOs to use (positive integer)")
    var utxoLimit: Int?
    
    @Option(name: .long, parsing: .upToNextOption, help: "Skip UTXOs containing these assets. Format: policyId+assetNameHex. Can be specified multiple times.")
    var skipUtxoWithAsset: [String] = []
    
    @Option(name: .long, parsing: .upToNextOption, help: "Only use UTXOs containing these assets. Format: policyId+assetNameHex. Can be specified multiple times.")
    var onlyUtxoWithAsset: [String] = []
    
    @Flag(help: "Use cardano-cli to build the transaction (default: use SwiftCardano)")
    var useCardanoCLI = false
    
    @Flag(inversion: .prefixedNo, help: "Save built transaction to file")
    var save = true
    
    @Flag(inversion: .prefixedNo, help: "Sign the transaction after building. Use --no-sign to leave it unsigned (e.g. for offline signing).")
    var sign = true

    @Flag(help: "Submit the transaction to the blockchain (requires signing)")
    var submit = false

    // MARK: - Time To Live

    @Option(name: .long, help: "Extra slots added to the chain tip when computing the TTL (invalid-hereafter). Defaults to the configured ttl_buffer.")
    var ttlExtra: UInt64?

    @Option(name: .long, help: "Override the TTL with an absolute slot (skips tip + extra computation).")
    var ttlOverride: UInt64?

    @Flag(name: .customLong("no-ttl"), help: "Build the transaction without a TTL so it never expires.")
    var noTTL = false
}

extension SharedTransactionOptions {
    /// True when a TTL flag was given on the command line, so the wizard must not ask.
    var hasTTLArguments: Bool {
        ttlExtra != nil || ttlOverride != nil || noTTL
    }

    /// Throws when the TTL flags contradict each other.
    func validateTTL() throws {
        let given = [ttlExtra != nil, ttlOverride != nil, noTTL].filter { $0 }.count
        guard given <= 1 else {
            throw ValidationError("--ttl-extra, --ttl-override and --no-ttl cannot be combined.")
        }
    }

    /// Store a wizard answer in the same fields the command-line flags use.
    mutating func set(ttlChoice: TTLChoice) {
        ttlExtra = nil
        ttlOverride = nil
        noTTL = false
        switch ttlChoice {
        case .tipPlus(let extra): ttlExtra = extra
        case .absolute(let slot): ttlOverride = slot
        case .never: noTTL = true
        }
    }

    /// The absolute TTL slot for a transaction built at `tip`, or nil when it should never
    /// expire. Without any TTL flag the chain tip plus the configured `ttl_buffer` is used.
    func ttl(tip: Int, config: MultitoolConfig) throws -> UInt64? {
        if noTTL { return nil }
        if let ttlOverride { return ttlOverride }
        let extra = try ttlExtra ?? UInt64(getCardanoConfig(config: config).ttlBuffer)
        return UInt64(tip) &+ extra
    }
}
