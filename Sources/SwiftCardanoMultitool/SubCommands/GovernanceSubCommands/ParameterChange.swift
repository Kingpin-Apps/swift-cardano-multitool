import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore

extension GovernanceMainCommand {
    struct ParameterChange: TransactionSendable {
        static let configuration = CommandConfiguration(
            commandName: "parameter-change",
            abstract: "Build + submit a protocol-parameter-update governance proposal.",
            usage: """
            scm governance parameter-change \\
                --param-update-json my-update.json \\
                --anchor-url ipfs://… --anchor-hash <64-hex> \\
                --prev-action-id gov_action1… \\
                --deposit-return-stake-address owner.stake \\
                --fee-payment-address owner.payment --submit
            """,
            discussion: """
            The 41 individual `param-name: value` knobs of the bash script are
            replaced with a single JSON file matching the SwiftCardanoCore
            ProtocolParamUpdate struct. Set just the fields you want changed —
            unset fields are left untouched. Example minimal file:

                {"minPoolCost": 170000000}

            cardano-cli mode is supported for the most common fields. Cost
            models / ex-units / voting thresholds require SwiftCardano mode.
            """
        )

        @Option(name: .long, help: "JSON file containing the ProtocolParamUpdate body.")
        var paramUpdateJson: FilePath?

        @Option(name: .long, help: "Optional guardrails (constitution) script hash (56 hex chars).")
        var guardrailsScriptHash: String?

        @Option(name: .long, help: "Previous ParameterChange gov-action ID (bech32, hex, or txHash#index).")
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

            if paramUpdateJson == nil {
                let input = noora.textPrompt(
                    title: "Param Update JSON",
                    prompt: "Path to a JSON file containing the protocol-param update body:",
                    description: "Example: {\"minPoolCost\": 170000000}",
                    collapseOnAnswer: true,
                    validationRules: [NonEmptyValidationRule(error: "Path cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                paramUpdateJson = FilePath(input)
            }

            if prevActionId == nil {
                let input = noora.textPrompt(
                    title: "Previous ParameterChange Action ID",
                    prompt: "Enter the previous parameter-change gov-action ID (blank to skip):",
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
            if paramUpdateJson == nil
                || actionOptions.depositReturnStakeAddress == nil
                || transactionOptions.feePaymentAddress == nil
                || (actionOptions.anchorUrl == nil && actionOptions.anchorHash == nil) {
                try await wizard()
            }

            let anchor = try await actionOptions.resolveAnchorInteractively()
            let stakeAddr = try await actionOptions.resolveDepositReturnStakeAddressInteractively()
            let prevId = try parseGovActionID(prevActionId)
            let scriptHash = try parseScriptHash(guardrailsScriptHash)

            guard let jsonPath = paramUpdateJson else {
                throw ValidationError("--param-update-json is required.")
            }
            let update = try loadProtocolParamUpdate(from: jsonPath)

            let inputs = GovernanceActionInputs(
                payload: .parameterChange(
                    prevActionID: prevId,
                    update: update,
                    guardrailsScriptHash: scriptHash
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
