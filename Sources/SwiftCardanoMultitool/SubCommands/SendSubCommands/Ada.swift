import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftCardanoChain
import SwiftCardanoTxBuilder
import Path

extension SendMainCommand {
    /// Send an ADA amount. Identical to `send lovelaces` except a bare `--amount`
    /// is interpreted as ADA (e.g. `--amount 3` = 3 ₳), not lovelaces.
    struct Ada: TransactionSendable {
        static let configuration = CommandConfiguration(
            commandName: "ada",
            abstract: "Send an ADA amount from one address to another.",
            usage: """

            scm send ada

            scm send ada \\
                --amount min \\
                --to-address recipient.payment \\
                --fee-payment-address owner.payment

            scm send ada \\
                --amount 5 \\
                --to-address addr1... \\
                --fee-payment-address owner.payment
            """,
            discussion: """
            Sends a specific amount of ADA to a destination address.

            Amount options:
              <number> — send exactly this many ADA (e.g. 1.5 = 1.5 ₳). Add an
                         explicit unit ('100000 lovelace') to override.
              min      — send the protocol-defined minimum UTXO amount

            Native assets at the source are NOT affected; only ADA is sent.
            Change (remaining ADA and any assets) is returned to the source address.
            """
        )

        // MARK: - Parameters

        @Option(name: .long, help: "ADA amount to send, or 'min' for the protocol minimum UTXO.")
        var amount: String?

        @OptionGroup var transactionOptions: SharedTransactionOptions

        // MARK: - Validation

        mutating func validate() throws {
            if let amount {
                let lowered = amount.lowercased()
                if lowered != "min" {
                    guard let parsed = AdaFormatter(defaultUnit: .ada).toLovelace(amount), parsed > 0 else {
                        throw ValidationError("Amount must be 'min' or a positive ADA amount, got '\(amount)'.")
                    }
                }
            }
            try self.validateForTransaction()
        }

        // MARK: - Wizard

        mutating func wizard() async throws {
            transactionOptions.feePaymentAddress = try await getFeePaymentAddress(title: "Source Address (from)")
            transactionOptions.toAddress = try await getDestinationAddress(title: "Destination Address (to)")

            // Show available balance
            let config = try await MultitoolConfig.load()
            let context = try await getContext(config: config)

            if let feePaymentAddress = transactionOptions.feePaymentAddress {
                let utxos = try await queryAndFilterUtxos(
                    feePaymentAddress: feePaymentAddress.info,
                    context: context,
                    config: config
                )
                let totalLovelaces = utxos.reduce(0) { $0 + $1.output.amount.coin }
                spacedPrint(
                    "Available balance: \(.primary(lovelaceToAdaFormatString(UInt64(totalLovelaces)))) / \(.primary("\(totalLovelaces)")) lovelaces"
                )
            }

            amount = noora.textPrompt(
                title: "Amount",
                prompt: "Enter ADA amount (e.g., 100, 1.5) or 'min' for protocol minimum:",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Amount cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            try await self.wizardForTransaction()
            try self.validate()
        }

        // MARK: - Run

        mutating func run() async throws {
            if amount == nil || transactionOptions.feePaymentAddress == nil , isInteractiveSession() {
                try await wizard()
            }

            if transactionOptions.toAddress == nil {
                transactionOptions.toAddress = transactionOptions.feePaymentAddress
            }

            let cwd = FilePath(FileManager.default.currentDirectoryPath)
            let config = try await MultitoolConfig.load()
            let cardanoConfig = try getCardanoConfig(config: config)
            try await resolveAdaHandles(network: cardanoConfig.network)
            let context = try await getContext(config: config)
            try await printContextInfo(config: config, context: context)

            guard let feePaymentAddress = transactionOptions.feePaymentAddress,
                  let toAddress = transactionOptions.toAddress,
                  let amount else {
                throw ValidationError("Required arguments missing. Run without arguments for wizard mode.")
            }

            spacedPrint("\n\(.primary("━━━ Send ADA Transaction ━━━"))\n")

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

            // Resolve amount (bare number = ADA)
            let resolvedLovelace: UInt64
            if amount.lowercased() == "min" {
                let draftOutput = TransactionOutput(
                    address: toAddress.info.address!,
                    amount: Value(coin: 1_000_000)
                )
                resolvedLovelace = try await Utils.minLovelacePostAlonzo(draftOutput, context)
                spacedPrint(
                    "Protocol minimum UTXO: \(.primary(lovelaceToAdaFormatString(resolvedLovelace))) / \(.primary("\(resolvedLovelace)")) lovelaces"
                )
            } else {
                guard let parsed = AdaFormatter(defaultUnit: .ada).toLovelace(amount), parsed > 0 else {
                    noora.error(.alert("Invalid amount '\(amount)'. Must be 'min', or an ADA or lovelace amount."))
                    throw ExitCode.validationFailure
                }
                resolvedLovelace = parsed
            }

            let totalAvailable = UInt64(utxos.reduce(0) { $0 + $1.output.amount.coin })
            guard resolvedLovelace <= totalAvailable else {
                noora.error(.alert(
                    "Insufficient funds.",
                    takeaways: [
                        "Requested: \(lovelaceToAdaFormatString(resolvedLovelace)) / \(resolvedLovelace) lovelaces",
                        "Available: \(lovelaceToAdaFormatString(totalAvailable)) / \(totalAvailable) lovelaces"
                    ]
                ))
                throw ExitCode.failure
            }

            noora.info(.alert(
                "Sending ADA with the following details:",
                takeaways: [
                    "Amount: \(.primary(lovelaceToAdaFormatString(resolvedLovelace))) / \(.primary("\(resolvedLovelace)")) lovelaces",
                    "From: \(feePaymentAddress.info.description)",
                    "To: \(toAddress.info.description)",
                ]
            ))

            let txOut = TransactionOutput(
                address: toAddress.info.address!,
                amount: Value(coin: Int64(resolvedLovelace))
            )

            let logger = getLogger(config: config)
            let txBuilder = TxBuilder(context: context, logger: logger)
            try txBuilder.addOutput(txOut)

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
