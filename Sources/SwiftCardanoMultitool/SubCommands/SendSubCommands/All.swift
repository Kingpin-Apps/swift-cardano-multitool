import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftCardanoChain
import SwiftCardanoTxBuilder
import Path

enum AllSendMode: String, ExpressibleByArgument, CaseIterable, AlignedChoiceDescribable {
    case all           = "all"
    case assetsOnly    = "assets-only"
    case lovelacesOnly = "lovelaces-only"

    var name: String {
        switch self {
        case .all:           return "All"
        case .assetsOnly:    return "Assets Only"
        case .lovelacesOnly: return "Lovelaces Only"
        }
    }

    var details: String {
        switch self {
        case .all:           return "Send all ADA and assets to destination."
        case .assetsOnly:    return "Send all native assets (with minimum ADA) to destination, keeping remaining ADA at source."
        case .lovelacesOnly: return "Send all available ADA to destination, returning assets with minimum ADA to source."
        }
    }
}

extension SendMainCommand {
    struct All: TransactionSendable {
        static let configuration = CommandConfiguration(
            commandName: "all",
            abstract: "Send all ADA and assets, all assets, or all ADA from an address.",
            usage: """

            scm send all

            scm send all \\
                --send-mode assets-only \\
                --to-address recipient.payment \\
                --fee-payment-address owner.payment

            scm send all \\
                --send-mode lovelaces-only \\
                --to-address addr1... \\
                --fee-payment-address owner.payment
            """,
            discussion: """
            Sends funds from a source address to a destination address.

            Modes:
              all           — sends all ADA and all native assets to destination
              assets-only   — sends all native assets (with minimum ADA) to destination; remaining ADA stays at source
              lovelaces-only — sends all available ADA to destination; native assets are returned to source with minimum ADA

            NOTE: 'all' and 'lovelaces-only' modes require the SwiftCardano builder and are not compatible with --use-cardano-cli.
            """
        )

        @Option(name: .long, help: "What to send: all, assets-only, lovelaces-only (default: all)")
        var sendMode: AllSendMode = .all

        @OptionGroup var transactionOptions: SharedTransactionOptions

        // MARK: - Validation

        mutating func validate() throws {
            if (sendMode == .all || sendMode == .lovelacesOnly) && transactionOptions.useCardanoCLI {
                throw ValidationError("Send mode '\(sendMode.rawValue)' is not compatible with --use-cardano-cli. Remove that flag to use SwiftCardano.")
            }
            try self.validateForTransaction()
        }

        // MARK: - Wizard

        mutating func wizard() async throws {
            transactionOptions.feePaymentAddress = try await getFeePaymentAddress(title: "Source Address (from)")

            let useSameDestination = noora.yesOrNoChoicePrompt(
                title: "Destination",
                question: "Send to the same address?",
                defaultAnswer: false,
                description: "Select 'No' to specify a different destination address."
            )

            if useSameDestination {
                transactionOptions.toAddress = transactionOptions.feePaymentAddress
            } else {
                transactionOptions.toAddress = try await getDestinationAddress(title: "Destination Address (to)")
            }

            sendMode = noora.singleChoicePrompt(
                title: "Send Mode",
                question: "What would you like to send?",
                options: AllSendMode.allCases,
                description: "Select what to send from the source address."
            )

            try await self.wizardForTransaction()
            try self.validate()
        }

        // MARK: - Run

        mutating func run() async throws {
            if transactionOptions.feePaymentAddress == nil {
                try await wizard()
            }

            if transactionOptions.toAddress == nil {
                transactionOptions.toAddress = transactionOptions.feePaymentAddress
            }

            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let config = try await MultitoolConfig.load()
            let context = try await getContext(config: config)
            try await printContextInfo(config: config, context: context)

            guard let feePaymentAddress = transactionOptions.feePaymentAddress,
                  let toAddress = transactionOptions.toAddress else {
                throw ValidationError("Source and destination addresses are required.")
            }

            spacedPrint("\n\(.primary("━━━ Send All Transaction ━━━"))\n")

            noora.info(.alert(
                "Send All (\(.primary(sendMode.rawValue))) with the following details:",
                takeaways: [
                    "Mode: \(.primary(sendMode.rawValue))",
                    "From: \(feePaymentAddress.info.description)",
                    "To: \(toAddress.info.description)",
                ]
            ))

            // Warn and confirm before proceeding — this drains the source address
            switch sendMode {
            case .all:
                noora.warning(.alert(
                    "This will send ALL ADA and ALL native assets from the source address.",
                    takeaway: "The source address will be completely emptied (minus the transaction fee)."
                ))
            case .lovelacesOnly:
                noora.warning(.alert(
                    "This will send ALL available ADA from the source address.",
                    takeaway: "Only the minimum ADA required to hold your native assets will remain at the source."
                ))
            case .assetsOnly:
                noora.warning(.alert(
                    "This will send ALL native assets from the source address.",
                    takeaway: "Remaining ADA will stay at the source. Only native assets are moved."
                ))
            }

            let confirmed = noora.yesOrNoChoicePrompt(
                title: "Confirm Send All",
                question: "Are you sure you want to proceed?",
                defaultAnswer: false,
                description: "This action cannot be undone once the transaction is submitted."
            )

            guard confirmed else {
                throw CleanExit.message("Send All cancelled.")
            }

            let protocolParamsFile = cwd.appending("protocol-parameters.json")
            _ = try await getProtocolParameters(
                context: context,
                protocolParamsFile: protocolParamsFile
            )

            let utxos = try await queryAndFilterUtxos(
                feePaymentAddress: feePaymentAddress.info,
                context: context,
                config: config
            )

            guard !utxos.isEmpty else {
                noora.error(.alert(
                    "No UTxOs found at source address.",
                    takeaways: ["Ensure the source address has funds before sending."]
                ))
                throw ExitCode.failure
            }

            let logger = getLogger(config: config)
            let txBuilder = TxBuilder(context: context, logger: logger)

            let timestamp = DateUtils.getCurrentTimestamp()
            let txRawFile = cwd.appending("\(feePaymentAddress.info.name!)-\(timestamp).raw.tx")
            let txFile = cwd.appending("\(feePaymentAddress.info.name!)-\(timestamp).tx")
            let txSignedFile = cwd.appending("\(feePaymentAddress.info.name!)-\(timestamp).signed.tx")

            switch sendMode {

            case .all:
                // No explicit outputs — change address directs everything to destination
                try await buildTransaction(
                    txBuilder: txBuilder,
                    config: config,
                    utxos: utxos,
                    protocolParamsFile: protocolParamsFile,
                    txRawFile: txRawFile,
                    txFile: txFile,
                    txSignedFile: txSignedFile,
                    changeAddressOverride: toAddress.info.address
                )

            case .assetsOnly:
                // Collect all assets across UTXOs
                var assetsOut = MultiAsset([:])
                for utxo in utxos {
                    assetsOut.data.merge(utxo.output.amount.multiAsset.data) { current, _ in current }
                }

                guard !assetsOut.isEmpty else {
                    noora.error(.alert(
                        "No native assets found at source address.",
                        takeaways: ["Use 'all' or 'lovelaces-only' mode if you only have ADA."]
                    ))
                    throw ExitCode.failure
                }

                // Calculate minimum lovelace for the asset output
                let draftOutput = TransactionOutput(
                    address: toAddress.info.address!,
                    amount: Value(coin: 1_000_000, multiAsset: assetsOut)
                )
                let minLovelace = try await Utils.minLovelacePostAlonzo(draftOutput, context)

                let assetTxOut = TransactionOutput(
                    address: toAddress.info.address!,
                    amount: Value(coin: Int64(minLovelace), multiAsset: assetsOut)
                )
                try txBuilder.addOutput(assetTxOut)

                spacedPrint(
                    "Sending all assets with minimum \(.primary(lovelaceToAdaFormatString(minLovelace))) / \(.primary("\(minLovelace)")) lovelaces to destination."
                )

                try await buildTransaction(
                    txBuilder: txBuilder,
                    config: config,
                    utxos: utxos,
                    protocolParamsFile: protocolParamsFile,
                    txRawFile: txRawFile,
                    txFile: txFile,
                    txSignedFile: txSignedFile
                )

            case .lovelacesOnly:
                // Collect all assets to return to source with minimum ADA
                var assetsOut = MultiAsset([:])
                for utxo in utxos {
                    assetsOut.data.merge(utxo.output.amount.multiAsset.data) { current, _ in current }
                }

                if !assetsOut.isEmpty {
                    let draftOutput = TransactionOutput(
                        address: feePaymentAddress.info.address!,
                        amount: Value(coin: 1_000_000, multiAsset: assetsOut)
                    )
                    let minLovelaceForAssets = try await Utils.minLovelacePostAlonzo(draftOutput, context)

                    let assetReturnTxOut = TransactionOutput(
                        address: feePaymentAddress.info.address!,
                        amount: Value(coin: Int64(minLovelaceForAssets), multiAsset: assetsOut)
                    )
                    try txBuilder.addOutput(assetReturnTxOut)

                    spacedPrint(
                        "Returning all assets to source with \(.primary(lovelaceToAdaFormatString(minLovelaceForAssets))) minimum ADA."
                    )
                }

                // Change (remaining lovelaces) goes to destination
                try await buildTransaction(
                    txBuilder: txBuilder,
                    config: config,
                    utxos: utxos,
                    protocolParamsFile: protocolParamsFile,
                    txRawFile: txRawFile,
                    txFile: txFile,
                    txSignedFile: txSignedFile,
                    changeAddressOverride: toAddress.info.address
                )
            }

            var args: [String] = []
            if transactionOptions.useCardanoCLI { args.append("--use-cardano-cli") }
            if transactionOptions.save         { args.append("--save") }
            if transactionOptions.submit       { args.append("--submit") }

            await TransactionMainCommand.Sign.main([
                "--tx-file", txFile.string,
                "--out-file", txSignedFile.string,
            ] + args + ["--signing-keys", try feePaymentAddress.info.getSigningMethod().path.string])

            if !transactionOptions.save {
                try? FileManager.default.removeItem(atPath: txRawFile.string)
                try? FileManager.default.removeItem(atPath: txFile.string)
                try? FileManager.default.removeItem(atPath: txSignedFile.string)
            }
        }
    }
}
