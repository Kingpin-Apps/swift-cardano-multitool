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
        
        var isSame: Bool {
            return feePaymentAddress!.info.address == toAddress!.info.address
        }
        
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
                
                toAddress = PaymentAddressInfo(
                    info: try AddressInfo(
                        fromFile: paymentFile,
                        name: paymentFileName
                    )
                )
                feePaymentAddress = toAddress
            } else {
                toAddress = try await getDestinationAddress(title: "Destination Address for Rewards Withdrawal")
                
                let useSameAddress = noora.yesOrNoChoicePrompt(
                    title: "Fee Payment",
                    question: "Use the same address to pay transaction fees?",
                    defaultAnswer: true,
                    description: "If 'No', you'll specify a different address to pay fees from."
                )
                
                if !useSameAddress {
                    feePaymentAddress = try await getFeePaymentAddress(
                        title: "Fee Payment Address"
                    )
                } else {
                    feePaymentAddress = toAddress
                }
            }
            
            try await self.wizardForTransaction()
            
            try self.validate()
        }
        
        // MARK: - Run
        
        mutating func run() async throws {
            // If no arguments provided, run wizard
            if stakeAddress == nil && feePaymentAddress == nil {
                try await self.wizard()
            }
            
            if toAddress == nil {
                toAddress = feePaymentAddress
            }
            
            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            
            let config = try await MultitoolConfig.load()
            let context = try await getContext(config: config)
            try await printInfo(config: config, context: context)
            
            // Ensure required arguments are present
            guard var stakeAddress = stakeAddress,
                    let toAddress = toAddress,
                    let feePaymentAddress = feePaymentAddress else {
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
            
            let totalLovelaces = utxos.reduce(0) {
                $0 + $1.output.lovelace
            }
            
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
            if useCardanoCLI {
                args.append("--use-cardano-cli")
            }
            if save {
                args.append("--save")
            }
            if submit {
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
            
            if !save {
                try FileManager.default.removeItem(atPath: txRawFile.string)
                try FileManager.default.removeItem(atPath: txFile.string)
                try FileManager.default.removeItem(atPath: txSignedFile.string)
            }
            
        }
    }
}

