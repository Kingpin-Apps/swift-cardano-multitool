import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftCardanoChain
import SwiftCardanoTxBuilder

extension CertificateMainCommand {

    struct VoteRegisterDelegateCertificate: CertificateCommandable {
        static let configuration = CommandConfiguration(
            commandName: "vote-register-delegation",
            abstract: "Generates a stake registration and vote delegation certificate.",
            usage: """
            scm certificate vote-register-delegation --stake-address owner --drep drep1abc
            """,
            discussion: """
            Creates a combined stake address registration and vote delegation
            certificate. This Conway-era certificate registers the stake address
            on-chain and delegates its voting power to the specified DRep in a
            single operation. The stake address deposit is required. If the
            `--generate-transaction` flag is used, a transaction will also be
            created to submit the certificate on-chain.
            """,
            aliases: ["vote-reg-deleg"]
        )

        // MARK: - Required Arguments

        @Option(name: [.short, .long], help: "Stake address file name. Example: owner → owner.stake.addr")
        var stakeAddress: StakeAddressInfo?

        @Option(name: [.short, .long], help: "The DRep to delegate votes to. Supports: bech32 (drep1...), hex hash, .drep.vkey file, 'always-abstain', 'always-no-confidence'.")
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

        mutating func wizard() async throws {
            stakeAddress = try await getStakeAddress(title: "Stake Address to register")
            drep = try await getDRep()
            try await self.wizardForCertificate()
            if certificateOptions.generateTransaction {
                try await self.wizardForTransaction()
            }
            try self.validate()
        }

        // MARK: - Run

        mutating func run() async throws {
            if stakeAddress == nil || drep == nil {
                try await wizard()
            }

            let config = try await MultitoolConfig.load()
            let cardanoConfig = try getCardanoConfig(config: config)
            try await resolveAdaHandles(network: cardanoConfig.network)
            try await resolveStakeAdaHandle(&stakeAddress, network: cardanoConfig.network)

            guard let stakeAddress = stakeAddress else {
                noora.error(.alert("Stake address is required.", takeaways: ["Provide a valid stake address base name."]))
                throw ExitCode.validationFailure
            }
            guard let drep = drep else {
                noora.error(.alert("DRep is required.", takeaways: ["Provide a valid DRep identifier."]))
                throw ExitCode.validationFailure
            }

            let context = try await getContext(config: config)
            try await printContextInfo(config: config, context: context)

            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let timestamp = DateUtils.getCurrentTimestamp()
            let stakeVkeyFilePath = try stakeAddress.info.getVerificationKey()

            do {
                try FileUtils.checkFileExists(stakeVkeyFilePath)
            } catch {
                noora.error(.alert(
                    "Failed to access stake verification key: \(stakeVkeyFilePath.string)",
                    takeaways: ["Ensure the file exists and is readable."]
                ))
                throw ExitCode.validationFailure
            }

            if certificateOptions.outFile == nil {
                certificateOptions.outFile = cwd.appending("\(stakeVkeyFilePath.stem!)-\(timestamp).vote-reg-deleg.cert")
            }

            guard let outFile = certificateOptions.outFile else {
                noora.error(.alert("Output file path is invalid.", takeaways: ["Provide a valid output file path."]))
                throw ExitCode.validationFailure
            }

            do {
                try await FileUtils.checkFile(outFile)
            } catch {
                noora.error(.alert("Output file already exists: \(outFile.string)", takeaways: ["\(error.localizedDescription)"]))
                throw ExitCode.validationFailure
            }

            let protocolParamsFile = cwd.appending("protocol-parameters.json")
            let protocolParams = try await getProtocolParameters(context: context, protocolParamsFile: protocolParamsFile)
            let depositFee = protocolParams.stakeAddressDeposit

            print(noora.format("\nGenerating stake registration and vote delegation certificate for: \(.primary(stakeAddress.info.name!))"))
            spacedPrint("Stake Address Deposit: \(.primary("\(lovelaceToAdaFormatString(UInt64(depositFee)))")) / \(depositFee) lovelaces.")

            do {
                if transactionOptions.useCardanoCLI {
                    let logger = getLogger(config: config)
                    let cli = try await CardanoCLI(configuration: config.toSwiftCardanoUtilsConfig(), logger: logger)

                    var arguments = [
                        "--stake-verification-key-file", stakeVkeyFilePath.string,
                        "--key-reg-deposit-amt", "\(depositFee)"
                    ]
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
                    arguments.append(contentsOf: ["--out-file", outFile.string])

                    try await FileUtils.unlockIfExists(outFile)
                    _ = try await cli.stakeAddress.registrationAndVoteDelegationCertificate(arguments: arguments)
                    try await FileUtils.fileLock(outFile)
                } else {
                    let stakeVkey = try StakeVerificationKey.load(from: stakeVkeyFilePath.string)
                    let stakeCredential = StakeCredential(credential: .verificationKeyHash(try stakeVkey.hash()))
                    let cert = SwiftCardanoCore.VoteRegisterDelegate(
                        stakeCredential: stakeCredential,
                        drep: drep,
                        coin: Coin(depositFee)
                    )
                    try cert.save(to: outFile.string, overwrite: true)
                }
            } catch {
                noora.error(.alert(
                    "Could not write certificate file \(.primary(outFile.string))!",
                    takeaways: ["\(error)"]
                ))
                throw ExitCode.failure
            }

            noora.success(.alert(
                "Stake Registration and Vote Delegation certificate created successfully.",
                takeaways: [
                    "File: \(outFile.string)",
                    "Registers stake address and delegates votes to DRep: \(.primary(try drep.id()))",
                    "Deposit: \(depositFee) lovelaces",
                    "Include this certificate when building your transaction."
                ]
            ))

            try await FileUtils.displayFile(outFile)

            if certificateOptions.generateTransaction {
                let logger = getLogger(config: config)
                let txBuilder = TxBuilder(context: context, logger: logger)

                let loadedCert = try SwiftCardanoCore.VoteRegisterDelegate.load(from: outFile.string)
                txBuilder.certificates = [.voteRegisterDelegate(loadedCert)]

                guard let feePaymentAddress = transactionOptions.feePaymentAddress else {
                    noora.error(.alert("Fee payment address is required.", takeaways: ["Provide a valid fee payment address."]))
                    throw ExitCode.validationFailure
                }

                let signingKeys: [String] = [
                    try stakeAddress.info.getSigningMethod().path.string,
                    try feePaymentAddress.info.getSigningMethod().path.string
                ]

                let txTimestamp = DateUtils.getCurrentTimestamp()
                let txRawFile = cwd.appending("\(feePaymentAddress.info.name!)-\(txTimestamp).raw.tx")
                let txFile = cwd.appending("\(feePaymentAddress.info.name!)-\(txTimestamp).tx")
                let txSignedFile = cwd.appending("\(feePaymentAddress.info.name!)-\(txTimestamp).signed.tx")

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
                if transactionOptions.useCardanoCLI { args.append("--use-cardano-cli") }
                if transactionOptions.save { args.append("--save") }
                if transactionOptions.submit { args.append("--submit") }

                let signingKeysArgs = signingKeys.flatMap { ["--signing-key-file", $0] }
                await TransactionMainCommand.Sign.main([
                    "--tx-file", txFile.string,
                    "--out-file", txSignedFile.string
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
