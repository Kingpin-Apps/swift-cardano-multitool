import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoChain
import SwiftCardanoCore

extension QueryMainCommand {
    struct GovernanceAction: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "governance-action",
            abstract: "Query on-chain state for a governance action.",
            aliases: ["gov-action", "ga"]
        )

        @Argument(help: "Governance action ID: bech32 (gov_action1…), hex bytes, or <txHash>#<index>.")
        var govActionID: SwiftCardanoCore.GovActionID? = nil

        mutating func wizard() async throws {
            let input = noora.textPrompt(
                title: "Governance Action ID",
                prompt: "Enter the governance action ID:",
                description: "Accepted formats:\n  • Bech32: gov_action1...\n  • <txHash-hex>#<index> (e.g. abc...def#0)\n  • Raw hex bytes",
                collapseOnAnswer: true,
                validationRules: [NonEmptyValidationRule(error: "Governance action ID cannot be empty.")]
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            guard let parsed = SwiftCardanoCore.GovActionID(argument: input) else {
                noora.error(.alert(
                    "Could not parse governance action ID: \(.danger(input))",
                    takeaways: [
                        "Use bech32 (gov_action1...), hex bytes, or <txHash>#<index>.",
                    ]
                ))
                throw ExitCode.validationFailure
            }
            govActionID = parsed
        }

        mutating func run() async throws {
            if govActionID == nil {
                try await wizard()
            }

            guard let govActionID = govActionID else {
                noora.error(.alert(
                    "Governance action ID is required.",
                    takeaways: [
                        "Provide a bech32 gov_action1..., hex bytes, or <txHash>#<index>.",
                        "Run with no argument to enter interactive mode.",
                    ]
                ))
                throw ExitCode.validationFailure
            }

            let config = try await MultitoolConfig.load()
            let cardanoConfig = try getCardanoConfig(config: config)
            let context = try await getContext(config: config)

            try await printContextInfo(config: config, context: context)

            try govActionIdSummary(govActionID: govActionID)
            print()

            let info = try await noora.progressStep(
                message: "Querying governance-action info...",
                successMessage: "Successfully retrieved governance-action info.",
                errorMessage: "Failed to retrieve governance-action info.",
                showSpinner: true
            ) { _ in
                try await context.govActionInfo(govActionID: govActionID)
            }
            print()

            let currentEpoch = try await noora.progressStep(
                message: "Querying current epoch...",
                successMessage: "Current epoch retrieved.",
                errorMessage: "Failed to retrieve current epoch.",
                showSpinner: true
            ) { _ in
                try await context.epoch()
            }
            print()

            try govActionInfoSummary(
                info: info,
                currentEpoch: currentEpoch,
                context: context
            )

            // Explorer link — currently throws notImplemented for every concrete explorer
            // (protocol method exists, no per-explorer impls yet), so wrap in try?.
            let explorer = config.blockchainExplorer.explorer(network: cardanoConfig.network)
            if let url = try? explorer.viewGovernanceAction(govActionID: govActionID) {
                print()
                spacedPrint("\(.link(title: url.absoluteString, href: url.absoluteString))")
            }
        }
    }
}
