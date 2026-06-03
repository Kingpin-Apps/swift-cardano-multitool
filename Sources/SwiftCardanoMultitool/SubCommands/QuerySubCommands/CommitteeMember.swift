import Foundation
import ArgumentParser
import Noora
import SystemPackage
import SwiftCardanoChain
import SwiftCardanoCore

extension QueryMainCommand {
    struct CommitteeMember: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "committee-member",
            abstract: "Query on-chain state for a constitutional-committee member (by cold or hot credential).",
            aliases: ["committee", "cc"]
        )

        @Argument(help: "Cold or hot credential: bech32 (cc_cold1…/cc_hot1…), hex hash, or .cc-cold.* / .cc-hot.* file.")
        var credential: CommitteeMemberCredential? = nil

        enum SelectCredentialSide: String, CaseIterable, AlignedChoiceDescribable {
            case cold
            case hot

            var name: String {
                switch self {
                    case .cold: return "Cold"
                    case .hot: return "Hot"
                }
            }

            var details: String {
                switch self {
                    case .cold: return "Look up the member by their cold credential."
                    case .hot: return "Look up the member by an authorized hot credential."
                }
            }
        }

        mutating func wizard() async throws {
            let side: SelectCredentialSide = noora.singleChoicePrompt(
                title: "Committee credential",
                question: "Look up a committee member by cold or hot credential?",
                description: "Cold = the member's permanent identity. Hot = the key they have authorized to vote on their behalf."
            )

            switch side {
                case .cold:
                    credential = .cold(try await getCommitteeColdCredential(title: "Committee cold credential"))
                case .hot:
                    credential = .hot(try await getCommitteeHotCredential(title: "Committee hot credential"))
            }
        }

        mutating func run() async throws {
            if credential == nil {
                try await wizard()
            }

            guard let credential = credential else {
                noora.error(.alert(
                    "Committee credential is required.",
                    takeaways: [
                        "Provide a bech32 cc_cold1…/cc_hot1…, a hex hash, or a .cc-cold.* / .cc-hot.* file.",
                        "Run with no argument to enter interactive mode.",
                    ]
                ))
                throw ExitCode.validationFailure
            }

            let config = try await MultitoolConfig.load()
            let cardanoConfig = try getCardanoConfig(config: config)
            let context = try await getContext(config: config)

            try await printContextInfo(config: config, context: context)

            try committeeMemberIdSummary(input: credential)
            print()

            // Fetch member info. Dispatch on the input variant.
            let info: CommitteeMemberInfo
            do {
                info = try await noora.progressStep(
                    message: "Querying committee-member info...",
                    successMessage: "Successfully retrieved committee-member info.",
                    errorMessage: "Failed to retrieve committee-member info.",
                    showSpinner: true
                ) { _ in
                    switch credential {
                        case .cold(let cold):
                            return try await context.committeeMemberInfo(cold: cold)
                        case .hot(let hot):
                            return try await context.committeeMemberInfo(hot: hot)
                        case .ambiguousHash(let data):
                            // Try cold first; fall back to hot on any error. Mirrors the bash script's
                            // behavior — a bare hex hash could be either side.
                            do {
                                return try await context.committeeMemberInfo(
                                    cold: CommitteeColdCredential(
                                        credential: .verificationKeyHash(
                                            VerificationKeyHash(payload: data))
                                    )
                                )
                            } catch {
                                return try await context.committeeMemberInfo(
                                    hot: CommitteeHotCredential(
                                        credential: .verificationKeyHash(
                                            VerificationKeyHash(payload: data))
                                    )
                                )
                            }
                    }
                }
            } catch {
                noora.error(.alert(
                    "Committee-member lookup failed: \(.danger("\(error)"))",
                    takeaways: [
                        "Backend in use: \(String(describing: type(of: context)))",
                        "BlockFrost does not implement committee-state queries — switch to Koios or cardano-cli mode.",
                    ]
                ))
                throw ExitCode.failure
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

            try committeeMemberInfoSummary(
                info: info,
                currentEpoch: currentEpoch,
                context: context
            )

            // Explorer link — pass the resolved cold credential so a hot-credential query still
            // produces a working "view this member" URL. Every concrete explorer currently throws
            // notImplemented for this method, so wrap in try? and only print when it succeeds.
            let explorer = config.blockchainExplorer.explorer(network: cardanoConfig.network)
            if let url = try? explorer.viewCommitteeMember(
                committeeColdCredential: info.coldCredential
            ) {
                spacedPrint("\(.link(title: url.absoluteString, href: url.absoluteString))")
            }
        }
    }
}
