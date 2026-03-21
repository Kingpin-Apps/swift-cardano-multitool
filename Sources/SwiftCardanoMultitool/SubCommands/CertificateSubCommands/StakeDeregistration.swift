import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftCardanoChain
import SwiftCardanoTxBuilder


extension CertificateMainCommand {
    
    struct StakeDeregistration: CertificateCommandable {
        static let configuration = CommandConfiguration(
            abstract: "Generates a stake address deregistration certificate.",
            usage: """
            scm certificate stake-deregistration --stake-address test
            """,
            discussion: """
            Creates a stake address deregistration certificate named 
            name.stake.dereg-cert to deregister a stake address from the 
            blockchain. The stake address must be provided in a file named 
            name.stake.addr. If the `--generate-transaction` flag is used, a 
            transaction will also be created to submit the certificate on-chain,
            with the fee paid by the specified fee payment address.
            """,
            aliases: ["stake-dereg"]
        )
        
        // MARK: - Required Arguments
        
        @Option(name: [.short, .long], help: "Stake address file name. Example: owner → owner.stake.addr or owner.stake, or owner.addr")
        var stakeAddress: StakeAddressInfo?
        
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
            stakeAddress = try await getStakeAddress(title: "Stake Address to deregister")
            
            try await self.wizardForCertificate()
            
            if certificateOptions.generateTransaction {
                try await self.wizardForTransaction()
            }
            
            try self.validate()
        }

        
        mutating func run() async throws {
            // Run wizard if required parameters are missing
            if stakeAddress == nil {
                try await wizard()
            }
            
            guard var stakeAddress = stakeAddress else {
                noora.error(.alert(
                    "Stake address is required.",
                    takeaways: ["Provide a valid stake address base name."]
                ))
                throw ExitCode.validationFailure
            }
            
            let config = try await MultitoolConfig.load()
            let context = try await getContext(config: config)
            try await printContextInfo(config: config, context: context)
            
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
                certificateOptions.outFile = cwd.appending("\(stakeVkeyFilePath.stem!)-\(timestamp).stake-dereg.cert")
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
                "\nGenerating stake deregistration certificate for: \(.primary(stakeAddress.info.name!))"
            ))
            
            if stakeAddress.info.type != .stake {
                noora.error(.alert(
                    "The provided address (\(.primary("\(stakeAddress.info.address!)"))) is not a stake address.",
                    takeaways: [
                        "Provide a valid stake address file."
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
            
            spacedPrint(
                "\n\(.primary("━━━ Stake Address Info ━━━"))\n"
            )
            
            try await stakeAddress.info.updateStakeAddressInfo(context: context)
            
            stakeAddress.info.addressTypeEra()
            
            guard stakeAddress.info.stakeAddressInfo.count != 0 else {
                noora.warning(
                    "Stake Address is not registered on the chain."
                )
                throw ExitCode.validationFailure
            }
            
            try await stakeAddressInfoSummary(
                stakeAddressInfo: stakeAddress.info.stakeAddressInfo,
                config: config,
                protocolParams: protocolParams
            )
            
            let depositFee = protocolParams.stakeAddressDeposit
            
            do {
                if transactionOptions.useCardanoCLI {
                    let logger = getLogger(config: config)
                    let cli = try await CardanoCLI(
                        configuration: config.toSwiftCardanoUtilsConfig(),
                        logger: logger
                    )
                    
                    let era = try await cli.getEra()
                    
                    guard let era else {
                        noora.error(.alert(
                            "Failed to determine the current era from Cardano CLI.",
                            takeaways: [
                                "Ensure Cardano CLI is properly configured and connected to a node."
                            ]
                        ))
                        throw ExitCode.failure
                    }
                    
                    if [.babbage, .alonzo, .mary, .allegra, .shelley].contains(era) {
                        spacedPrint(
                            "Generate Deregistration-Certificate in \(.primary("\(era)")) format."
                        )
                        _ = try await cli.stakeAddress
                            .deregistrationCertificate(arguments: [
                                "--stake-address", stakeAddress.info.address!.toBech32(),
                                "--out-file", outFile.string
                            ])
                    } else {
                        spacedPrint(
                            "Generate Registration-Certificate with the currently set deposit fee: \(.primary("\(depositFee)")) lovelaces."
                        )
                        _ = try await cli.stakeAddress
                            .deregistrationCertificate(arguments: [
                                "--stake-address", stakeAddress.info.address!.toBech32(),
                                "--key-reg-deposit-amt", "\(depositFee)",
                                "--out-file", outFile.string
                            ])
                    }
                }
                else {
                    let stakeVkey = try StakeVerificationKey.load(
                        from: stakeVkeyFilePath.string
                    )
                    let stakeCredential = StakeCredential(
                        credential: .verificationKeyHash(try stakeVkey.hash())
                    )
                    
                    let era = try await context.era()
                    
                    guard let era else {
                        noora.error(.alert(
                            "Failed to determine the current era from \(.primary("\(context.name)"))."
                        ))
                        throw ExitCode.failure
                    }
                    
                    if [.babbage, .alonzo, .mary, .allegra, .shelley].contains(era) {
                        spacedPrint(
                            "Generate Deregistration-Certificate in \(.primary("\(era)")) format."
                        )
                        let stakeRegistrationCertificate = SwiftCardanoCore.StakeDeregistration(
                            stakeCredential: stakeCredential
                        )
                        try stakeRegistrationCertificate.save(to: outFile.string)
                    } else {
                        spacedPrint(
                            "Generate Deregistration-Certificate with the currently set deposit fee: \(.primary("\(depositFee)")) lovelaces."
                        )
                        let stakeRegistrationCertificate = Unregister(
                            stakeCredential: stakeCredential,
                            coin: Coin(depositFee)
                        )
                        try stakeRegistrationCertificate.save(to: outFile.string)
                    }
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
                "Stake Address Deregistration certificate created successfully.",
                takeaways: [
                    "File: \(outFile.string)",
                    "This certificate deregisters the stake address: \(.primary(try stakeAddress.info.address!.toBech32()))",
                    "Associated with \(stakeVkeyFilePath.string).",
                    "Include this certificate when building your transaction to activate the deregistration."
                ]
            ))
            
            // Display results
            try await FileUtils.displayFile(outFile)
            
            // Generate transaction if requested
            if certificateOptions.generateTransaction {
                let logger = getLogger(config: config)
                let txBuilder = TxBuilder(context: context, logger: logger)
                
                let stakeRegistrationCertificate = try SwiftCardanoCore.StakeRegistration.load(
                    from: outFile.string
                )
                txBuilder.certificates = [
                    .stakeRegistration(stakeRegistrationCertificate)
                ]
                
                guard let feePaymentAddress = transactionOptions.feePaymentAddress else {
                    noora.error(.alert(
                        "Fee payment address is required to generate the transaction.",
                        takeaways: ["Provide a valid fee payment address."]
                    ))
                    throw ExitCode.validationFailure
                }
                
                let signingKeys: [String] = [
                    try stakeAddress.info.getSigningMethod().path.string,
                    try feePaymentAddress.info.getSigningMethod().path.string
                ]
                
                spacedPrint(
                    "\nSubmit Stake Address Deregistration Certificate \(.primary("\(outFile.string)")) with funds from Address \(.primary("\(feePaymentAddress.info.name!)"))"
                )
                
                spacedPrint(
                    "Stake Address Deposit Fee: \(.primary("\(lovelaceToAdaFormatString(UInt64(depositFee)))")) / \(depositFee) lovelaces."
                )
                
                // Transaction file paths
                let timestamp = DateUtils.getCurrentTimestamp()
                let txRawFile = cwd.appending("\(feePaymentAddress.info.name!)-\(timestamp).raw.tx")
                let txFile = cwd.appending("\(feePaymentAddress.info.name!)-\(timestamp).tx")
                let txSignedFile = cwd.appending("\(feePaymentAddress.info.name!)-\(timestamp).signed.tx")
                
                try await buildTransaction(
                    txBuilder: txBuilder,
                    config: config,
                    witnessOverride: signingKeys.count,
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
                
                let signingKeysArgs: [String] = signingKeys.flatMap {
                    ["--signing-key-file", $0]
                }
                
                await TransactionMainCommand.Sign.main([
                    "--tx-file", txFile.string,
                    "--out-file", txSignedFile.string,
                ] + args + signingKeysArgs)
                
                if !transactionOptions.save {
                    try FileManager.default.removeItem(atPath: txRawFile.string)
                    try FileManager.default.removeItem(atPath: txFile.string)
                    try FileManager.default.removeItem(atPath: txSignedFile.string)
                }
            }
            
            
        }
    }
}
