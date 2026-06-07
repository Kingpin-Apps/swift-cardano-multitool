import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftCardanoChain
import SwiftCardanoTxBuilder

extension AssetMainCommand {
    struct Mint: TransactionSendable {
        static let configuration = CommandConfiguration(
            commandName: "mint",
            abstract: "Mint a native asset using a local minting policy.",
            usage: """
            scm asset mint myPolicy.MYTOK 1000 \\
                --from-address owner.payment --submit

            scm asset mint \\
                --policy-name myPolicy --asset-name MYTOK --amount 1000 \\
                --from-address owner.payment --submit
            """,
            discussion: """
            Loads <policyName>.policy.{id,script,vkey,skey|hwsfile}, builds a balanced
            transaction that mints <amount> tokens of <policyId>.<assetName> back to the
            from-address, signs with both the payment and policy keys, and (with --submit)
            submits to the configured network. On success the
            <policyName>.<assetDisplay>.asset sidecar is created or its sequence number
            bumped with a "minted N tokens" audit entry.
            """
        )

        // MARK: - Identifier (positional OR flag-based)

        @Argument(help: "Combined identifier: <PolicyName>.<AssetName>. Alternative to --policy-name + --asset-name.")
        var policyAsset: String?

        @Option(name: .long, help: "Stem of the policy on disk. Loads <name>.policy.{id,script,vkey,skey|hwsfile}.")
        var policyName: String?

        @Option(name: .long, help: "Asset name. Plain ASCII (e.g. 'MYTOK') or {hex}. Max 32 bytes.")
        var assetName: String?

        // MARK: - Required

        @Option(name: .long, help: "Number of tokens to mint (positive integer).")
        var amount: UInt64?

        // MARK: - TTL controls

        @Option(name: .long, help: "Extra slots added to chain tip when computing TTL (default: 500).")
        var ttlExtra: UInt64 = 500

        @Option(name: .long, help: "Override TTL with an absolute slot (skips tip + extra computation).")
        var ttlOverride: UInt64?

        // MARK: - Output

        @Option(name: [.short, .long], help: "Output file for the signed transaction. Defaults to <addr>-<timestamp>.mint.signed.tx.")
        var outFile: FilePath?

        // MARK: - Shared

        @OptionGroup var transactionOptions: SharedTransactionOptions

        // MARK: - Validation

        mutating func validate() throws {
            if let combined = policyAsset {
                let (p, a) = splitPolicyAssetPositional(combined)
                if policyName == nil { policyName = p }
                if assetName == nil { assetName = a }
            }

            if let amount, amount == 0 {
                throw ValidationError("--amount must be greater than zero.")
            }

            try self.validateForTransaction()
        }

        // MARK: - Wizard

        mutating func wizard() async throws {
            policyName = try selectPolicyNameInteractive()

            assetName = noora.textPrompt(
                title: "Asset Name",
                prompt: "Enter the asset name:",
                description: "Plain ASCII (e.g. 'MYTOK') or {hex}. Max 32 bytes. Leave empty for the policy's default asset.",
                collapseOnAnswer: true
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            let amtStr = noora.textPrompt(
                title: "Amount",
                prompt: "Enter the number of tokens to mint:",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Amount cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let n = UInt64(amtStr), n > 0 else {
                throw ValidationError("Amount must be a positive integer, got '\(amtStr)'.")
            }
            amount = n

            transactionOptions.feePaymentAddress = try await getFeePaymentAddress(
                title: "From Address (mints to and pays fee)"
            )

            try await self.wizardForTransaction()
            try self.validate()
        }

        // MARK: - Run

        mutating func run() async throws {
            if let combined = policyAsset {
                let (p, a) = splitPolicyAssetPositional(combined)
                if policyName == nil { policyName = p }
                if assetName == nil { assetName = a }
            }

            if policyName == nil || amount == nil || transactionOptions.feePaymentAddress == nil {
                try await wizard()
            }

            guard let policyName, let amount else {
                throw ValidationError("Required arguments missing. Run without arguments for wizard mode.")
            }

            let inputs = MintBurnInputs(
                action: .mint,
                policyName: policyName,
                assetName: assetName ?? "",
                amount: amount,
                ttlExtra: ttlExtra,
                ttlOverride: ttlOverride
            )

            var localOutFile = outFile
            try await runMintOrBurn(inputs: inputs, outFile: &localOutFile)
            outFile = localOutFile
        }
    }
}
