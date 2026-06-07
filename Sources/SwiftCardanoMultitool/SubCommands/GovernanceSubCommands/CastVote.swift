import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoCore
import SwiftCardanoUtils
import SwiftCardanoChain
import SwiftCardanoTxBuilder

extension GovernanceMainCommand {
    struct Vote: TransactionSendable {
        static let configuration = CommandConfiguration(
            commandName: "vote",
            abstract: "Cast a Conway-era on-chain vote (DRep / SPO / CC hot).",
            usage: """
            scm governance vote gov_action1xyz... yes \\
                --voter-vkey-file myDRep.drep.vkey \\
                --fee-payment-address owner.payment --submit

            scm governance vote
                # interactive wizard prompts for every required field
            """,
            discussion: """
            Loads the voter verification key (.drep.vkey / .node.vkey / .cc-hot.vkey),
            locates its matching .skey or .hwsfile, builds a balanced transaction with
            a single voting procedure, signs with both the payment and voter keys, and
            (with --submit) submits to the configured network.

            The voter role is inferred from the file extension; pass --voter-role to
            override. An optional CIP-100 anchor (URL + 64-hex blake2b hash) is
            verified by default before submission — use --skip-anchor-verify to bypass.
            """
        )

        // MARK: - Required (positional OR flag-based)

        @Argument(help: "Governance action ID: bech32 (gov_action1…), hex, or txHash#index.")
        var govActionId: String?

        @Argument(help: "Vote choice: yes | no | abstain.")
        var choice: VoteChoice?

        // MARK: - Voter

        @Option(name: .long, help: "Voter verification key file (.drep.vkey / .node.vkey / .cc-hot.vkey).")
        var voterVkeyFile: FilePath?

        @Option(name: .long, help: "Override the voter role inferred from the vkey file extension.")
        var voterRole: VoterRole?

        // MARK: - Anchor

        @Option(name: .long, help: "Optional anchor URL (CIP-100 vote rationale).")
        var anchorUrl: String?

        @Option(name: .long, help: "Anchor blake2b-256 hash (64 hex chars). Required if --anchor-url is set.")
        var anchorHash: String?

        @Flag(name: .long, help: "Skip download + blake2b + CIP-100 verification of the anchor.")
        var skipAnchorVerify: Bool = false

        // MARK: - TTL controls

        @Option(name: .long, help: "Extra slots added to chain tip when computing TTL (default: 500).")
        var ttlExtra: UInt64 = 500

        @Option(name: .long, help: "Override TTL with an absolute slot (skips tip + extra computation).")
        var ttlOverride: UInt64?

        // MARK: - Output

        @Option(name: [.short, .long], help: "Output file for the signed transaction. Defaults to <voterName>-<timestamp>.vote.signed.tx.")
        var outFile: FilePath?

        // MARK: - Shared

        @OptionGroup var transactionOptions: SharedTransactionOptions

        // MARK: - Validation

        mutating func validate() throws {
            // Anchor flags must be both-or-neither.
            if (anchorUrl == nil) != (anchorHash == nil) {
                throw ValidationError("--anchor-url and --anchor-hash must both be provided, or neither.")
            }

            try self.validateForTransaction()
        }

        // MARK: - Wizard

        mutating func wizard() async throws {
            // 1. Governance action ID
            if govActionId == nil {
                let input = noora.textPrompt(
                    title: "Governance Action ID",
                    prompt: "Enter the governance action ID:",
                    description: "Bech32 (gov_action1…), hex, or <txHash>#<index>.",
                    collapseOnAnswer: true,
                    validationRules: [NonEmptyValidationRule(error: "Governance action ID cannot be empty.")]
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                govActionId = input
            }

            // 2. Voter vkey file
            if voterVkeyFile == nil {
                voterVkeyFile = try selectVoterVKeyInteractive()
            }

            // 3. Confirm or override role
            if voterRole == nil {
                let inferred = try inferVoterRole(from: voterVkeyFile!)
                let confirm = noora.yesOrNoChoicePrompt(
                    title: "Voter Role",
                    question: "Use inferred role '\(inferred.name)'?",
                    defaultAnswer: true,
                    description: "Inferred from the vkey filename suffix."
                )
                if confirm {
                    voterRole = inferred
                } else {
                    voterRole = noora.singleChoicePrompt(
                        title: "Voter Role",
                        question: "Pick the voter role:",
                        options: VoterRole.allCases
                    )
                }
            }

            // 4. Vote choice
            if choice == nil {
                choice = noora.singleChoicePrompt(
                    title: "Vote",
                    question: "How do you vote?",
                    options: VoteChoice.allCases
                )
            }

            // 5. Anchor (optional)
            if anchorUrl == nil && anchorHash == nil {
                if let anchor = try await getOptionalAnchor(purpose: "vote rationale") {
                    anchorUrl = anchor.anchorUrl.absoluteString
                    anchorHash = anchor.anchorDataHash.payload.toHex
                }
            }

            // 6. Fee payment address
            if transactionOptions.feePaymentAddress == nil {
                transactionOptions.feePaymentAddress = try await getFeePaymentAddress(
                    title: "Fee Payment Address"
                )
            }

            try await self.wizardForTransaction()
            try self.validate()
        }

        // MARK: - Run

        mutating func run() async throws {
            if govActionId == nil
                || choice == nil
                || voterVkeyFile == nil
                || transactionOptions.feePaymentAddress == nil {
                try await wizard()
            }

            guard let govActionIdStr = govActionId,
                  let choice,
                  let voterVkeyFile else {
                throw ValidationError("Required arguments missing. Run without arguments for wizard mode.")
            }

            guard let parsedGovActionId = SwiftCardanoCore.GovActionID(argument: govActionIdStr) else {
                noora.error(.alert(
                    "Could not parse governance action ID: \(.danger(govActionIdStr))",
                    takeaways: [
                        "Use bech32 (gov_action1…), hex bytes, or <txHash>#<index>."
                    ]
                ))
                throw ExitCode.validationFailure
            }

            let voter = try loadVoterKey(vkeyPath: voterVkeyFile, roleOverride: voterRole)
            let anchor = try parseAnchorArguments(url: anchorUrl, hash: anchorHash)

            let inputs = VoteCastInputs(
                govActionId: parsedGovActionId,
                voter: voter,
                choice: choice.asCoreVote,
                anchor: anchor,
                skipAnchorVerify: skipAnchorVerify,
                ttlExtra: ttlExtra,
                ttlOverride: ttlOverride
            )

            var localOutFile = outFile
            try await runCastVote(inputs: inputs, outFile: &localOutFile)
            outFile = localOutFile
        }
    }
}
