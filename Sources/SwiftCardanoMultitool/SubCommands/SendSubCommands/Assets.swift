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
    struct Assets: TransactionSendable {
        static let configuration = CommandConfiguration(
            commandName: "assets",
            abstract: "Send a native asset from one address to another.",
            usage: """

            scm send assets

            scm send assets \\
                --policy-id <56-char-hex> \\
                --asset-name-hex <hex> \\
                --amount all \\
                --to-address recipient.payment \\
                --fee-payment-address owner.payment

            scm send assets \\
                --policy-id <56-char-hex> \\
                --asset-name-hex <hex> \\
                --amount 100 \\
                --lovelace-amount 2000000 \\
                --to-address addr1... \\
                --fee-payment-address owner.payment
            """,
            discussion: """
            Sends a specific native asset to a destination address.

            Amount options:
              <number> — send exactly this many tokens
              all      — send all available tokens of this asset
              min      — send 1 token with the minimum required lovelaces (protocol minimum UTXO)

            The lovelace amount bundled with the asset defaults to the protocol minimum if not specified.
            """
        )

        // MARK: - Parameters

        @Option(name: .long, help: "Policy ID of the asset (56-char hex).")
        var policyId: String?

        @Option(name: .long, help: "Asset name in hex.")
        var assetNameHex: String?

        @Option(name: .long, help: "Amount to send: a positive integer, 'all', or 'min'.")
        var amount: String?

        @Option(name: .long, help: "Lovelaces to bundle with the asset (default: protocol minimum).")
        var lovelaceAmount: UInt64?

        @OptionGroup var transactionOptions: SharedTransactionOptions

        // MARK: - Validation

        mutating func validate() throws {
            if let policyId {
                guard policyId.count == 56,
                      policyId.allSatisfy({ $0.isHexDigit }) else {
                    throw ValidationError("Policy ID must be a 56-character hex string, got '\(policyId)'.")
                }
            }
            if let assetNameHex {
                guard assetNameHex.allSatisfy({ $0.isHexDigit }) else {
                    throw ValidationError("Asset name must be a hex string, got '\(assetNameHex)'.")
                }
            }
            if let amount {
                let lowered = amount.lowercased()
                if lowered != "all" && lowered != "min" {
                    guard let n = Int(amount), n > 0 else {
                        throw ValidationError("Amount must be 'all', 'min', or a positive integer, got '\(amount)'.")
                    }
                }
            }
            try self.validateForTransaction()
        }

        // MARK: - Wizard

        mutating func wizard() async throws {
            transactionOptions.feePaymentAddress = try await getFeePaymentAddress(title: "Source Address (from)")
            transactionOptions.toAddress = try await getDestinationAddress(title: "Destination Address (to)")

            // Query UTxOs to build an asset picker
            let config = try await MultitoolConfig.load()
            let cardanoConfig = try getCardanoConfig(config: config)
            try await resolveAdaHandles(network: cardanoConfig.network)
            let context = try await getContext(config: config)

            guard let feePaymentAddress = transactionOptions.feePaymentAddress else {
                throw ValidationError("Source address is required.")
            }

            let utxos = try await queryAndFilterUtxos(
                feePaymentAddress: feePaymentAddress.info,
                context: context,
                config: config
            )

            // Collect available assets: (policyId hex, assetNameHex, total amount)
            var assetMap: [(policyId: String, assetNameHex: String, totalAmount: Int64)] = []
            for utxo in utxos {
                for (scriptHash, asset) in utxo.output.amount.multiAsset.data {
                    for (assetName, qty) in asset.data {
                        let pid = scriptHash.payload.toHex
                        let nameHex = assetName.payload.toHex
                        if let idx = assetMap.firstIndex(where: { $0.policyId == pid && $0.assetNameHex == nameHex }) {
                            assetMap[idx].totalAmount += qty
                        } else {
                            assetMap.append((policyId: pid, assetNameHex: nameHex, totalAmount: qty))
                        }
                    }
                }
            }

            if assetMap.isEmpty {
                noora.warning(.alert(
                    "No native assets found at source address.",
                    takeaway: "You can still enter the asset details manually."
                ))

                policyId = noora.textPrompt(
                    title: "Policy ID",
                    prompt: "Enter the policy ID (56-char hex):",
                    collapseOnAnswer: true,
                    validationRules: [NonEmptyValidationRule(error: "Policy ID cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines)

                assetNameHex = noora.textPrompt(
                    title: "Asset Name Hex",
                    prompt: "Enter the asset name in hex:",
                    collapseOnAnswer: true
                ).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                // Show picker with all available assets
                let options = assetMap.map { entry -> String in
                    let nameText = entry.assetNameHex.isEmpty ? "(no name)" : entry.assetNameHex
                    return "\(entry.policyId).\(nameText) — \(entry.totalAmount) available"
                }

                let usePickerOrManual = noora.yesOrNoChoicePrompt(
                    title: "Asset Selection",
                    question: "Pick from available assets at source address?",
                    defaultAnswer: true,
                    description: "Select 'No' to enter a policy ID and asset name manually."
                )

                if usePickerOrManual {
                    let picked = noora.singleChoicePrompt(
                        title: "Select Asset",
                        question: "Which asset would you like to send?",
                        options: options,
                        description: "Assets available at source address:"
                    )
                    let pickedIdx = options.firstIndex(of: picked)!
                    policyId = assetMap[pickedIdx].policyId
                    assetNameHex = assetMap[pickedIdx].assetNameHex
                } else {
                    policyId = noora.textPrompt(
                        title: "Policy ID",
                        prompt: "Enter the policy ID (56-char hex):",
                        collapseOnAnswer: true,
                        validationRules: [NonEmptyValidationRule(error: "Policy ID cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)

                    assetNameHex = noora.textPrompt(
                        title: "Asset Name Hex",
                        prompt: "Enter the asset name in hex:",
                        collapseOnAnswer: true
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            amount = noora.textPrompt(
                title: "Amount",
                prompt: "Enter amount to send ('all', 'min', or a positive integer):",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Amount cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            let lovelaceInput = noora.textPrompt(
                title: "ADA to Bundle",
                prompt: "ADA/lovelace to bundle with the asset (e.g., 2 ADA, 2000000 lovelace; leave blank for protocol minimum):",
                collapseOnAnswer: true
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            if !lovelaceInput.isEmpty,
               let parsed = AdaFormatter(defaultUnit: .ada).toLovelace(lovelaceInput) {
                lovelaceAmount = parsed
            }

            try await self.wizardForTransaction()
            try self.validate()
        }

        // MARK: - Run

        mutating func run() async throws {
            if policyId == nil {
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
                  let policyId, let assetNameHex, let amount else {
                throw ValidationError("Required arguments missing. Run without arguments for wizard mode.")
            }

            spacedPrint("\n\(.primary("━━━ Send Assets Transaction ━━━"))\n")

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

            // Find the target asset across UTXOs
            let policyData = policyId.hexStringToData
            let scriptHash = ScriptHash(payload: policyData)
            let targetAssetNameData = assetNameHex.hexStringToData
            let targetAssetName = try AssetName(payload: targetAssetNameData)

            var totalAvailable: Int64 = 0
            for utxo in utxos {
                if let assetUnderPolicy = utxo.output.amount.multiAsset.data[scriptHash],
                   let qty = assetUnderPolicy.data[targetAssetName] {
                    totalAvailable += qty
                }
            }

            guard totalAvailable > 0 else {
                noora.error(.alert(
                    "Asset not found at source address.",
                    takeaways: [
                        "Policy: \(policyId)",
                        "Asset Name (hex): \(assetNameHex.isEmpty ? "(empty)" : assetNameHex)",
                        "Available: 0"
                    ]
                ))
                throw ExitCode.failure
            }

            // Resolve amount
            let resolvedAmount: Int64
            let amountLower = amount.lowercased()
            switch amountLower {
            case "all":
                resolvedAmount = totalAvailable
            case "min":
                resolvedAmount = 1
            default:
                guard let n = Int64(amount), n > 0 else {
                    noora.error(.alert("Invalid amount '\(amount)'. Must be 'all', 'min', or a positive integer."))
                    throw ExitCode.validationFailure
                }
                resolvedAmount = n
            }

            guard resolvedAmount <= totalAvailable else {
                noora.error(.alert(
                    "Not enough tokens.",
                    takeaways: [
                        "Requested: \(resolvedAmount)",
                        "Available: \(totalAvailable)"
                    ]
                ))
                throw ExitCode.failure
            }

            // Build asset output
            var assetOut = MultiAsset([:])
            assetOut.data[scriptHash] = Asset([targetAssetName: resolvedAmount])

            // Calculate minimum lovelace for this output
            let draftOutput = TransactionOutput(
                address: toAddress.info.address!,
                amount: Value(coin: 1_000_000, multiAsset: assetOut)
            )
            let minLovelace = try await Utils.minLovelacePostAlonzo(draftOutput, context)
            let resolvedLovelace = max(lovelaceAmount ?? minLovelace, minLovelace)

            noora.info(.alert(
                "Sending asset with the following details:",
                takeaways: [
                    "Policy ID: \(.primary(policyId))",
                    "Asset Name (hex): \(.primary(assetNameHex.isEmpty ? "(empty)" : assetNameHex))",
                    "Amount: \(.primary("\(resolvedAmount)")) of \(.primary("\(totalAvailable)")) available",
                    "Lovelaces bundled: \(.primary(lovelaceToAdaFormatString(resolvedLovelace))) / \(.primary("\(resolvedLovelace)")) lovelaces",
                    "From: \(feePaymentAddress.info.description)",
                    "To: \(toAddress.info.description)",
                ]
            ))

            let txOut = TransactionOutput(
                address: toAddress.info.address!,
                amount: Value(coin: Int64(resolvedLovelace), multiAsset: assetOut)
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
