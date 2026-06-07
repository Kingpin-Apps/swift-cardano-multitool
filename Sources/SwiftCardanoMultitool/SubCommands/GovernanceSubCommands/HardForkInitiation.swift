import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore

extension GovernanceMainCommand {
    struct HardForkInitiation: TransactionSendable {
        static let configuration = CommandConfiguration(
            commandName: "hard-fork-initiation",
            abstract: "Build + submit a hard-fork-initiation governance proposal.",
            usage: """
            scm governance hard-fork-initiation \\
                --protocol-version 10.0 \\
                --anchor-url ipfs://… --anchor-hash <64-hex> \\
                --deposit-return-stake-address owner.stake \\
                --fee-payment-address owner.payment --submit
            """,
            discussion: """
            --protocol-version takes the form <major>.<minor> (e.g. 10.0).
            Validation against current chain state (cannot fork backward, major
            bumps must be +1, minor must be 0 on a major bump) is left to the
            ledger — the bash script's local sanity checks are not duplicated here.
            """
        )

        @Option(name: .long, help: "Target protocol version, formatted as <major>.<minor> (e.g. 10.0).")
        var protocolVersion: String?

        @Option(name: .long, help: "Previous HardFork gov-action ID (bech32, hex, or txHash#index).")
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

            if protocolVersion == nil {
                protocolVersion = noora.textPrompt(
                    title: "Target Protocol Version",
                    prompt: "Enter the target protocol version (e.g. 10.0):",
                    collapseOnAnswer: true,
                    validationRules: [NonEmptyValidationRule(error: "Protocol version cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if prevActionId == nil {
                let input = noora.textPrompt(
                    title: "Previous HardFork Action ID",
                    prompt: "Enter the previous hard-fork gov-action ID (blank to skip):",
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
            if protocolVersion == nil
                || actionOptions.depositReturnStakeAddress == nil
                || transactionOptions.feePaymentAddress == nil
                || (actionOptions.anchorUrl == nil && actionOptions.anchorHash == nil) {
                try await wizard()
            }

            let anchor = try await actionOptions.resolveAnchorInteractively()
            let stakeAddr = try await actionOptions.resolveDepositReturnStakeAddressInteractively()
            let prevId = try parseGovActionID(prevActionId)

            guard let pv = protocolVersion else {
                throw ValidationError("--protocol-version is required.")
            }
            let parts = pv.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2,
                  let major = Int(parts[0]),
                  let minor = Int(parts[1]),
                  major >= 0, minor >= 0
            else {
                throw ValidationError("--protocol-version must be <major>.<minor> (e.g. 10.0), got '\(pv)'.")
            }

            let inputs = GovernanceActionInputs(
                payload: .hardForkInitiation(prevActionID: prevId, major: major, minor: minor),
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
