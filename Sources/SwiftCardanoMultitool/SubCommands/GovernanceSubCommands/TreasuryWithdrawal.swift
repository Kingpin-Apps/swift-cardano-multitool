import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore

extension GovernanceMainCommand {
    struct TreasuryWithdrawal: TransactionSendable {
        static let configuration = CommandConfiguration(
            commandName: "treasury-withdrawal",
            abstract: "Build + submit a treasury-withdrawal governance proposal.",
            usage: """
            scm governance treasury-withdrawal \\
                --withdrawal stake1...:1000000000 \\
                --anchor-url ipfs://… --anchor-hash <64-hex> \\
                --deposit-return-stake-address owner.stake \\
                --fee-payment-address owner.payment --submit
            """,
            discussion: """
            Each --withdrawal flag takes the form <stakeAddrOrFile>:<lovelaces>
            and may be repeated to fund multiple stake addresses in one action.

            --guardrails-script-hash is required when the network's constitution
            has a guardrails script attached.
            """
        )

        @Option(
            name: .long,
            parsing: .upToNextOption,
            help: "Withdrawal target as <stakeAddrOrFile>:<lovelaces>. Repeat for multiple recipients."
        )
        var withdrawal: [String] = []

        @Option(name: .long, help: "Constitution guardrails script hash (56-hex). Required when the network has one.")
        var guardrailsScriptHash: String?

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

            if withdrawal.isEmpty {
                repeat {
                    let stakeStr = noora.textPrompt(
                        title: "Withdrawal Target",
                        prompt: "Enter the recipient stake address (bech32 or .stake.addr file path):",
                        collapseOnAnswer: true,
                        validationRules: [NonEmptyValidationRule(error: "Stake address cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)

                    let amtStr = noora.textPrompt(
                        title: "Withdrawal Amount",
                        prompt: "Lovelaces to withdraw to \(stakeStr):",
                        collapseOnAnswer: true,
                        validationRules: [NonEmptyValidationRule(error: "Amount cannot be empty.")]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)

                    withdrawal.append("\(stakeStr):\(amtStr)")
                } while noora.yesOrNoChoicePrompt(
                    title: "Another?",
                    question: "Add another withdrawal recipient?",
                    defaultAnswer: false
                )
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
            if withdrawal.isEmpty
                || actionOptions.depositReturnStakeAddress == nil
                || transactionOptions.feePaymentAddress == nil
                || (actionOptions.anchorUrl == nil && actionOptions.anchorHash == nil) {
                try await wizard()
            }

            let anchor = try await actionOptions.resolveAnchorInteractively()
            let stakeAddr = try await actionOptions.resolveDepositReturnStakeAddressInteractively()
            let scriptHash = try parseScriptHash(guardrailsScriptHash)

            var entries: [TreasuryWithdrawalEntry] = []
            for raw in withdrawal {
                let parts = raw.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                guard parts.count == 2 else {
                    throw ValidationError("Withdrawal must be <stakeAddrOrFile>:<lovelaces>, got '\(raw)'.")
                }
                let stakeArg = String(parts[0])
                let amtStr = String(parts[1])
                guard let amount = UInt64(amtStr) else {
                    throw ValidationError("Could not parse lovelace amount '\(amtStr)' in withdrawal '\(raw)'.")
                }
                guard let parsed = StakeAddressInfo(argument: stakeArg) else {
                    throw ValidationError("Could not resolve stake address '\(stakeArg)' in withdrawal '\(raw)'.")
                }
                guard let address = parsed.info.address else {
                    throw ValidationError("Resolved stake address has no underlying Address: '\(stakeArg)'.")
                }
                let bech32 = (try? address.toBech32()) ?? ""
                entries.append(TreasuryWithdrawalEntry(
                    stakeAddressBech32: bech32,
                    stakeAddress: address,
                    amount: amount
                ))
            }

            let inputs = GovernanceActionInputs(
                payload: .treasuryWithdrawal(withdrawals: entries, guardrailsScriptHash: scriptHash),
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
