import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftCardanoChain
import SwiftCardanoTxBuilder
import Logging
import Path


extension TransactionMainCommand {
    
    struct RewardsWithdraw: TransactionCommandable {
        static let configuration = CommandConfiguration(
            abstract: "Generates a rewards withdrawal transaction to withdraw staking rewards.",
            usage: """
            scm transaction rewards-withdraw \\
                --stake-address-name owner \\
                --to-address owner.payment
            
            scm transaction rewards-withdraw \\
                -s owner.stake \\
                -t addr1... \\
                -f fees.payment \\
                --message "Rewards for epoch 450" \\
                --encryption basic
            """,
            discussion: """
            Claims staking rewards from a stake address and sends them to a destination address.
            
            The transaction can withdraw all available rewards from a registered stake address.
            You can specify the same or different addresses for receiving rewards and paying fees.
            
            IMPORTANT: In Conway era (protocol version ≥ 10), a DRep delegation is required
            before claiming rewards.
            """
        )
        
        // MARK: - Required Arguments
        
        @Option(name: [.short, .long], help: "Staking address file base name (without .stake.addr). Example: owner → owner.stake.addr")
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
        
        mutating func wizard() async throws {
            stakeAddress = try await getStakeAddress(title: "Stake Address for Rewards Withdrawal")
            
            let claimToSelf = noora.yesOrNoChoicePrompt(
                title: "Claim to Self",
                question: "Send rewards to self (use payment address that belongs to stake address)?",
                defaultAnswer: true,
                description: "If 'No', you'll specify a different address to pay fees from."
            )
            
            if claimToSelf {
                let cwd = FilePath(FileManager.default.currentDirectoryPath)
                
                guard let stakeAddressFileName = stakeAddress?.info.name else {
                    throw ValidationError("Stake address file name is missing.")
                }
                
                let paymentFileName = "\(stakeAddressFileName).payment.addr"
                let paymentFile = cwd.appending(paymentFileName)
                
                try FileUtils.checkFileExists(paymentFile)
                
                transactionOptions.toAddress = PaymentAddressInfo(
                    info: try AddressInfo(
                        fromFile: paymentFile,
                        name: paymentFileName
                    )
                )
                transactionOptions.feePaymentAddress = transactionOptions.toAddress
            } else {
                transactionOptions.toAddress = try await getDestinationAddress(title: "Destination Address for Rewards Withdrawal")
                
                let useSameAddress = noora.yesOrNoChoicePrompt(
                    title: "Fee Payment",
                    question: "Use the same address to pay transaction fees?",
                    defaultAnswer: true,
                    description: "If 'No', you'll specify a different address to pay fees from."
                )
                
                if !useSameAddress {
                    transactionOptions.feePaymentAddress = try await getFeePaymentAddress(
                        title: "Fee Payment Address"
                    )
                } else {
                    transactionOptions.feePaymentAddress = transactionOptions.toAddress
                }
            }
            
            try await self.wizardForTransaction()
            
            try self.validate()
        }
        
        // MARK: - Run
        
        mutating func run() async throws {
            // If no arguments provided, run wizard
            if stakeAddress == nil && transactionOptions.feePaymentAddress == nil {
                try await self.wizard()
            }
            
            if transactionOptions.toAddress == nil {
                transactionOptions.toAddress = transactionOptions.feePaymentAddress
            }
            
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            
            let config = try await MultitoolConfig.load()
            let context = try await getContext(config: config)
            try await printContextInfo(config: config, context: context)
            
            // Ensure required arguments are present
            guard var stakeAddress = stakeAddress,
                  let toAddress = transactionOptions.toAddress,
                  let feePaymentAddress = transactionOptions.feePaymentAddress else {
                throw ValidationError("Required arguments missing. Use --stake-address and --fee-payment-address or run without arguments for wizard mode.")
            }
            
            spacedPrint(
                "\n\(.primary("━━━ Rewards Withdrawal Transaction ━━━"))\n"
            )
            
            noora.info(.alert(
                "Address Resolution Complete. Claim Staking Rewards with the following details:",
                takeaways: [
                    "Stake: \(stakeAddress.info.description)",
                    "Destination: \(toAddress.info.description)",
                    "Fee Payer: \(String(describing: feePaymentAddress.info.description))",
                    "Signing: Payment via \((try feePaymentAddress.info.getSigningMethod().isHardware) ? "Hardware" : "Software"), Stake via \((try stakeAddress.info.getSigningMethod().isHardware) ? "Hardware" : "Software")"
                ]
            ))
            
            let protocolParamsFile = cwd.appending(
                "protocol-parameters.json"
            )
            
            let protocolParams = try await getProtocolParameters(
                context: context,
                protocolParamsFile: protocolParamsFile
            )
            
            try await queryStakeAddressInfo(
                stakeAddress: &stakeAddress,
                context: context,
                config: config,
                protocolParams: protocolParams
            )
            
            let rewardAccountBalance = stakeAddress.info.stakeAddressInfo.reduce(0) {
                $0 + $1.rewardAccountBalance
            }
            
            // Check if rewards are available
            guard rewardAccountBalance > 0 else {
                noora.error(.alert(
                    "No rewards available to withdraw.",
                    takeaways: [
                        "Rewards balance: 0 lovelaces",
                        "Wait for rewards to accumulate before claiming."
                    ]
                ))
                throw CleanExit.message("No rewards to withdraw. Exiting.")
            }
            
            if isSame {
                spacedPrint(
                    "Using same address for rewards and fee payment."
                )
            } else {
                noora.warning(.alert(
                    "Using different addresses for rewards and fee payment."
                ))
            }
            
            let utxos = try await queryAndFilterUtxos(
                feePaymentAddress: feePaymentAddress.info,
                context: context,
                config: config
            )
            
            var assetsOutString = ""
            var assetsOut: MultiAsset = MultiAsset([:])
            
            for utxo in utxos {
                assetsOutString += utxo.output.amount.multiAsset.toAssetsOutString()
                assetsOut.data.merge(
                    utxo.output.amount.multiAsset.data
                ) { (current, _) in current }
            }
            
            var withdrawals = Withdrawals([:])
            for rewards in stakeAddress.info.stakeAddressInfo {
                withdrawals
                    .data[RewardAccount(stakeAddress.info.address!.toBytes())] = Coin(
                        rewards.rewardAccountBalance
                    )
            }
            let withdrawalsAmount = withdrawals.data.values.reduce(0, +)
            
            let logger = getLogger(config: config)
            let txBuilder = TxBuilder(context: context, logger: logger)
            txBuilder.withdrawals = withdrawals
            
            if !isSame {
                let txOut = TransactionOutput(
                    address: toAddress.info.address!,
                    amount: Value(coin: Int(withdrawalsAmount))
                )
                try txBuilder.addOutput(txOut)
            }
            
            // Transaction file paths
            let timestamp = DateUtils.getCurrentTimestamp()
            let txRawFile = cwd.appending("\(feePaymentAddress.info.name!)-\(timestamp).raw.tx")
            let txFile = cwd.appending("\(feePaymentAddress.info.name!)-\(timestamp).tx")
            let txSignedFile = cwd.appending("\(feePaymentAddress.info.name!)-\(timestamp).signed.tx")
            
            try await buildTransaction(
                txBuilder: txBuilder,
                config: config,
                utxos: utxos,
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

