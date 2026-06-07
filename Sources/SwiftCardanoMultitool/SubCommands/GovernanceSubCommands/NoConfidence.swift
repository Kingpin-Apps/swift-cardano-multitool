import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore

extension GovernanceMainCommand {
    struct NoConfidence: TransactionSendable {
        static let configuration = CommandConfiguration(
            commandName: "no-confidence",
            abstract: "Build + submit a no-confidence motion against the constitutional committee.",
            usage: """
            scm governance no-confidence \\
                --anchor-url ipfs://… --anchor-hash <64-hex> \\
                --prev-action-id gov_action1… \\
                --deposit-return-stake-address owner.stake \\
                --fee-payment-address owner.payment --submit
            """,
            discussion: """
            --prev-action-id is the most recent enacted Committee action — required
            on the SwiftCardano path, optional on --use-cardano-cli (the CLI infers
            it from the on-chain gov-state when omitted).
            """
        )

        @Option(name: .long, help: "Previous Committee gov-action ID (bech32, hex, or txHash#index).")
        var prevActionId: String?

        @OptionGroup var actionOptions: SharedGovernanceActionOptions
        @OptionGroup var transactionOptions: SharedTransactionOptions

        @Option(name: [.short, .long], help: "Output file for the signed transaction.")
        var outFile: FilePath?

        mutating func validate() throws {
            try actionOptions.validateAnchorFlags()
            try self.validateForTransaction()
        }

        mutating func wizard() async throws {
            _ = try await actionOptions.resolveAnchorInteractively()
            _ = try await actionOptions.resolveDepositReturnStakeAddressInteractively()

            if prevActionId == nil {
                let input = noora.textPrompt(
                    title: "Previous Committee Action ID",
                    prompt: "Enter the previous committee-related gov-action ID (or leave blank to skip):",
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
            if actionOptions.depositReturnStakeAddress == nil
                || transactionOptions.feePaymentAddress == nil
                || (actionOptions.anchorUrl == nil && actionOptions.anchorHash == nil) {
                try await wizard()
            }

            let anchor = try await actionOptions.resolveAnchorInteractively()
            let stakeAddr = try await actionOptions.resolveDepositReturnStakeAddressInteractively()
            let prevId = try parseGovActionID(prevActionId)

            let inputs = GovernanceActionInputs(
                payload: .noConfidence(prevActionID: prevId),
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
