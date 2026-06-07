import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore

extension GovernanceMainCommand {
    struct NewConstitution: TransactionSendable {
        static let configuration = CommandConfiguration(
            commandName: "new-constitution",
            abstract: "Build + submit a new-constitution governance proposal.",
            usage: """
            scm governance new-constitution \\
                --constitution-url https://… --constitution-hash <64-hex> \\
                --anchor-url ipfs://… --anchor-hash <64-hex> \\
                --prev-action-id gov_action1… \\
                --deposit-return-stake-address owner.stake \\
                --fee-payment-address owner.payment --submit
            """,
            discussion: """
            The constitution itself (URL + 64-hex hash) is separate from the
            CIP-100 anchor — the bash duo prompts for both as `url:` and
            `constitution-url:`. --constitution-script-hash attaches an optional
            guardrails script.
            """
        )

        @Option(name: .long, help: "Constitution document URL.")
        var constitutionUrl: String?

        @Option(name: .long, help: "Constitution document blake2b-256 hash (64 hex chars).")
        var constitutionHash: String?

        @Option(name: .long, help: "Optional guardrails script hash (56 hex chars).")
        var constitutionScriptHash: String?

        @Option(name: .long, help: "Previous Constitution gov-action ID (bech32, hex, or txHash#index).")
        var prevActionId: String?

        @OptionGroup var actionOptions: SharedGovernanceActionOptions
        @OptionGroup var transactionOptions: SharedTransactionOptions

        @Option(name: [.short, .long], help: "Output file for the signed transaction.")
        var outFile: FilePath?

        mutating func validate() throws {
            try actionOptions.validateAnchorFlags()
            if (constitutionUrl == nil) != (constitutionHash == nil) {
                throw ValidationError("--constitution-url and --constitution-hash must both be provided, or neither.")
            }
            try self.validateForTransaction()
        }

        mutating func wizard() async throws {
            _ = try await actionOptions.resolveAnchorInteractively()
            _ = try await actionOptions.resolveDepositReturnStakeAddressInteractively()

            if constitutionUrl == nil {
                constitutionUrl = noora.textPrompt(
                    title: "Constitution URL",
                    prompt: "Enter the constitution document URL:",
                    collapseOnAnswer: true,
                    validationRules: [NonEmptyValidationRule(error: "Constitution URL cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if constitutionHash == nil {
                constitutionHash = noora.textPrompt(
                    title: "Constitution Hash",
                    prompt: "Enter the constitution blake2b-256 hash (64 hex chars):",
                    collapseOnAnswer: true,
                    validationRules: [NonEmptyValidationRule(error: "Constitution hash cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }

            if prevActionId == nil {
                let input = noora.textPrompt(
                    title: "Previous Constitution Action ID",
                    prompt: "Enter the previous constitution-related gov-action ID (blank to skip):",
                    collapseOnAnswer: true
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                if !input.isEmpty { prevActionId = input }
            }

            if transactionOptions.feePaymentAddress == nil {
                transactionOptions.feePaymentAddress = try await getFeePaymentAddress(
                    title: "Fee Payment Address"
                )
            }

            try await self.wizardForTransaction()
            try self.validate()
        }

        mutating func run() async throws {
            if constitutionUrl == nil || constitutionHash == nil
                || actionOptions.depositReturnStakeAddress == nil
                || transactionOptions.feePaymentAddress == nil
                || (actionOptions.anchorUrl == nil && actionOptions.anchorHash == nil) {
                try await wizard()
            }

            let anchor = try await actionOptions.resolveAnchorInteractively()
            let stakeAddr = try await actionOptions.resolveDepositReturnStakeAddressInteractively()
            let prevId = try parseGovActionID(prevActionId)
            let scriptHash = try parseScriptHash(constitutionScriptHash)

            guard let url = constitutionUrl, let hash = constitutionHash else {
                throw ValidationError("Constitution URL and hash are required.")
            }
            let lowerHash = hash.lowercased()
            guard lowerHash.count == 64, lowerHash.allSatisfy({ $0.isHexDigit }) else {
                throw ValidationError("--constitution-hash must be 64 hex chars, got '\(hash)'.")
            }

            let inputs = GovernanceActionInputs(
                payload: .newConstitution(
                    prevActionID: prevId,
                    constitutionUrl: url,
                    constitutionHash: lowerHash,
                    scriptHash: scriptHash
                ),
                depositReturnStakeAddress: stakeAddr,
                deposit: actionOptions.deposit,
                anchor: anchor,
                skipAnchorVerify: actionOptions.skipAnchorVerify,
                ttlExtra: actionOptions.ttlExtra,
                ttlOverride: actionOptions.ttlOverride,
                generateOnly: actionOptions.generateOnly,
                actionOutFile: actionOptions.actionOutFile
            )

            var localOutFile = outFile
            try await runCreateGovernanceAction(inputs: inputs, outFile: &localOutFile)
            outFile = localOutFile
        }
    }
}
