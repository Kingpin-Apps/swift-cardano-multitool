import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftCardanoChain
import SwiftCardanoTxBuilder

extension CertificateMainCommand {

    struct StakeRegisterDelegateCertificate: CertificateCommandable {
        static let configuration = CommandConfiguration(
            commandName: "stake-register-delegation",
            abstract: "Generates a stake address registration and delegation certificate.",
            usage: """
            scm certificate stake-register-delegation --stake-address owner --pool-operator pool1xyz
            """,
            discussion: """
            Creates a combined stake address registration and stake delegation
            certificate. This Conway-era certificate registers the stake address
            on-chain and delegates its stake to the specified pool in a single
            operation. The stake address deposit is required. If the
            `--generate-transaction` flag is used, a transaction will also be
            created to submit the certificate on-chain.
            """,
            aliases: ["stake-reg-deleg"]
        )

        // MARK: - Required Arguments

        @Option(name: [.short, .long], help: "Stake address file name. Example: owner → owner.stake.addr")
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

        mutating func wizard() async throws {
            stakeAddress = try await getStakeAddress(title: "Stake Address to register and delegate")
            poolOperator = try await getPoolOperator()
            try await self.wizardForCertificate()
            if certificateOptions.generateTransaction {
                try await self.wizardForTransaction()
            }
            try self.validate()
        }

        // MARK: - Run

        mutating func run() async throws {
            if stakeAddress == nil || poolOperator == nil {
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
            guard let poolOperator = poolOperator else {
                noora.error(.alert("Pool Operator is required.", takeaways: ["Provide a valid Pool Operator identifier."]))
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
                certificateOptions.outFile = cwd.appending("\(stakeVkeyFilePath.stem!)-\(timestamp).stake-reg-deleg.cert")
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

            print(noora.format("\nGenerating stake registration and delegation certificate for: \(.primary(stakeAddress.info.name!))"))
            spacedPrint("Stake Address Deposit: \(.primary("\(lovelaceToAdaFormatString(UInt64(depositFee)))")) / \(depositFee) lovelaces.")

            do {
                if transactionOptions.useCardanoCLI {
                    let logger = getLogger(config: config)
                    let cli = try await CardanoCLI(configuration: config.toSwiftCardanoUtilsConfig(), logger: logger)

                    let arguments = [
                        "--stake-verification-key-file", stakeVkeyFilePath.string,
                        "--stake-pool-id", try poolOperator.id(),
                        "--key-reg-deposit-amt", "\(depositFee)",
                        "--out-file", outFile.string
                    ]
                    try await FileUtils.unlockIfExists(outFile)
                    _ = try await cli.stakeAddress.registrationAndDelegationCertificate(arguments: arguments)
                    try await FileUtils.fileLock(outFile)
                } else {
                    let stakeVkey = try StakeVerificationKey.load(from: stakeVkeyFilePath.string)
                    let stakeCredential = StakeCredential(credential: .verificationKeyHash(try stakeVkey.hash()))
                    let cert = SwiftCardanoCore.StakeRegisterDelegate(
                        stakeCredential: stakeCredential,
                        poolKeyHash: poolOperator.poolKeyHash,
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
                "Stake Registration and Delegation certificate created successfully.",
                takeaways: [
                    "File: \(outFile.string)",
                    "Registers stake address and delegates to pool: \(.primary(try poolOperator.id()))",
                    "Deposit: \(depositFee) lovelaces",
                    "Include this certificate when building your transaction."
                ]
            ))

            try await FileUtils.displayFile(outFile)

            if certificateOptions.generateTransaction {
                let logger = getLogger(config: config)
                let txBuilder = TxBuilder(context: context, logger: logger)

                let loadedCert = try SwiftCardanoCore.StakeRegisterDelegate.load(from: outFile.string)
                txBuilder.certificates = [.stakeRegisterDelegate(loadedCert)]

                guard let feePaymentAddress = transactionOptions.feePaymentAddress else {
                    noora.error(.alert("Fee payment address is required.", takeaways: ["Provide a valid fee payment address."]))
                    throw ExitCode.validationFailure
                }

                let signingKeys: [String] = [
                    try stakeAddress.info.getSigningMethod().path.string,
                    try feePaymentAddress.info.getSigningMethod().path.string
                ]

                spacedPrint("\nSubmit Stake Registration and Delegation Certificate \(.primary(outFile.string)) with funds from \(.primary(feePaymentAddress.info.name!))")

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
