import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoChain

extension QueryMainCommand {
    struct Address: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Query UTxOs for an address.")
        
        @Argument(help: "The address to query.")
        var address: AddressInfo? = nil
        
        /// Wizard to interactively gather missing parameters
        mutating func wizard() async throws {
            let enterAddressBy = try await enterAddressBy()
            
            switch enterAddressBy {
                case .adahandle:
                    let adahandle = noora.textPrompt(
                        title: "Address",
                        prompt: "Enter the address in Bech32  or Hex format:",
                        description: "The address must be a valid Cardano address."
                    )
                    let config = try await MultitoolConfig.load()
                    
                    let cardanoConfig = try getCardanoConfig(config: config)
                    
                    let resolvedAddress = try await resolveAdahandle(
                        handle: adahandle,
                        network: cardanoConfig.network
                    )
                    address = try AddressInfo(adaHandle: adahandle, address: resolvedAddress)
                case .address:
                    let addressString = noora.textPrompt(
                        title: "Address",
                        prompt: "Enter the address in Bech32  or Hex format:",
                        description: "The address must be a valid Cardano address."
                    )
                    
                    address = try AddressInfo(
                        address: try SwiftCardanoCore.Address(from: .string(addressString))
                    )
                case .path:
                    let cwd = FilePath(FileManager.default.currentDirectoryPath)
                    let addressFiles = try FileManager.default.contentsOfDirectory(atPath: cwd.string)
                        .filter { $0.hasSuffix(".addr") }
                    
                    let addressFile = FilePath(noora.singleChoicePrompt(
                        title: "Address File",
                        question: "Select the address file to use:",
                        options: addressFiles,
                        description: "Available .addr files in current directory"
                    ))
                    
                    address = try AddressInfo(
                        addressFile: addressFile,
                        address: try SwiftCardanoCore.Address.load(from: addressFile.string)
                    )
            }
        }
        
        
        mutating func run() async throws {
            if address == nil {
                try await wizard()
            }
            
            guard var addressInfo = address,
                  let address = addressInfo.address else {
                noora.error(
                    .alert(
                        "Address information is missing.",
                        takeaways: [
                            "Ensure you provide a valid address or adahandle.",
                            "You can also specify a file containing the address."
                        ]
                    )
                )
                throw ExitCode.validationFailure
            }
            
            let config = try await MultitoolConfig.load()
            
            let context = try await getContext(config: config)
            
            try await printContextInfo(config: config, context: context)
            
            let cardanoConfig = try getCardanoConfig(config: config)
            
            if addressInfo.adaHandle != nil, addressInfo.address == nil {
                do {
                    try await addressInfo.checkAdaHandle(network: cardanoConfig.network)
                } catch {
                    noora.error(
                        .alert(
                            "Address can't be resolved. \(error)",
                            takeaways: [
                                "Ensure the adahandle is correct and try again.",
                                "Filename may be wrong, or not a payment- or stake-address."
                            ]
                        )
                    )
                    throw ExitCode.failure
                }
            }
            
            guard let addressType = addressInfo.type else {
                noora.error(
                    .alert(
                        "Address type could not be determined.",
                        takeaways: [
                            "Ensure the address is correct and try again.",
                            "Filename may be wrong, or not a payment- or stake-address."
                        ]
                    )
                )
                throw ExitCode.validationFailure
            }
            
            guard let name = addressInfo.name else {
                noora.error(
                    .alert(
                        "Address name could not be determined.",
                        takeaways: [
                            "Ensure the address is correct and try again.",
                            "Filename may be wrong, or not a payment- or stake-address."
                        ]
                    )
                )
                throw ExitCode.validationFailure
            }
            
            let blockchainExplorer = config.blockchainExplorer.explorer(
                network: cardanoConfig.network
            )
            
            switch addressType {
                case .payment:
                    
                    spacedPrint(
                        "Checking UTXOs of Payment-Address \(.primary(name)): \(.primary(try address.toBech32()))"
                    )
                    
                    try await addressInfo.updateUTxOs(context: context)
                    
                    addressInfo.addressTypeEra()
                    
                    try await utxoSummary(
                        utxos: addressInfo.utxos,
                        config: config
                    )
                    
                    let addressURL = try blockchainExplorer.viewAddress(address: address)
                    
                    spacedPrint("\(.link(title:addressURL.absoluteString, href: addressURL.absoluteString))")
                    
                case .stake:
                    
                    spacedPrint(
                        "Checking Rewards on Stake-Address \(.primary(name)): \(.primary(try address.toBech32()))"
                    )
                    
                    try await addressInfo.updateStakeAddressInfo(context: context)
                    
                    addressInfo.addressTypeEra()
                    
                    let protocolParams = try await noora.progressStep(
                        message: "Querying protocol parameters...",
                        successMessage: "Successfully retrieved protocol parameters.",
                        errorMessage: "Failed to retrieve protocol parameters.",
                        showSpinner: true
                    ) { updateMessage in
                        return try await context.protocolParameters()
                    }
                    
                    try await stakeAddressInfoSummary(
                        stakeAddressInfo: addressInfo.stakeAddressInfo,
                        config: config,
                        protocolParams: protocolParams
                    )
                    
                    let addressURL = try blockchainExplorer.viewAccount(
                        address: address
                    )
                    
                    
                    spacedPrint("\(.link(title:addressURL.absoluteString, href: addressURL.absoluteString))")
                    
            }
        }
    }
}
