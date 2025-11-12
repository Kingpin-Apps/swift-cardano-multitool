import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftCardanoChain
import SwiftCardanoTxBuilder

extension CertificateMainCommand {
    
    struct VoteDelegation: CertificateCommandable {
        static let configuration = CommandConfiguration(
            abstract: "Generates the vote delegation certificate to delegate voting power to a DRep."
        )
        
        // MARK: - Required Arguments
        
        @Option(name: [.short, .long], help: "Stake address file name. Example: owner → owner.stake.addr or owner.stake, or owner.addr")
        var stakeAddress: StakeAddressInfo?
        
        @Option(name: [.short, .long], help: "The delegation representative (DRep) to delegate to. Supports: bech32 (drep1...), hex hash, .drep.vkey file, 'always-abstain', or 'always-no-confidence'.")
        var drep: DRep?
        
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
            stakeAddress = try await getStakeAddress(title: "Stake Address to delegate votes from")
            
            drep = try await getDRep()
            
            try await self.wizardForCertificate()
            
            if certificateOptions.generateTransaction {
                try await self.wizardForTransaction()
            }
            
            try self.validate()
        }
        
        // MARK: - Run
        
        mutating func run() async throws {
            // Run wizard if required parameters are missing
            if stakeAddress == nil || drep == nil {
                try await wizard()
            }
            
            guard let stakeAddress = stakeAddress else {
                noora.error(.alert(
                    "Stake address is required.",
                    takeaways: ["Provide a valid stake address base name."]
                ))
                throw ExitCode.validationFailure
            }
            
            guard let drep = drep else {
                noora.error(.alert(
                    "DRep is required.",
                    takeaways: ["Provide a valid DRep identifier."]
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
                certificateOptions.outFile = cwd.appending("\(stakeVkeyFilePath.stem!)-\(timestamp).vote-deleg.cert")
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
                "\nGenerating vote delegation certificate for: \(.primary(stakeAddress.info.name!))"
            ))
            
            // Echo resolved DRep information
            let drepDescription: String
            switch drep.credential {
                case .verificationKeyHash(let hash):
                    drepDescription = "DRep Key Hash: \(hash.payload.toHex)"
                case .scriptHash(let hash):
                    drepDescription = "DRep Script Hash: \(hash.payload.toHex)"
                case .alwaysAbstain:
                    drepDescription = "DRep: ALWAYS ABSTAIN"
                case .alwaysNoConfidence:
                    drepDescription = "DRep: ALWAYS NO CONFIDENCE"
            }
            
            print(noora.format(
                "  Stake Vkey: \(.path(try .init(validating: stakeVkeyFilePath.string)))"
            ))
            print(noora.format(
                "  \(drepDescription)"
            ))
            print(noora.format(
                "  Output: \(.path(try .init(validating: outFile.string)))"
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
                    var arguments = [
                        "--stake-verification-key-file", stakeVkeyFilePath.string
                    ]
                    
                    // Add DRep-specific arguments
                    switch drep.credential {
                        case .verificationKeyHash(let hash):
                            arguments.append(contentsOf: ["--drep-key-hash", hash.payload.toHex])
                            
                        case .scriptHash(let hash):
                            arguments.append(contentsOf: ["--drep-script-hash", hash.payload.toHex])
                            
                        case .alwaysAbstain:
                            arguments.append("--always-abstain")
                            
                        case .alwaysNoConfidence:
                            arguments.append("--always-no-confidence")
                    }
                    
                    // Add output file
                    arguments.append(contentsOf: ["--out-file", outFile.string])
                    
                    // Generate certificate
                    do {
                        // Unlock certificate file if it exists (shouldn't, but be safe)
                        try await FileUtils.unlockIfExists(outFile)
                        
                        // Execute cardano-cli command
                        _ = try await cli.stakeAddress.voteDelegationCertificate(
                            arguments: arguments
                        )
                        
                        // Lock the certificate file (set to 0400)
                        try await FileUtils.fileLock(outFile)
                        
                    } catch {
                        noora.error(.alert(
                            "Failed to generate vote delegation certificate.",
                            takeaways: [
                                "Error: \(error.localizedDescription)",
                                "Ensure your cardano-cli supports Conway era governance commands.",
                                "Verify the stake verification key file is valid.",
                                "Verify the DRep identifier is correct.",
                                "Check that your network is in Conway era (or later)."
                            ]
                        ))
                        throw ExitCode.failure
                    }
                }
                else {
                    let stakeVkey = try StakeVerificationKey.load(
                        from: stakeVkeyFilePath.string
                    )
                    let stakeCredential = StakeCredential(
                        credential: .verificationKeyHash(try stakeVkey.hash())
                    )
                    let voteDelegationCertificate = VoteDelegate(
                        stakeCredential: stakeCredential,
                        drep: drep
                    )
                    try voteDelegationCertificate
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
                "Vote Delegation certificate created successfully.",
                takeaways: [
                    "File: \(outFile.string)",
                    "This certificate delegates voting power from stake address \(.primary(try stakeAddress.info.address!.toBech32())) to the DRep \(try drep.id()).",
                    "Associated with \(stakeVkeyFilePath.string).",
                    "Include this certificate when building your transaction to activate the delegation."
                ]
            ))
            
            // Display results
            try await FileUtils.displayFile(outFile)
            
            if certificateOptions.generateTransaction {
                let logger = getLogger(config: config)
                let txBuilder = TxBuilder(context: context, logger: logger)
                
                let voteDelegationCertificate = try VoteDelegate.load(
                    from: outFile.string
                )
                txBuilder.certificates = [
                    .voteDelegate(voteDelegationCertificate)
                ]
                
                guard let feePaymentAddress = transactionOptions.feePaymentAddress else {
                    noora.error(.alert(
                        "Fee payment address is required to generate the transaction.",
                        takeaways: ["Provide a valid fee payment address."]
                    ))
                    throw ExitCode.validationFailure
                }
                
                spacedPrint(
                    "\nRegister Vote-Delegation Certificate \(.primary("\(outFile.string)")) with funds from Address \(.primary("\(feePaymentAddress.info.name!)"))"
                )
                
                let loadedDrep = voteDelegationCertificate.drep
                let drepHexId = try loadedDrep.id((.hex, .cip105))
                
                switch loadedDrep.credential {
                    case .verificationKeyHash(_):
                        noora.info(.alert(
                            "Delegating Voting-Power of \(.primary("\(stakeAddress.info.name!)")) to DRep with Hash: \(.primary("\(drepHexId)"))",
                            takeaways: [
                                "• CIP105 Bech-DRepID: \(.primary("\(try loadedDrep.id((.bech32, .cip105)))"))",
                                "• CIP129 Bech-DRepID: \(.primary("\(try loadedDrep.id((.bech32, .cip105)))"))"
                            ]
                        ))
                    case .scriptHash(_):
                        noora.info(.alert(
                            "Delegating Voting-Power of \(.primary("\(stakeAddress.info.name!)")) to DRep with Hash: \(.primary("\(drepHexId)"))",
                            takeaways: [
                                "• CIP105 Script-Bech-DRepID: \(.primary("\(try loadedDrep.id((.bech32, .cip105)))"))",
                                "• CIP129 Script-Bech-DRepID: \(.primary("\(try loadedDrep.id((.bech32, .cip105)))"))"
                            ]
                        ))
                    case .alwaysAbstain:
                        noora.info(.alert(
                            "Setting Voting-Power of \(.primary("\(stakeAddress.info.name!)")) to: \(.danger("ALWAYS ABSTAIN"))"
                        ))
                    case .alwaysNoConfidence:
                        noora.info(.alert(
                            "Setting Voting-Power of \(.primary("\(stakeAddress.info.name!)")) to: \(.danger("ALWAYS NO CONFIDENCE"))"
                        ))
                }
                print("\n")
                
                let protocolParamsFile = cwd.appending(
                    "protocol-parameters.json"
                )
                
                _ = try await getProtocolParameters(
                    context: context,
                    protocolParamsFile: protocolParamsFile
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
