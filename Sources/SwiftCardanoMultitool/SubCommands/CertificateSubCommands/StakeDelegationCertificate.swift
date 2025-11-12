import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftCardanoChain
import SwiftCardanoTxBuilder
import SwiftKoios

extension CertificateMainCommand {
    
    struct StakeDelegationCertificate: CertificateCommandable {
        static let configuration = CommandConfiguration(
            abstract: "Generates the delegation certificate name.deleg.cert to delegate stake to a stakepool."
        )
        
        // MARK: - Required Arguments
        
        @Option(name: [.short, .long], help: "Stake address file name. Example: owner → owner.stake.addr or owner.stake, or owner.addr")
        var stakeAddress: StakeAddressInfo?
        
        @Option(name: [.short, .long], help: "The pool operator (PoolOperator) to delegate to. Supports: bech32 (pool1...), hex hash, .node.vkey file.")
        var poolOperator: PoolOperator?
        
        // MARK: - CertificateCommandable Arguments
        
        @OptionGroup var certificateOptions: SharedCertificateOptions
        
        // MARK: - TransactionCommandable Arguments
        
        @OptionGroup var transactionOptions: SharedTransactionOptions
        
        // MARK: - Validation
        
        mutating func validate() throws {
            try self.validateForTransaction()
        }
        
        // MARK: - Wizard
        
        /// Interactive wizard to gather missing parameters
        mutating func wizard() async throws {
            stakeAddress = try await getStakeAddress(title: "Stake Address to register")
            
            poolOperator = try await getPoolOperator()
            
            try await self.wizardForCertificate()
            
            if certificateOptions.generateTransaction {
                try await self.wizardForTransaction()
            }
            
            try self.validate()
        }
        
        // MARK: - Run
        
        mutating func run() async throws {
            // Run wizard if required parameters are missing
            if stakeAddress == nil || poolOperator == nil {
                try await wizard()
            }
            
            guard var stakeAddress = stakeAddress else {
                noora.error(.alert(
                    "Stake address is required.",
                    takeaways: ["Provide a valid stake address base name."]
                ))
                throw ExitCode.validationFailure
            }
            
            guard let poolOperator = poolOperator else {
                noora.error(.alert(
                    "Pool Operator is required.",
                    takeaways: ["Provide a valid Pool Operator identifier."]
                ))
                throw ExitCode.validationFailure
            }
            
            let config = try await MultitoolConfig.load()
            let context = try await getContext(config: config)
            try await printInfo(config: config, context: context)
            
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let timestamp = DateUtils.getCurrentTimestamp()
            
            let stakeVkeyFilePath = try stakeAddress.info.getVerificationKey()
            
            // Validate stake vkey file exists
            do {
                try FileUtils.checkFileExists(stakeVkeyFilePath)
            } catch {
                noora.error(.alert(
                    "Failed to access stake verification key: \(stakeVkeyFilePath.string)",
                    takeaways: ["Ensure the file exists and is readable."]
                ))
                throw ExitCode.validationFailure
            }
            
            // Output certificate path
            if certificateOptions.outFile == nil {
                certificateOptions.outFile = cwd.appending("\(stakeVkeyFilePath.stem!)-\(timestamp).deleg.cert")
            }
            
            guard let outFile = certificateOptions.outFile else {
                noora.error(.alert(
                    "Output file path is invalid.",
                    takeaways: ["Provide a valid output file path for the certificate."]
                ))
                throw ExitCode.validationFailure
            }
            
            // Ensure certificate doesn't already exist
            do {
                try await FileUtils.checkFile(outFile)
            } catch {
                noora.error(.alert(
                    "Output file already exists: \(outFile.string)",
                    takeaways: ["\(error.localizedDescription)"]
                ))
                throw ExitCode.validationFailure
            }
            
            print(noora.format(
                "Generating stake delegation certificate for: \(.primary(stakeAddress.info.name!))"
            ))
            
            print(noora.format(
                "• Stake Vkey: \(.path(try .init(validating: stakeVkeyFilePath.string)))"
            ))
            print(noora.format(
                "• Pool ID: \(.primary("\(try poolOperator.id())"))"
            ))
            print(noora.format(
                "• Output: \(.path(try .init(validating: outFile.string)))"
            ))
            print()
            
            do {
                if transactionOptions.useCardanoCLI {
                    // Initialize CardanoCLI
                    let logger = getLogger(config: config)
                    let cli = try await CardanoCLI(
                        configuration: config.toSwiftCardanoUtilsConfig(),
                        logger: logger
                    )
                    
                    // Build cardano-cli arguments
                    let arguments = [
                        "--stake-verification-key-file", stakeVkeyFilePath.string,
                        "--stake-pool-id", try poolOperator.id(),
                        "--out-file", outFile.string
                    ]
                    
                    // Generate certificate
                    do {
                        // Unlock certificate file if it exists (shouldn't, but be safe)
                        try await FileUtils.unlockIfExists(outFile)
                        
                        // Execute cardano-cli command
                        _ = try await cli.stakeAddress.stakeDelegationCertificate(
                            arguments: arguments
                        )
                        
                        // Lock the certificate file (set to 0400)
                        try await FileUtils.fileLock(outFile)
                        
                    } catch {
                        noora.error(.alert(
                            "Failed to generate stake delegation certificate.",
                            takeaways: [
                                "Error: \(error.localizedDescription)",
                                "Ensure your cardano-cli supports Conway era governance commands.",
                                "Verify the stake verification key file is valid.",
                                "Verify the Pool identifier is correct.",
                                "Check that your network is in Conway era (or later)."
                            ]
                        ))
                        throw ExitCode.failure
                    }
                    
                } else {
                    let stakeVkey = try StakeVerificationKey.load(
                        from: stakeVkeyFilePath.string
                    )
                    let stakeCredential = StakeCredential(
                        credential: .verificationKeyHash(try stakeVkey.hash())
                    )
                    let stakeDelegationCertificate = StakeDelegation(
                        stakeCredential: stakeCredential,
                        poolKeyHash: poolOperator.poolKeyHash
                    )
                    try stakeDelegationCertificate
                        .save(to: outFile.string, overwrite: true)
                }
            } catch {
                noora.error(.alert(
                    "Could not write out the certificate file \(.primary("\(outFile.string)"))!",
                    takeaways: [
                        "\(error)"
                    ]
                ))
                throw ExitCode.failure
            }
            
            // Success message
            noora.success(.alert(
                "Stake Delegation certificate created successfully.",
                takeaways: [
                    "File: \(outFile.string)",
                    "This certificate delegates stake from stake address \(.primary(try stakeAddress.info.address!.toBech32())) to the Pool \(.primary(try poolOperator.id())).",
                    "Associated with \(stakeVkeyFilePath.string).",
                    "Include this certificate when building your transaction to activate the delegation."
                ]
            ))
            
            // Display results
            try await FileUtils.displayFile(outFile)
            
            // Generate transaction if requested
            if certificateOptions.generateTransaction {
                let logger = getLogger(config: config)
                let txBuilder = TxBuilder(context: context, logger: logger)
                
                let stakeDelegationCertificate = try StakeDelegation.load(
                    from: outFile.string
                )
                txBuilder.certificates = [
                    .stakeDelegation(stakeDelegationCertificate)
                ]
                
                guard let feePaymentAddress = transactionOptions.feePaymentAddress else {
                    noora.error(.alert(
                        "Fee payment address is required to generate the transaction.",
                        takeaways: ["Provide a valid fee payment address."]
                    ))
                    throw ExitCode.validationFailure
                }
                
                spacedPrint(
                    "\nSubmit Stake Delegation Certificate \(.primary("\(outFile.string)")) with funds from Address \(.primary("\(feePaymentAddress.info.name!)"))"
                )
                
                noora.info(.alert(
                    "Delegating stake of \(.primary("\(stakeAddress.info.name!)")) to Pool with the following details:",
                    takeaways: [
                        "• Pool ID Hex: \(.primary("\(try poolOperator.id(.hex))"))",
                        "• Pool ID Bech32: \(.primary("\(try poolOperator.id(.bech32))"))"
                    ]
                ))
                
                let poolInfo: Components.Schemas.PoolInfo?
                if [.online, .auto, .lite].contains(config.mode),
                    let koiosApiKey = config.koiosApiKey {
                    let koiosContext = try await KoiosChainContext(
                        apiKey: koiosApiKey,
                        network: config.cardano.network
                    )
                    
                    poolInfo = try await noora.progressStep(
                        message: "Fetching stake pool info...",
                        successMessage: "Successfully retrieved stake pool info.",
                        errorMessage: "Failed to retrieve stake pool info.",
                        showSpinner: true
                    ) { updateMessage in
                        return try await withRetry() {
                            try await koiosContext.poolInfo(poolIds: [poolOperator.id()])
                        }
                    }
                    
                    if let poolInfo = poolInfo,
                       let poolDetails = poolInfo.first {
                        noora.info(.alert(
                            "Stake Pool Details:",
                            takeaways: [
                                "Name: \(poolDetails.metaJson?.name ?? "N/A")",
                                "Ticker: \(poolDetails.metaJson?.ticker ?? "N/A")",
                                "Status: \(poolDetails.poolStatus!)",
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
                    poolInfo = nil
                }
                
                if let context = context as? CardanoCliChainContext {
                    
                    do {
                        let stakePools = try await context.stakePools()
                        
                        if !stakePools.contains(try poolOperator.id()) {
                            noora.error(.alert(
                                "The specified Pool ID \(try poolOperator.id()) was not found in the stake pool list from the chain.",
                                takeaways: [
                                    "Ensure the Pool ID is correct.",
                                    "The pool may not be registered on the network yet.",
                                    "Verify your network context supports stake pool queries."
                                ]
                            ))
                        }
                    } catch {
                        noora.error(.alert(
                            "Unable to fetch stake pool list from the chain.",
                            takeaways: [
                                "Error: \(error.localizedDescription)",
                                "Ensure your network context supports stake pool queries.",
                                "You may need to verify your network connection or API access."
                            ]
                        ))
                        throw ExitCode.failure
                    }
                    
                }
                else if let poolInfo = poolInfo,
                       let poolDetails = poolInfo.first,
                        poolDetails.poolStatus != .registered {
                        noora.error(.alert(
                            "The specified Pool ID \(try poolOperator.id()) is currently \(poolDetails.poolStatus!), please register it first to do the delegation!",
                            takeaways: [
                                "Ensure the Pool ID is correct.",
                                "The pool may not be registered on the network yet."
                            ]
                        ))
                        
                }
                else {
                    noora.error(.alert(
                        "Unable to verify stake pool registration status. Pool is most likely NOT on the chain",
                        takeaways: [
                            "Ensure the Pool ID is correct.",
                            "You may need to verify your network connection or API access.",
                            "Register pool first to do the delegation!"
                        ]
                    ))
                }
                
                let protocolParamsFile = cwd.appending(
                    "protocol-parameters.json"
                )
                
                let protocolParams = try await getProtocolParameters(
                    context: context,
                    protocolParamsFile: protocolParamsFile
                )
                
                try await self.queryStakeAddressInfo(
                    stakeAddress: &stakeAddress,
                    context: context,
                    config: config,
                    protocolParams: protocolParams
                )
                
                // Transaction file paths
                let timestamp = DateUtils.getCurrentTimestamp()
                let txRawFile = cwd.appending("\(feePaymentAddress.info.name!)-\(timestamp).raw.tx")
                let txFile = cwd.appending("\(feePaymentAddress.info.name!)-\(timestamp).tx")
                let txSignedFile = cwd.appending("\(feePaymentAddress.info.name!)-\(timestamp).signed.tx")
                
                try await buildTransaction(
                    txBuilder: txBuilder,
                    config: config,
                    protocolParamsFile: protocolParamsFile,
                    txRawFile: txRawFile,
                    txFile: txFile,
                    txSignedFile: txSignedFile
                )
                
                var args: [String] = []
                if transactionOptions.useCardanoCLI {
                    args.append("--use-cardano-cli")
                }
                if transactionOptions.save {
                    args.append("--save")
                }
                if transactionOptions.submit {
                    args.append("--submit")
                }
                
                let signingKeys: [String] = [
                    "--signing-keys", try stakeAddress.info.getSigningMethod().path.string,
                    "--signing-keys", try feePaymentAddress.info.getSigningMethod().path.string
                ]
                await TransactionMainCommand.Sign.main([
                    "--tx-file", txFile.string,
                    "--out-file", txSignedFile.string,
                ] + args + signingKeys)
                
                if !transactionOptions.save {
                    try FileManager.default.removeItem(atPath: txRawFile.string)
                    try FileManager.default.removeItem(atPath: txFile.string)
                    try FileManager.default.removeItem(atPath: txSignedFile.string)
                }
            }
        }
    }
}
