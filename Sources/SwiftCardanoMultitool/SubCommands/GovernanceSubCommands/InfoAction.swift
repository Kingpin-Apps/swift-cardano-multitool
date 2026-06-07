import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore

extension GovernanceMainCommand {
    struct InfoAction: TransactionSendable {
        static let configuration = CommandConfiguration(
            commandName: "info-action",
            abstract: "Build + submit a Conway info-action governance proposal.",
            usage: """
            scm governance info-action \\
                --anchor-url ipfs://… --anchor-hash <64-hex> \\
                --deposit-return-stake-address owner.stake \\
                --fee-payment-address owner.payment --submit

            scm governance info-action
                # interactive wizard prompts for every required field
            """,
            discussion: """
            An info action has no on-chain effect — it just records its anchor
            (CIP-100 metadata) for off-chain observers. Pass --generate-only to
            emit just the .action file without building a transaction.
            """
        )

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

            let inputs = GovernanceActionInputs(
                payload: .infoAction,
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
