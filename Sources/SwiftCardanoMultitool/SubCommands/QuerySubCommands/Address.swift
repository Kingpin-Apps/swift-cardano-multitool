import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoChain

extension QueryMainCommand {
    struct Address: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Query UTxOs for an address.")
        
        @Option(name: .shortAndLong, help: "The address to query.")
        var addressInfo: AddressInfo? = nil
        
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
                    let address = try await resolveAdahandle(
                        handle: adahandle,
                        network: config.cardano.network
                    )
                    addressInfo = try AddressInfo(adaHandle: adahandle, address: address)
                case .address:
                    let addressString = noora.textPrompt(
                        title: "Address",
                        prompt: "Enter the address in Bech32  or Hex format:",
                        description: "The address must be a valid Cardano address."
                    )
                    
                    let address = try SwiftCardanoCore.Address(from: .string(addressString))
                    addressInfo = try AddressInfo(address: address)
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
                    
                    let address = try SwiftCardanoCore.Address.load(from: addressFile.string)
                    addressInfo = try AddressInfo(addressFile: addressFile, address: address)
            }
        }

        
        mutating func run() async throws {
            if addressInfo == nil {
                try await wizard()
            }
            
            guard var addressInfo = addressInfo,
            var address = addressInfo.address else {
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
            
            try await printInfo(config: config, context: context)
            
            if addressInfo.adaHandle != nil, addressInfo.address == nil {
                do {
                    try await addressInfo.checkAdaHandle(network: config.cardano.network)
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
                throw ExitCode.failure
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
                throw ExitCode.failure
            }
            
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
                case .stake:
                    
                    spacedPrint(
                        "Checking Rewards on Stake-Address \(.primary(name)): \(.primary(try address.toBech32()))"
                    )
                    
                    try await addressInfo.updateStakeAddressInfo(context: context)
                    
                    guard !addressInfo.stakeAddressInfo.isEmpty,
                          let stakeAddressInfo = addressInfo.stakeAddressInfo.first else {
                        noora.error(.alert(
                            "Stake Registration: \(.danger("✗ Not Registered"))",
                            takeaways: [
                                "Register the stake address before withdrawing rewards.",
                                "Use 'generate stake-address-registration' command to register."
                            ]
                        ))
                        throw ExitCode.failure
                    }
                    
                    print(noora.format(
                        "Staking Address is \(.success("✓ Registered")) on the chain with a deposit of \(.primary("\(String(describing: stakeAddressInfo.stakeRegistrationDeposit))")) lovelaces\n"
                    ))
                    
                    if stakeAddressInfo.rewardAccountBalance == 0 {
                        noora.warning(.alert(
                            "Rewards Balance: \(.danger("0 lovelaces"))",
                            takeaway: "No rewards available to withdraw. \nWait for rewards to accumulate before claiming."
                            
                        ))
                    } else {
                        print(noora.format(
                            "Rewards Balance: \(.primary(lovelaceToAdaString(UInt64(stakeAddressInfo.rewardAccountBalance)))) \(.muted("(\(stakeAddressInfo.rewardAccountBalance) lovelaces)"))"
                        ))
                    }
                    
                    
                    // If delegated to a pool, show the current pool ID
                    if let poolOperator = stakeAddressInfo.stakeDelegation {
                        print(noora.format(
                            "Account is delegated to a Pool with ID: \(.primary(try poolOperator.id()))"
                        ))
                        
                        let koiosContext = try await KoiosChainContext(
                            apiKey: config.koiosApiKey,
                            network: config.cardano.network
                        )
                        
                        let poolInfo = try await noora.progressStep(
                            message: "Fetching stake pool info...",
                            successMessage: "Successfully retrieved stake pool info.",
                            errorMessage: "Failed to retrieve stake pool info.",
                            showSpinner: true
                        ) { updateMessage in
                            return try await withRetry() {
                                try await koiosContext.poolInfo(poolIds: [poolOperator.id()])
                            }
                        }
                        
                        if let poolDetails = poolInfo.first {
                            noora.info(.alert(
                                "Delegated Stake Pool Details:",
                                takeaways: [
                                    "Name: \(poolDetails.metaJson?.name ?? "N/A")",
                                    "Ticker: \(poolDetails.metaJson?.ticker ?? "N/A")",
                                    "Status: \(String(describing: poolDetails.poolStatus ?? .none))",
                                    "Pledge: \(poolDetails.pledge ?? "N/A")",
                                    "Live Pledge: \(poolDetails.livePledge ?? "N/A")",
                                    "Live Stake: \(poolDetails.liveStake ?? "N/A")",
                                    "Block Count: \(poolDetails.blockCount ?? 0)"
                                ]
                            ))
                        } else {
                            noora.warning(.alert(
                                "Failed to retrieve details for stake pool ID: \(try poolOperator.id())"
                            ))
                        }
                    } else {
                        print(noora.format(
                            "\(.danger("Account is not delegated to a Pool."))"
                        ))
                    }
                    
                    
                    // Show the current status of the voteDelegation
                    if let voteDelegation = stakeAddressInfo.voteDelegation {
                        
                        spacedPrint(
                            "DRep Delegation: \(.success("✓ Delegated")))"
                        )
                        
                        switch voteDelegation.credential {
                            case .alwaysNoConfidence:
                                noora.info(.alert(
                                    "Voting-Power of Staking Address is currently set to: \(.primary("ALWAYS NO CONFIDENCE"))"
                                ))
                            case .alwaysAbstain:
                                noora.info(.alert(
                                    "Voting-Power of Staking Address is currently set to: \(.primary("ALWAYS ABSTAIN"))"
                                ))
                            case .scriptHash(let scriptHash):
                                noora.info(.alert(
                                    "Voting-Power of Staking Address is delegated to the following DRep-Script:",
                                    takeaways: [
                                        "CIP129 DRep-ID: \(.primary(try voteDelegation.id((.bech32, .cip129))))",
                                        "Legacy DRep-ID: \(.primary(try voteDelegation.id((.bech32, .cip105))))",
                                        "DRep-HASH: \(.primary(try voteDelegation.id((.hex, .cip105))))",
                                    ]
                                ))
                            case .verificationKeyHash(let vkeyHash):
                                let drepId = try voteDelegation.id((.bech32, .cip129))
                                noora.info(.alert(
                                    "Voting-Power of Staking Address is delegated to the following DRep: \(.primary(drepId))",
                                    takeaways: [
                                        "CIP129 DRep-ID: \(.primary(try voteDelegation.id((.bech32, .cip129))))",
                                        "Legacy DRep-ID: \(.primary(try voteDelegation.id((.bech32, .cip105))))",
                                        "DRep-HASH: \(.primary(try voteDelegation.id((.hex, .cip105))))",
                                    ]
                                ))
                        }
                    } else {
                        
                        print(noora.format(
                            "\(.danger("Voting-Power of Staking Address is not delegated to a DRep."))"
                        ))
                        
                        let context = try await getContext(config: config)
                        let protocolParams = try await noora.progressStep(
                            message: "Querying protocol parameters...",
                            successMessage: "Successfully retrieved protocol parameters.",
                            errorMessage: "Failed to retrieve protocol parameters.",
                            showSpinner: true
                        ) { updateMessage in
                            return try await context.protocolParameters()
                        }
                        
                        if protocolParams.protocolVersion.major >= 10 {
                            noora.error(.alert(
                                "\(.danger("⚠️  You need to delegate your stake account to a DRep in order to claim your rewards!"))",
                                takeaways: [
                                    "Run the appropriate generate and register command to delegate your stake account to a DRep."
                                ]
                            ))
                        }
                    }
                    
                    if let govActionDeposits = stakeAddressInfo.govActionDeposits,
                       govActionDeposits.isEmpty == false {
                        noora.info(.alert(
                            "👀 Staking Address is used in the following \(govActionDeposits.count) governance action(s):",
                            takeaways: try govActionDeposits
                                .map({ (key: String, value: UInt64) in
                                    let govActionID = try GovActionID(from: .list([.string(key), .uint(UInt(value))]))
                                    return "\(.primary(try govActionID.id())) -> \(.primary("\(lovelaceToAdaString(value)) deposit"))"
                                })
                        ))
                    }
            }
        }
    }
}
