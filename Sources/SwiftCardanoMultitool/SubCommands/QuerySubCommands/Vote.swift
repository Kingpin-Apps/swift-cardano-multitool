import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoChain
import SwiftCardanoCore
import SwiftCardanoNetwork

extension QueryMainCommand {
    struct Vote: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "vote",
            abstract: "Query votes on governance actions, filtered by voter, action ID, or action type.",
            aliases: ["votes"]
        )

        @Option(name: .customLong("voter"),
                help: "Filter to a single voter: bech32 (drep1…, pool1…, cc_cold1…, cc_hot1…, stake1…), a 56-char hex key/script hash, or a key file (.drep.id, .pool.id, .drep.vkey, .node.vkey). Stake addresses match the deposit-return address first, then fall back to the delegated DRep.")
        var voterRaw: String? = nil

        @Option(name: .customLong("action-id"),
                help: "Filter to one governance action: bech32 (gov_action1…), hex, or <txHash>#<index>.")
        var govActionID: SwiftCardanoCore.GovActionID? = nil

        @Option(name: .customLong("action-type"),
                help: "Filter by action type: parameter-change, hard-fork, treasury-withdrawal, no-confidence, update-committee, new-constitution, info.")
        var actionType: VoteActionTypeFilter? = nil

        @Flag(name: .customLong("all"),
              help: "Show every governance action with full tallies, including historical (expired/dropped/enacted) ones. Without this flag only active proposals are listed.")
        var showAll: Bool = false

        mutating func wizard(into resolvedVoter: inout VoterFilter) async throws {
            // Voter filter
            resolvedVoter = try await getVoter(title: "Voter filter")

            // Action-ID filter
            let askActionId = noora.yesOrNoChoicePrompt(
                title: "Action ID filter",
                question: "Filter by a specific governance-action ID?"
            )
            if askActionId {
                let input = noora.textPrompt(
                    title: "Governance Action ID",
                    prompt: "Enter the governance action ID:",
                    description: "Bech32 (gov_action1…), hex bytes, or <txHash>#<index>.",
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

            // Action-type filter (only meaningful if no action ID pinned the type)
            if govActionID == nil {
                let typeFilter = try await getActionTypeFilter(title: "Action type filter")
                if typeFilter != .any {
                    actionType = typeFilter
                }
            }

            // If still nothing selected, confirm "show all"
            if govActionID == nil, actionType == nil, resolvedVoter.isNone {
                let confirmAll = noora.yesOrNoChoicePrompt(
                    title: "Show all",
                    question: "No filters chosen — show all active governance actions?"
                )
                if !confirmAll {
                    noora.error(.alert(
                        "No filters selected.",
                        takeaways: ["Pick at least one filter or accept 'show all'."]
                    ))
                    throw ExitCode.validationFailure
                }
                showAll = true
            }
        }

        mutating func run() async throws {
            var resolvedVoter: VoterFilter = .none

            // Resolve voterRaw if provided
            if let voterRaw {
                resolvedVoter = try parseVoterArgument(voterRaw)
            }

            // Wizard kicks in when nothing was provided on the CLI.
            let nothingProvided = voterRaw == nil
                && govActionID == nil
                && actionType == nil
                && !showAll
            if nothingProvided {
                try await wizard(into: &resolvedVoter)
            }

            // Validate: at least one filter or --all.
            if govActionID == nil, actionType == nil, resolvedVoter.isNone, !showAll {
                noora.error(.alert(
                    "Provide at least one of --voter / --action-id / --action-type, or pass --all.",
                    takeaways: ["Run with no arguments to use the interactive wizard."]
                ))
                throw ExitCode.validationFailure
            }

            let config = try await MultitoolConfig.load()
            let cardanoConfig = try getCardanoConfig(config: config)
            let context = try await getContext(config: config)

            try await printContextInfo(config: config, context: context)

            // Shared state needed for tallies + acceptance.
            let pp = try await noora.progressStep(
                message: "Querying protocol parameters...",
                successMessage: "Protocol parameters retrieved.",
                errorMessage: "Failed to retrieve protocol parameters.",
                showSpinner: true
            ) { _ in try await context.protocolParameters() }

            let currentEpoch = try await noora.progressStep(
                message: "Querying current epoch...",
                successMessage: "Current epoch retrieved.",
                errorMessage: "Failed to retrieve current epoch.",
                showSpinner: true
            ) { _ in try await context.epoch() }

            // Stake distributions + committee state — optional via try? so backends that
            // don't implement them surface as 0-power tallies with a backend-gap warning
            // rather than failing the whole subcommand.
            let drepDistr = try? await noora.progressStep(
                message: "Querying DRep stake distribution...",
                successMessage: "DRep stake distribution retrieved.",
                errorMessage: "DRep stake distribution unavailable (backend gap).",
                showSpinner: true
            ) { _ in try await context.drepStakeDistribution() }

            let spoDistr = try? await noora.progressStep(
                message: "Querying SPO stake distribution...",
                successMessage: "SPO stake distribution retrieved.",
                errorMessage: "SPO stake distribution unavailable (backend gap).",
                showSpinner: true
            ) { _ in try await context.spoStakeDistribution() }

            let committee = try? await noora.progressStep(
                message: "Querying committee state...",
                successMessage: "Committee state retrieved.",
                errorMessage: "Committee state unavailable (backend gap).",
                showSpinner: true
            ) { _ in try await context.committeeState() }

            // Resolve proposal set.
            let proposals: [GovActionVotes]
            var hiddenHistoricalCount = 0
            if let id = govActionID {
                // Explicit ID lookup ignores the active-only filter — the user named
                // a specific action and presumably wants it shown even if it's expired.
                let idLabel = "\(id.transactionID.payload.toHex)#\(id.govActionIndex)"
                let one = try await noora.progressStep(
                    message: "Querying votes for action \(idLabel)...",
                    successMessage: "Votes retrieved.",
                    errorMessage: "Failed to retrieve votes.",
                    showSpinner: true
                ) { _ in try await context.govActionVotes(govActionID: id) }
                proposals = [one]
            } else {
                let all = try await noora.progressStep(
                    message: "Querying all governance actions...",
                    successMessage: "Governance actions retrieved.",
                    errorMessage: "Failed to retrieve governance actions.",
                    showSpinner: true
                ) { _ in try await context.govActionsAll() }

                // Apply action-type filter.
                let typeFiltered = all.filter { matchesActionType($0.govAction, filter: actionType) }

                // Apply voter filter. Stake-address voters do a two-pass match:
                // first against the deposit-return address; if empty, fall back to
                // looking up the delegated DRep via stakeAddressInfo() and re-filter.
                var voterFiltered: [GovActionVotes]
                if case .stakeAddress(let stakeCred) = resolvedVoter {
                    let byReturnAddr = typeFiltered.filter {
                        voterParticipated(in: $0, voter: .stakeAddress(stakeCred), committee: committee)
                    }
                    if byReturnAddr.isEmpty {
                        do {
                            let stakeAddr = try buildStakeAddress(
                                credential: stakeCred,
                                network: cardanoConfig.network
                            )
                            let info = try await noora.progressStep(
                                message: "No deposit-return match — resolving delegated DRep for \(stakeAddr)...",
                                successMessage: "Delegated DRep resolved.",
                                errorMessage: "Could not resolve delegated DRep.",
                                showSpinner: true
                            ) { _ in
                                try await context.stakeAddressInfo(
                                    address: try SwiftCardanoCore.Address(from: .string(stakeAddr))
                                )
                            }
                            if let drep = info.compactMap({ $0.voteDelegation }).first {
                                noora.info(.alert(
                                    "Falling back to delegated DRep: \(.primary((try? drep.toBech32()) ?? "(unprintable)"))"
                                ))
                                resolvedVoter = .drep(drep)
                                voterFiltered = typeFiltered.filter {
                                    voterParticipated(in: $0, voter: .drep(drep), committee: committee)
                                }
                            } else {
                                voterFiltered = byReturnAddr
                            }
                        } catch {
                            voterFiltered = byReturnAddr
                        }
                    } else {
                        voterFiltered = byReturnAddr
                    }
                } else if resolvedVoter.isNone {
                    voterFiltered = typeFiltered
                } else {
                    voterFiltered = typeFiltered.filter {
                        voterParticipated(in: $0, voter: resolvedVoter, committee: committee)
                    }
                }

                // Active-only filter unless --all was explicitly passed. Without this,
                // an active DRep can have voted on hundreds of historical actions and
                // we'd surface every one of them.
                if showAll {
                    proposals = voterFiltered
                } else {
                    let activeOnly = voterFiltered.filter {
                        isActive($0, currentEpoch: UInt64(currentEpoch))
                    }
                    hiddenHistoricalCount = voterFiltered.count - activeOnly.count
                    proposals = activeOnly
                }
            }

            if proposals.isEmpty {
                let takeaway: TerminalText
                if hiddenHistoricalCount > 0 {
                    let plural = hiddenHistoricalCount == 1 ? "" : "s"
                    takeaway = "\(.primary("\(hiddenHistoricalCount)")) historical (expired/dropped/enacted) action\(plural) matched but were hidden — pass \(.primary("--all")) to include them."
                } else {
                    takeaway = "Try relaxing the filters or pass \(.primary("--all")) to also include historical actions."
                }
                noora.warning(.alert(
                    "No governance actions match the given filters.",
                    takeaway: takeaway
                ))
                return
            }

            if hiddenHistoricalCount > 0 {
                let plural = hiddenHistoricalCount == 1 ? "" : "s"
                noora.info(.alert(
                    "Hiding \(.primary("\(hiddenHistoricalCount)")) historical action\(plural) (expired / dropped / enacted) — pass --all to include them."
                ))
            }

            // Render each proposal.
            let explorer = config.blockchainExplorer.explorer(network: cardanoConfig.network)
            for (idx, votes) in proposals.enumerated() {
                if idx > 0 { print() }
                noora.info(.alert("Governance Action \(idx + 1) of \(proposals.count)"))

                try govActionIdSummary(govActionID: votes.govActionId)
                print()

                try govActionInfoSummary(
                    info: votes.asGovActionInfo,
                    currentEpoch: currentEpoch,
                    context: context
                )

                if let returnAddr = rewardAccountBech32(votes.depositReturnAddr) {
                    spacedPrint("Deposit return to Stake-Addr ► \(.primary(returnAddr))")
                }

                // Anchor verification — gated on online mode + non-nil anchor.
                // SCM_SKIP_ANCHOR=1 short-circuits the IPFS/HTTP fetch for smoke testing
                // the tally renderer when anchor URLs are slow or unreachable.
                let skipAnchor = ProcessInfo.processInfo.environment["SCM_SKIP_ANCHOR"] == "1"
                if let anchor = votes.anchor, config.mode != .offline, !skipAnchor {
                    print()
                    try await verifyAnchor(anchor: anchor, config: config, kind: .voteRationale)
                } else if votes.anchor != nil, skipAnchor {
                    spacedPrint("\(.muted("(Anchor verification skipped — SCM_SKIP_ANCHOR=1)"))")
                }

                print()
                try printVoteTally(
                    votes: votes,
                    pp: pp,
                    drepDistr: drepDistr,
                    spoDistr: spoDistr,
                    committee: committee,
                    voterHighlight: resolvedVoter
                )

                if let url = try? explorer.viewGovernanceAction(govActionID: votes.govActionId) {
                    print()
                    spacedPrint("\(.link(title: url.absoluteString, href: url.absoluteString))")
                }
            }
        }
    }
}
