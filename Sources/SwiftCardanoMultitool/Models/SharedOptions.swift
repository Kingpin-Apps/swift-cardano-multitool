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
    
    @Option(name: [.short, .long], help: "Address to pay transaction fees from.")
    var feePaymentAddress: PaymentAddressInfo?
    
    @Option(name: [.short, .long], parsing: .upToNextOption, help: "Transaction message(s). Max 64 bytes each. Can be specified multiple times.")
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
    
    @Flag(help: "Submit the transaction to the blockchain")
    var submit = false
}
