import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftCardanoChain
import SwiftCardanoTxBuilder

extension CertificateMainCommand {

    struct MoveInstantaneousRewardsCertificate: CertificateCommandable {
        static let configuration = CommandConfiguration(
            commandName: "move-instantaneous-rewards",
            abstract: "Generates a Move Instantaneous Rewards (MIR) certificate.",
            usage: """
            scm certificate move-instantaneous-rewards
            """,
            discussion: """
            Creates a Move Instantaneous Rewards (MIR) certificate for
            Shelley-era networks. MIR certificates transfer funds from either
            the reserves or treasury to stake addresses or between the two
            pots. This is a legacy certificate type not available in Conway
            era. If the `--generate-transaction` flag is used, a transaction
            will also be created to submit the certificate on-chain.
            """,
            aliases: ["mir"]
        )

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
            try await self.wizardForCertificate()
            if certificateOptions.generateTransaction {
                try await self.wizardForTransaction()
            }
            try self.validate()
        }

        // MARK: - Run

        mutating func run() async throws {
            // Prompt for source
            let sourceOption: MoveInstantaneousRewardSourceOption = noora.singleChoicePrompt(
                title: "MIR Source",
                question: "Select the source of the rewards:",
                description: "Choose whether to move funds from reserves or treasury."
            )
            let source: MoveInstantaneousRewardSource = sourceOption == .reserves ? .reserves : .treasury

            // Prompt for transfer target
            let transferToOtherPot = noora.yesOrNoChoicePrompt(
                title: "Transfer Type",
                question: "Transfer to the other pot (reserves ↔ treasury)?",
                description: "If no, you will distribute rewards to specific stake addresses instead."
            )

            let config = try await MultitoolConfig.load()
            let context = try await getContext(config: config)
            try await printContextInfo(config: config, context: context)

            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let timestamp = DateUtils.getCurrentTimestamp()

            if certificateOptions.outFile == nil {
                certificateOptions.outFile = cwd.appending("\(sourceOption.rawValue)-\(timestamp).mir.cert")
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

            let moveInstantaneousReward: MoveInstantaneousReward
            var cliArguments: [String] = [sourceOption == .reserves ? "--reserves" : "--treasury"]

            if transferToOtherPot {
                let amountStr = noora.textPrompt(
                    title: "Transfer Amount",
                    prompt: "Enter the amount to transfer in lovelaces:",
                    collapseOnAnswer: true,
                    validationRules: [NonEmptyValidationRule(error: "Amount cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                guard let amount = UInt64(amountStr) else {
                    noora.error(.alert("Invalid amount.", takeaways: ["Enter a valid lovelace amount."]))
                    throw ExitCode.validationFailure
                }
                moveInstantaneousReward = MoveInstantaneousReward(source: source, rewards: nil, coin: amount)
                cliArguments.append(contentsOf: ["--transfer", "\(amount)"])
            } else {
                // Reward distributions to stake addresses
                var rewards: [String: DeltaCoin] = [:]
                var moreAddresses = true

                while moreAddresses {
                    let stakeAddr = noora.textPrompt(
                        title: "Stake Address",
                        prompt: "Enter a stake address (stake1...):",
                        collapseOnAnswer: true,
                        validationRules: [NonEmptyValidationRule(error: "Stake address cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)

                    let rewardStr = noora.textPrompt(
                        title: "Reward Amount",
                        prompt: "Enter the reward amount for \(stakeAddr) in lovelaces:",
                        collapseOnAnswer: true,
                        validationRules: [NonEmptyValidationRule(error: "Reward cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)

                    guard let reward = Int(rewardStr) else {
                        noora.error(.alert("Invalid reward amount.", takeaways: ["Enter a valid lovelace amount."]))
                        throw ExitCode.validationFailure
                    }

                    let deltaCoin = try JSONDecoder().decode(DeltaCoin.self, from: Data("{\"deltaCoin\":\(reward)}".utf8))
                    rewards[stakeAddr] = deltaCoin
                    cliArguments.append(contentsOf: ["--stake-address", stakeAddr, "--reward", "\(reward)"])

                    moreAddresses = noora.yesOrNoChoicePrompt(
                        title: "More Addresses",
                        question: "Add another stake address?",
                        description: "You can distribute rewards to multiple stake addresses."
                    )
                }

                moveInstantaneousReward = MoveInstantaneousReward(source: source, rewards: rewards, coin: nil)
            }

            print(noora.format("\nGenerating MIR certificate from: \(.primary(sourceOption.rawValue))"))

            do {
                if transactionOptions.useCardanoCLI {
                    let logger = getLogger(config: config)
                    let cli = try await CardanoCLI(configuration: config.toSwiftCardanoUtilsConfig(), logger: logger)

                    cliArguments.append(contentsOf: ["--out-file", outFile.string])

                    try await FileUtils.unlockIfExists(outFile)
                    _ = try await cli.legacy.governance(arguments: ["create-mir-certificate"] + cliArguments)
                    try await FileUtils.fileLock(outFile)
                } else {
                    let cert = SwiftCardanoCore.MoveInstantaneousRewards(
                        moveInstantaneousRewards: moveInstantaneousReward
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
                "Move Instantaneous Rewards certificate created successfully.",
                takeaways: [
                    "File: \(outFile.string)",
                    "Source: \(sourceOption.rawValue)",
                    "Include this certificate when building your transaction."
                ]
            ))

            try await FileUtils.displayFile(outFile)

            if certificateOptions.generateTransaction {
                let logger = getLogger(config: config)
                let txBuilder = TxBuilder(context: context, logger: logger)

                let loadedCert = try SwiftCardanoCore.MoveInstantaneousRewards.load(from: outFile.string)
                txBuilder.certificates = [.moveInstantaneousRewards(loadedCert)]

                guard let feePaymentAddress = transactionOptions.feePaymentAddress else {
                    noora.error(.alert("Fee payment address is required.", takeaways: ["Provide a valid fee payment address."]))
                    throw ExitCode.validationFailure
                }

                let signingKeys: [String] = [
                    try feePaymentAddress.info.getSigningMethod().path.string
                ]

                let protocolParamsFile = cwd.appending("protocol-parameters.json")
                _ = try await getProtocolParameters(context: context, protocolParamsFile: protocolParamsFile)

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
