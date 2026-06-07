import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore

extension GovernanceMainCommand {
    struct UpdateCommittee: TransactionSendable {
        static let configuration = CommandConfiguration(
            commandName: "update-committee",
            abstract: "Build + submit an update-committee governance proposal.",
            usage: """
            scm governance update-committee \\
                --threshold 2/3 \\
                --add <56-hex-cold-key-hash>:<termEpoch> \\
                --remove <56-hex-cold-key-hash> \\
                --anchor-url ipfs://… --anchor-hash <64-hex> \\
                --deposit-return-stake-address owner.stake \\
                --fee-payment-address owner.payment --submit
            """,
            discussion: """
            --threshold takes a rational (e.g. 2/3 or 0.66).
            --add / --add-script add a cold credential, each requiring a term
            end epoch. --remove / --remove-script drop a credential. Repeat
            flags as needed.
            """
        )

        @Option(name: .long, help: "Acceptance threshold as a rational (e.g. 2/3) or decimal 0…1.")
        var threshold: String?

        @Option(name: .long, parsing: .upToNextOption, help: "Add a cold key-hash credential as <56-hex-hash>:<termEpoch>. Repeatable.")
        var add: [String] = []

        @Option(name: .long, parsing: .upToNextOption, help: "Remove a cold key-hash credential by 56-hex hash. Repeatable.")
        var remove: [String] = []

        @Option(name: .long, parsing: .upToNextOption, help: "Add a cold script-hash credential as <56-hex-hash>:<termEpoch>. Repeatable.")
        var addScript: [String] = []

        @Option(name: .long, parsing: .upToNextOption, help: "Remove a cold script-hash credential by 56-hex hash. Repeatable.")
        var removeScript: [String] = []

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

            if threshold == nil {
                threshold = noora.textPrompt(
                    title: "Threshold",
                    prompt: "Enter the acceptance threshold (e.g. 2/3 or 0.66):",
                    collapseOnAnswer: true,
                    validationRules: [NonEmptyValidationRule(error: "Threshold cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if prevActionId == nil {
                let input = noora.textPrompt(
                    title: "Previous Committee Action ID",
                    prompt: "Enter the previous committee-related gov-action ID (blank to skip):",
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
            if threshold == nil
                || actionOptions.depositReturnStakeAddress == nil
                || transactionOptions.feePaymentAddress == nil
                || (actionOptions.anchorUrl == nil && actionOptions.anchorHash == nil) {
                try await wizard()
            }

            let anchor = try await actionOptions.resolveAnchorInteractively()
            let stakeAddr = try await actionOptions.resolveDepositReturnStakeAddressInteractively()
            let prevId = try parseGovActionID(prevActionId)

            guard let thrStr = threshold else {
                throw ValidationError("--threshold is required.")
            }
            let interval = try parseUnitInterval(thrStr)

            var additions: [CommitteeAddition] = []
            for raw in add {
                let (cred, hex, epoch) = try parseAddSpec(raw, isScript: false)
                additions.append(CommitteeAddition(
                    credential: cred,
                    termEpoch: epoch,
                    hashHex: hex,
                    isScriptHash: false
                ))
            }
            for raw in addScript {
                let (cred, hex, epoch) = try parseAddSpec(raw, isScript: true)
                additions.append(CommitteeAddition(
                    credential: cred,
                    termEpoch: epoch,
                    hashHex: hex,
                    isScriptHash: true
                ))
            }

            var removals: [CommitteeColdCredential] = []
            for raw in remove {
                let (cred, _) = try parseColdCredential(raw, isScript: false)
                removals.append(cred)
            }
            for raw in removeScript {
                let (cred, _) = try parseColdCredential(raw, isScript: true)
                removals.append(cred)
            }

            let inputs = GovernanceActionInputs(
                payload: .updateCommittee(
                    prevActionID: prevId,
                    threshold: interval,
                    additions: additions,
                    removals: removals
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

        /// Parse `<56-hex-hash>:<termEpoch>` into a CommitteeColdCredential + hash hex + epoch.
        private func parseAddSpec(_ raw: String, isScript: Bool) throws -> (CommitteeColdCredential, String, UInt64) {
            let parts = raw.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else {
                throw ValidationError("--add\(isScript ? "-script" : "") must be <56-hex-hash>:<termEpoch>, got '\(raw)'.")
            }
            let hashStr = String(parts[0])
            let epochStr = String(parts[1])
            guard let epoch = UInt64(epochStr) else {
                throw ValidationError("Could not parse term epoch '\(epochStr)' in '\(raw)'.")
            }
            let (cred, lowerHex) = try parseColdCredential(hashStr, isScript: isScript)
            return (cred, lowerHex, epoch)
        }
    }
}
